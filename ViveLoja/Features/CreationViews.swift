import Foundation
import PhotosUI
import SwiftUI

/// Tapping publish with no session used to do nothing at all — no request, no
/// message, no haptic — which is indistinguishable from a dead button. Access
/// tokens last fifteen minutes, so this is reachable just by leaving a
/// half-written form open for a while.
let signedOutMessage = "Inicia sesión para publicar."

struct CreationHubView: View {
    var body: some View {
        List {
            Section("Publicar en Vive Loja") {
                NavigationLink(destination: CreateEventView()) { Label("Evento", systemImage: "calendar.badge.plus") }.accessibilityIdentifier("creation-event")
                NavigationLink(destination: CreateVenueView()) { Label("Local", systemImage: "storefront") }.accessibilityIdentifier("creation-venue")
                NavigationLink(destination: CreatePostView()) { Label("Artículo", systemImage: "doc.richtext") }.accessibilityIdentifier("creation-post")
                NavigationLink(destination: CreateRouteView()) { Label("Ruta", systemImage: "point.topleft.down.curvedto.point.bottomright.up") }.accessibilityIdentifier("creation-route")
            }
            Section { Text("Todo lo que publiques queda pendiente de moderación antes de aparecer en la app.").font(.footnote).foregroundStyle(.secondary) }
        }
        .navigationTitle("Publicar contenido")
    }
}

struct CreateVenueView: View {
    @Environment(SessionStore.self) private var session
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""; @State private var description = ""; @State private var location = ""; @State private var address = ""
    @State private var phone = ""; @State private var website = ""; @State private var isSaving = false; @State private var errorMessage: String?
    @State private var selectedPhoto: PhotosPickerItem?; @State private var imageURL: URL?; @State private var isUploading = false

    private var isValid: Bool { name.trimmed.count >= 2 && description.trimmed.count >= 10 && location.trimmed.count >= 2 }
    var body: some View {
        Form {
            Section("Información") {
                TextField("Nombre del local", text: $name)
                TextField("Descripción", text: $description, axis: .vertical).lineLimit(3...7)
                TextField("Ciudad o sector", text: $location)
                TextField("Dirección (opcional)", text: $address)
                TextField("Teléfono (opcional)", text: $phone).keyboardType(.phonePad)
                TextField("Sitio web (opcional)", text: $website).keyboardType(.URL).textInputAutocapitalization(.never)
            }
            Section("Imagen") {
                PhotosPicker(selection: $selectedPhoto, matching: .images, photoLibrary: .shared()) { Label(isUploading ? "Subiendo…" : "Añadir portada", systemImage: "photo.badge.plus") }
                .disabled(isUploading || session.accessToken == nil)
                if let imageURL { AsyncImage(url: imageURL) { $0.resizable().scaledToFill() } placeholder: { ProgressView() }.frame(height: 140).clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous)) }
            }
            submitSection
        }
        .navigationTitle("Nuevo local")
        .onChange(of: selectedPhoto) { _, item in guard let item else { return }; Task { if let data = try? await item.loadTransferable(type: Data.self) { await upload(data) } } }
    }

    @ViewBuilder private var submitSection: some View {
        Section { if let errorMessage { Text(errorMessage).foregroundStyle(.red) }; Button { Task { await save() } } label: { if isSaving { ProgressView() } else { Label("Enviar a moderación", systemImage: "paperplane.fill") } }.disabled(!isValid || isSaving) }
    }
    private func upload(_ data: Data) async {
        guard let token = session.accessToken else { errorMessage = signedOutMessage; VLFeedback.error(); return }; isUploading = true; defer { isUploading = false }
        do { let uploaded: MobileUpload = try await APIClient.shared.upload("/me/uploads", data: data, fileName: "venue-cover.jpg", mimeType: "image/jpeg", bearer: token); imageURL = uploaded.url } catch { errorMessage = "No se pudo subir la portada." }
    }
    private func save() async {
        guard let token = session.accessToken else { errorMessage = signedOutMessage; VLFeedback.error(); return }; isSaving = true; defer { isSaving = false }
        do { let _: ModeratedDraft = try await APIClient.shared.post("/me/venues", body: CreateVenueRequest(name: name.trimmed, description: description.trimmed, location: location.trimmed, address: address.nilIfEmpty, phone: phone.nilIfEmpty, email: nil, website: website.nilIfEmpty, lat: nil, lng: nil, priceRange: nil, image: imageURL, categoryIds: nil), bearer: token); VLFeedback.success(); dismiss() } catch { errorMessage = (error as? LocalizedError)?.errorDescription ?? "No se pudo publicar el local."; VLFeedback.error() }
    }
}

