import MapKit
import SwiftUI
import UIKit

/// Downsampled pin artwork, kept in memory so panning does not refetch.
@MainActor
final class MapImageCache {
    static let shared = MapImageCache()
    private let cache = NSCache<NSURL, UIImage>()
    private static let pinPixelSize = CGSize(width: 96, height: 96)

    private init() { cache.countLimit = 240 }

    func cached(_ url: URL) -> UIImage? { cache.object(forKey: url as NSURL) }

    func image(for url: URL) async -> UIImage? {
        if let hit = cached(url) { return hit }
        guard let (data, _) = try? await URLSession.shared.data(from: url) else { return nil }
        // Pins are 46pt; keeping full-resolution photos for every marker is what
        // makes map memory blow up, so downsample before caching.
        guard let image = UIImage(data: data)?.preparingThumbnail(of: Self.pinPixelSize) else { return nil }
        cache.setObject(image, forKey: url as NSURL)
        return image
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
        if let hit = MapImageCache.shared.cached(url) { show(hit); return }
        loadTask = Task { [weak self] in
            let image = await MapImageCache.shared.image(for: url)
            guard !Task.isCancelled, let self, let image else { return }
            // The view may have been recycled for a different pin mid-flight.
            guard (self.annotation as? MapItemAnnotation)?.id == item.id else { return }
            self.show(image)
        }
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)
        let apply = {
            self.transform = selected ? CGAffineTransform(scaleX: 1.45, y: 1.45) : .identity
            self.layer.borderWidth = selected ? 3.5 : 2.5
            self.layer.shadowOpacity = selected ? 0.6 : 0.35
        }
        if animated {
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
