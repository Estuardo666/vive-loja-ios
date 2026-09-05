import SwiftUI
import UIKit

/// Loaded only while the fallback is on screen; cancellation follows SwiftUI's task lifecycle.
struct VLGoogleVenuePhoto: View {
    let slug: String
    let large: Bool
    let height: CGFloat
    /// The author capsule does not fit on a thumbnail. Callers that turn it off
    /// must credit Google Maps themselves somewhere on the same card.
    var showsAttribution = true
    @State private var image: UIImage?
    @State private var photo: GoogleVenuePhoto?
    @State private var showAttribution = false

    var body: some View {
        Group {
            if let image, let photo {
                Image(uiImage: image).resizable().scaledToFill()
                    .frame(maxWidth: .infinity).frame(height: height).clipped()
                    .overlay(alignment: .bottomLeading) {
                        if showsAttribution {
                            Button { showAttribution = true } label: {
                                Text((["Google Maps"] + photo.authors.map(\.displayName)).joined(separator: " · "))
                                    .font(.caption.weight(.medium)).foregroundStyle(.white)
                                    .fixedSize(horizontal: false, vertical: true)
                                    .padding(8).background(.black.opacity(0.8), in: Capsule())
                            }
                            .buttonStyle(.borderless)
                            .accessibilityLabel("Ver fuente y autores de la foto en Google Maps")
                            .padding(8)
                        }
                    }
                    .accessibilityLabel("Foto de Google Maps, \(photo.authors.map(\.displayName).joined(separator: ", "))")
            } else {
                Rectangle().fill(.quaternary)
                    .overlay { Image(systemName: "photo").foregroundStyle(.secondary) }
            }
        }
        .sheet(isPresented: $showAttribution) {
            if let photo {
                NavigationStack {
                    List {
                        Link("Ver foto original en Google Maps", destination: photo.googleMapsUri)
                        ForEach(Array(photo.authors.enumerated()), id: \.offset) { _, author in
                            if let url = author.uri, url.scheme == "https" {
                                Link(author.displayName, destination: url)
                            } else { Text(author.displayName) }
                        }
                    }
                    .navigationTitle("Foto de Google Maps")
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Cerrar") { showAttribution = false }
                        }
                    }
                }
                .presentationDetents([.medium, .large])
            }
        }
        .task(id: "\(slug)-\(large)") {
            image = nil
            photo = nil
            do {
                guard let (metadata, data) = try await GoogleVenuePhotoClient.shared.load(slug: slug, large: large) else { return }
                guard let decoded = UIImage(data: data) else {
                    // Undecodable bytes must not be served again from the cache.
                    await GoogleVenuePhotoClient.shared.invalidate(slug: slug, large: large)
                    return
                }
                try Task.checkCancellation()
                photo = metadata
                image = decoded
            } catch {
                // Missing photos, offline requests and rate limits keep the placeholder.
            }
        }
    }
}