struct CreatePostView: View {
    @Environment(SessionStore.self) private var session
    @Environment(\.dismiss) private var dismiss
    @State private var title = ""; @State private var content = ""; @State private var categories: [Category] = []; @State private var categoryID = ""; @State private var isSaving = false; @State private var errorMessage: String?
    private var isValid: Bool { title.trimmed.count >= 3 && content.trimmed.count >= 20 && !categoryID.isEmpty }
    var body: some View {
        Form {
            Section("Artículo") { TextField("Título", text: $title); TextField("Contenido", text: $content, axis: .vertical).lineLimit(8...16); if categories.isEmpty { ProgressView("Cargando categorías…") } else { Picker("Categoría", selection: $categoryID) { Text("Selecciona una categoría").tag(""); ForEach(categories, id: \.id) { Text($0.name).tag($0.id) } } } }
            Section { if let errorMessage { Text(errorMessage).foregroundStyle(.red) }; Button { Task { await save() } } label: { if isSaving { ProgressView() } else { Label("Enviar a moderación", systemImage: "paperplane.fill") } }.disabled(!isValid || isSaving) }
        }
        .navigationTitle("Nuevo artículo")
        .task {
            if ProcessInfo.processInfo.arguments.contains("-uiTesting") {
                categories = [Category(id: "ui-test-category", name: "Cultura", slug: "cultura", icon: "music.note", color: nil)]
                categoryID = categories[0].id
            } else if let home: HomePayload = try? await APIClient.shared.get("/home") {
                categories = home.categories
                if categoryID.isEmpty { categoryID = categories.first?.id ?? "" }
            }
        }
    }
    private func save() async { guard let token = session.accessToken else { errorMessage = signedOutMessage; VLFeedback.error(); return }; isSaving = true; defer { isSaving = false }; do { let _: ModeratedDraft = try await APIClient.shared.post("/me/posts", body: CreatePostRequest(title: title.trimmed, excerpt: nil, content: content.trimmed, image: nil, categoryId: categoryID), bearer: token); VLFeedback.success(); dismiss() } catch { errorMessage = (error as? LocalizedError)?.errorDescription ?? "No se pudo publicar el artículo."; VLFeedback.error() } }
}

struct CreateRouteView: View {
    @Environment(SessionStore.self) private var session
    @Environment(\.dismiss) private var dismiss
    @State private var title = ""; @State private var description = ""; @State private var type = "cultural"; @State private var duration = ""; @State private var difficulty = ""; @State private var isSaving = false; @State private var errorMessage: String?
    private var isValid: Bool { title.trimmed.count >= 3 && description.trimmed.count >= 10 && type.trimmed.count >= 2 }
    var body: some View {
        Form {
            Section("Ruta") { TextField("Título", text: $title); TextField("Descripción", text: $description, axis: .vertical).lineLimit(3...7); TextField("Tipo", text: $type); TextField("Duración (opcional)", text: $duration); TextField("Dificultad (opcional)", text: $difficulty) }
            Section { if let errorMessage { Text(errorMessage).foregroundStyle(.red) }; Button { Task { await save() } } label: { if isSaving { ProgressView() } else { Label("Enviar a moderación", systemImage: "paperplane.fill") } }.disabled(!isValid || isSaving) }
        }
        .navigationTitle("Nueva ruta")
    }
    private func save() async { guard let token = session.accessToken else { errorMessage = signedOutMessage; VLFeedback.error(); return }; isSaving = true; defer { isSaving = false }; do { let _: ModeratedDraft = try await APIClient.shared.post("/me/routes", body: CreateRouteRequest(title: title.trimmed, description: description.trimmed, content: nil, image: nil, duration: duration.nilIfEmpty, difficulty: difficulty.nilIfEmpty, type: type.trimmed, stops: nil), bearer: token); VLFeedback.success(); dismiss() } catch { errorMessage = (error as? LocalizedError)?.errorDescription ?? "No se pudo publicar la ruta."; VLFeedback.error() } }
}

private extension String {
    var trimmed: String { trimmingCharacters(in: .whitespacesAndNewlines) }
    var nilIfEmpty: String? { let value = trimmed; return value.isEmpty ? nil : value }
}
