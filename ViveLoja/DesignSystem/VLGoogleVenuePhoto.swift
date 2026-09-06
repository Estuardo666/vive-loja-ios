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
    /// Small cards have no room for the author list, but Google still has to be
    /// credited on the card, so the capsule shrinks to the source alone.
    var compactAttribution = false
    @State private var image: UIImage?
    @State private var photo: GoogleVenuePhoto?
    @State private var showAttribution = false

    private func attributionText(for photo: GoogleVenuePhoto) -> String {
        compactAttribution ? "Google Maps" : (["Google Maps"] + photo.authors.map(\.displayName)).joined(separator: " · ")
    }

    var body: some View {
        Group {
            if let image, let photo {
                Image(uiImage: image).resizable().scaledToFill()
                    .frame(maxWidth: .infinity).frame(height: height).clipped()
                    .overlay(alignment: .bottomLeading) {
                        if showsAttribution {
                            Button { showAttribution = true } label: {
                                Text(attributionText(for: photo))
                                    .font(.caption.weight(.medium)).foregroundStyle(.white)
                                    .lineLimit(1)
                                    .truncationMode(.tail)
                                    .padding(8).background(.black.opacity(0.8), in: Capsule())
                            }
                            .buttonStyle(.borderless)
                            .accessibilityLabel("Ver fuente y autores de la foto en Google Maps")
                            .padding(8)
                        }
                    }
                    .accessibilityLabel("Foto de Google Maps, \(photo.authors.map(\.displayName).joined(separator: ", "))")
                    // The capsule is an overlay, and an overlay is not clipped
                    // by the view it decorates: on a card it used to spill over
                    // the neighbouring one.
                    .clipped()
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
                    .vlScreen()
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
