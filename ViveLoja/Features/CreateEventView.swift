import Foundation
import Observation
import PhotosUI
import SwiftUI

@MainActor
@Observable
final class CreateEventViewModel {
    var title = ""
    var description = ""
    var location = ""
    var date = Calendar.current.date(byAdding: .day, value: 1, to: .now) ?? .now
    var isSaving = false
    var isUploading = false
    var imageURL: URL?
    var errorMessage: String?
    var didCreate = false

    var isValid: Bool {
        title.trimmingCharacters(in: .whitespacesAndNewlines).count >= 3
            && description.trimmingCharacters(in: .whitespacesAndNewlines).count >= 10
            && location.trimmingCharacters(in: .whitespacesAndNewlines).count >= 2
            && date > .now
    }

    func save(accessToken: String?) async {
        guard isValid else { return }
        guard let accessToken else { errorMessage = signedOutMessage; VLFeedback.error(); return }
        isSaving = true
        defer { isSaving = false }
        let formatter = ISO8601DateFormatter()
        do {
            let _: CreatedEvent = try await APIClient.shared.post(
                "/me/events",
                body: CreateEventRequest(title: title.trimmingCharacters(in: .whitespacesAndNewlines), description: description.trimmingCharacters(in: .whitespacesAndNewlines), startDate: formatter.string(from: date), endDate: nil, location: location.trimmingCharacters(in: .whitespacesAndNewlines), address: nil, lat: nil, lng: nil, price: nil, image: imageURL, venueId: nil),
                bearer: accessToken
            )
            didCreate = true
            VLFeedback.success()
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? "No se pudo publicar el evento."
            VLFeedback.error()
        }
    }

    func uploadPhoto(_ data: Data, fileName: String, mimeType: String, accessToken: String?) async {
        guard let accessToken else { errorMessage = signedOutMessage; VLFeedback.error(); return }
        isUploading = true; defer { isUploading = false }
        do {
            let upload: MobileUpload = try await APIClient.shared.upload("/me/uploads", data: data, fileName: fileName, mimeType: mimeType, bearer: accessToken)
            imageURL = upload.url
            errorMessage = nil
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? "No se pudo subir la imagen."
            VLFeedback.error()
        }
    }
}

struct CreateEventView: View {
    @Environment(SessionStore.self) private var session
    @Environment(\.dismiss) private var dismiss
    @State private var model = CreateEventViewModel()
    @State private var selectedPhoto: PhotosPickerItem?

    var body: some View {
        Form {
            Section("Información") {
                TextField("Título", text: $model.title)
                TextField("Descripción", text: $model.description, axis: .vertical).lineLimit(3...7)
                TextField("Lugar", text: $model.location)
                DatePicker("Fecha y hora", selection: $model.date, in: .now..., displayedComponents: [.date, .hourAndMinute])
            }
            Section("Imagen") {
                PhotosPicker(selection: $selectedPhoto, matching: .images, photoLibrary: .shared()) {
                    Label(model.isUploading ? "Subiendo…" : (model.imageURL == nil ? "Añadir portada" : "Cambiar portada"), systemImage: "photo.badge.plus")
                }
                .disabled(model.isUploading || session.accessToken == nil)
                if let imageURL = model.imageURL {
                    AsyncImage(url: imageURL) { image in image.resizable().scaledToFill() } placeholder: { ProgressView() }
                        .frame(height: 140).clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .accessibilityLabel("Portada seleccionada")
                }
            }
            Section {
                if let error = model.errorMessage { Text(error).foregroundStyle(.red) }
                Button {
                    Task { await model.save(accessToken: session.accessToken) }
                } label: {
                    if model.isSaving { ProgressView() } else { Label("Enviar a moderación", systemImage: "paperplane.fill") }
                }
                .frame(maxWidth: .infinity)
                .disabled(!model.isValid || model.isSaving)
            } footer: {
                Text("Tu evento quedará pendiente de revisión antes de publicarse.")
            }
        }
        .vlScreen()
        .navigationTitle("Nuevo evento")
        .onChange(of: selectedPhoto) { _, item in
            guard let item else { return }
            Task {
                if let data = try? await item.loadTransferable(type: Data.self) {
                    await model.uploadPhoto(data, fileName: "event-cover.jpg", mimeType: "image/jpeg", accessToken: session.accessToken)
                }
            }
        }
        .onChange(of: model.didCreate) { _, created in if created { dismiss() } }
    }
}
