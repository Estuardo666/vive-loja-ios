import MapKit
import SwiftUI
import UIKit

/// Downsampled remote artwork kept in memory so panning, tab switches and
/// navigation back to a list do not refetch first-party images.
///
/// Google Places photos deliberately do not use this cache. They have a
/// separate client because Google prohibits caching photo URIs and photos.
@MainActor
final class RemoteImageCache {
    static let shared = RemoteImageCache()
    private let session: URLSession
    private let cache = NSCache<NSString, UIImage>()
    private var inflight: [String: Task<UIImage?, Never>] = [:]

    private init() {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.urlCache = nil
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        configuration.waitsForConnectivity = false
        configuration.timeoutIntervalForRequest = 12
        configuration.timeoutIntervalForResource = 30
        session = URLSession(configuration: configuration)
        cache.countLimit = 320
        cache.totalCostLimit = 24 * 1024 * 1024
    }

    func cached(_ url: URL, maxPixelSize: CGSize = CGSize(width: 96, height: 96)) -> UIImage? {
        guard !Self.isGoogleOwned(url) else { return nil }
        cache.object(forKey: key(for: url, maxPixelSize: maxPixelSize) as NSString)
    }

    func image(for url: URL, maxPixelSize: CGSize = CGSize(width: 96, height: 96)) async -> UIImage? {
        let cacheKey = key(for: url, maxPixelSize: maxPixelSize)
        let cacheable = !Self.isGoogleOwned(url)
        if cacheable, let hit = cache.object(forKey: cacheKey as NSString) { return hit }
        if let running = inflight[cacheKey] { return await running.value }

        let task = Task { [weak self] in
            guard let self else { return nil }
            guard let (data, response) = try? await self.session.data(from: url),
                  let http = response as? HTTPURLResponse,
                  (200..<300).contains(http.statusCode),
                  // Pins are small; cards and detail galleries get a larger
                  // target. Never retain the original full-resolution bytes.
                  let image = UIImage(data: data)?.preparingThumbnail(of: maxPixelSize)
            else { return nil }
            if cacheable {
                self.cache.setObject(image, forKey: cacheKey as NSString, cost: data.count)
            }
            return image
        }
        inflight[cacheKey] = task
        let image = await task.value
        inflight[cacheKey] = nil
        return image
    }

    private func key(for url: URL, maxPixelSize: CGSize) -> String {
        "\(url.absoluteString)|\(Int(maxPixelSize.width))x\(Int(maxPixelSize.height))"
    }

    private static func isGoogleOwned(_ url: URL) -> Bool {
        let host = (url.host ?? "").lowercased()
        let path = url.path.lowercased()
        return host == "google.com"
            || host.hasSuffix(".google.com")
            || host == "googleapis.com"
            || host.hasSuffix(".googleapis.com")
            || host == "googleusercontent.com"
            || host.hasSuffix(".googleusercontent.com")
            || host == "ggpht.com"
            || host.hasSuffix(".ggpht.com")
            || host == "gstatic.com"
            || host.hasSuffix(".gstatic.com")
            || path.contains("/google-photo")
    }
}

/// Map pin showing the venue/event photo instead of a generic marker.
final class ItemPhotoAnnotationView: MKAnnotationView {
    private static let diameter: CGFloat = 34
    private let photoView = UIImageView()
    private var loadTask: Task<Void, Never>?

