import SwiftUI

struct CheckInView: View {
    let venueID: String
    let onSaved: () -> Void
    @Environment(SessionStore.self) private var session
    @Environment(\.dismiss) private var dismiss
    @State private var location = LocationService()
    @State private var note = ""
    @State private var isSaving = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                Section("Ubicación") {
                    if let coordinate = location.coordinate {
                        Label(String(format: "%.5f, %.5f", coordinate.lat, coordinate.lng), systemImage: "location.fill")
                            .foregroundStyle(VLTheme.emerald)
                    } else if location.isRequesting {
                        ProgressView("Obteniendo ubicación…")
                    } else {
                        Button("Usar mi ubicación", systemImage: "location") { location.requestCurrentLocation() }
                    }
                    if let locationError = location.errorMessage { Text(locationError).font(.footnote).foregroundStyle(.secondary) }
                }
                Section("Nota (opcional)") { TextEditor(text: $note).frame(minHeight: 100) }
                if let errorMessage { Text(errorMessage).foregroundStyle(.red) }
                Button { Task { await save() } } label: {
                    if isSaving { ProgressView() } else { Label("Registrar check-in", systemImage: "checkmark.seal.fill") }
                }
                .disabled(isSaving || session.accessToken == nil || location.coordinate == nil)
            }
            .navigationTitle("Check-in")
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cerrar") { dismiss() } } }
            .task { location.requestCurrentLocation() }
        }
    }

    private func save() async {
        guard let token = session.accessToken, let coordinate = location.coordinate else { return }
        isSaving = true; defer { isSaving = false }
        do {
            let trimmedNote = note.trimmingCharacters(in: .whitespacesAndNewlines)
            let _: MobileCheckIn = try await APIClient.shared.post("/me/check-ins", body: CheckInRequest(venueId: venueID, lat: coordinate.lat, lng: coordinate.lng, note: trimmedNote.isEmpty ? nil : trimmedNote, photoUrl: nil), bearer: token)
            VLFeedback.success(); onSaved(); dismiss()
        } catch { errorMessage = (error as? LocalizedError)?.errorDescription ?? "No se pudo registrar el check-in."; VLFeedback.error() }
    }
}