    override init(annotation: MKAnnotation?, reuseIdentifier: String?) {
        super.init(annotation: annotation, reuseIdentifier: reuseIdentifier)
        frame = CGRect(x: 0, y: 0, width: Self.diameter, height: Self.diameter)
        centerOffset = CGPoint(x: 0, y: -Self.diameter / 2)
        clusteringIdentifier = "explore-items"
        displayPriority = .defaultHigh
        collisionMode = .circle

        photoView.frame = bounds
        photoView.clipsToBounds = true
        photoView.layer.cornerRadius = Self.diameter / 2
        photoView.tintColor = .white
        addSubview(photoView)

        layer.cornerRadius = Self.diameter / 2
        layer.borderWidth = 2.5
        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOpacity = 0.35
        layer.shadowRadius = 4
        layer.shadowOffset = CGSize(width: 0, height: 2)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func configure(with item: MapItemAnnotation) {
        annotation = item
        let tint = UIColor(VLTheme.itemColor(item.item))
        layer.borderColor = tint.cgColor
        photoView.backgroundColor = tint
        // Re-asserted after dequeue: a recycled view can come back without it,
        // which is what stopped pins from clustering.
        clusteringIdentifier = "explore-items"
        showPlaceholder(isVenue: item.isVenue)

        loadTask?.cancel()
        loadTask = nil
        guard let url = item.imageURL else { return }
        if let hit = RemoteImageCache.shared.cached(url) { show(hit); return }
        loadTask = Task { [weak self] in
            let image = await RemoteImageCache.shared.image(for: url)
            guard !Task.isCancelled, let self, let image else { return }
            // The view may have been recycled for a different pin mid-flight.
            guard (self.annotation as? MapItemAnnotation)?.id == item.id else { return }
            self.show(image)
        }
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)
        let itemTint = (annotation as? MapItemAnnotation)
            .map { UIColor(VLTheme.itemColor($0.item)) }
            ?? UIColor(VLTheme.indigo)
        let apply = {
            self.transform = selected ? CGAffineTransform(scaleX: 1.6, y: 1.6) : .identity
            self.layer.borderWidth = selected ? 4 : 2.5
            self.layer.borderColor = selected ? UIColor.white.cgColor : itemTint.cgColor
            self.layer.shadowOpacity = selected ? 0.75 : 0.35
            self.layer.shadowRadius = selected ? 8 : 4
        }
        if animated && !UIAccessibility.isReduceMotionEnabled {
            UIView.animate(withDuration: 0.22, delay: 0, usingSpringWithDamping: 0.7, initialSpringVelocity: 0.4, options: [.beginFromCurrentState], animations: apply)
        } else {
            apply()
        }
        if selected { superview?.bringSubviewToFront(self) }
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        loadTask?.cancel()
        loadTask = nil
        photoView.image = nil
        transform = .identity
        layer.borderWidth = 2.5
        layer.shadowOpacity = 0.35
        layer.shadowRadius = 4
    }

    private func show(_ image: UIImage) {
        photoView.contentMode = .scaleAspectFill
        photoView.image = image
    }

    private func showPlaceholder(isVenue: Bool) {
        photoView.contentMode = .center
        photoView.image = UIImage(systemName: isVenue ? "mappin" : "calendar")?
            .withTintColor(.white, renderingMode: .alwaysOriginal)
    }
}

/// Replaces the plain blue dot with the signed-in user's avatar. Falls back to
/// MapKit's own dot when there is no photo, which is why the delegate returns
/// nil rather than this view in that case.
final class UserAvatarAnnotationView: MKAnnotationView {
    static let reuseID = "user-avatar"
    private static let diameter: CGFloat = 38
    private let photoView = UIImageView()
    private var loadTask: Task<Void, Never>?

    override init(annotation: MKAnnotation?, reuseIdentifier: String?) {
        super.init(annotation: annotation, reuseIdentifier: reuseIdentifier)
        frame = CGRect(x: 0, y: 0, width: Self.diameter, height: Self.diameter)
        canShowCallout = false
        isEnabled = false

        photoView.frame = bounds
        photoView.clipsToBounds = true
        photoView.contentMode = .scaleAspectFill
        photoView.layer.cornerRadius = Self.diameter / 2
        photoView.backgroundColor = UIColor(VLTheme.indigo)
        addSubview(photoView)

        layer.cornerRadius = Self.diameter / 2
        layer.borderWidth = 3
        layer.borderColor = UIColor.white.cgColor
        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOpacity = 0.4
        layer.shadowRadius = 5
        layer.shadowOffset = CGSize(width: 0, height: 2)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func configure(with url: URL?) {
        loadTask?.cancel()
        loadTask = nil
        guard let url else {
            photoView.image = nil
            return
        }
        if let hit = RemoteImageCache.shared.cached(url) { photoView.image = hit; return }
        loadTask = Task { [weak self] in
            let image = await RemoteImageCache.shared.image(for: url)
            guard !Task.isCancelled, let self, let image else { return }
            self.photoView.image = image
        }
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        loadTask?.cancel()
        loadTask = nil
        photoView.image = nil
    }
}
