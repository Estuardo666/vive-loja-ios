import Observation
import SwiftUI

@MainActor
@Observable
final class InterestsViewModel {
    var categories: [Category] = []
    var selectedIDs: Set<String> = []
    var preferences: Set<String> = []
    var isLoading = false
    var isSaving = false
    var errorMessage: String?
    let preferenceOptions = ["Comida", "Cultura", "Naturaleza", "Familia", "Vida nocturna", "Bienestar"]

    func load(accessToken: String?) async {
        guard let accessToken else { return }
        isLoading = true; defer { isLoading = false }
        do {
            async let home: HomePayload = APIClient.shared.get("/home")
            async let current: MobileInterests = APIClient.shared.get("/me/interests", bearer: accessToken)
            let (homePayload, interests) = try await (home, current)
            categories = homePayload.categories
            selectedIDs = Set(interests.categories.map(\.id))
            preferences = Set(interests.preferences)
            errorMessage = nil
        } catch { errorMessage = (error as? LocalizedError)?.errorDescription ?? "No se pudieron cargar tus intereses." }
    }

    func save(accessToken: String?) async -> Bool {
        guard let accessToken else { return false }
        isSaving = true; defer { isSaving = false }
        do {
            let _: MobileInterests = try await APIClient.shared.put("/me/interests", body: InterestsRequest(categoryIds: Array(selectedIDs), preferences: Array(preferences)), bearer: accessToken)
            VLFeedback.success(); return true
        } catch { errorMessage = (error as? LocalizedError)?.errorDescription ?? "No se pudieron guardar tus intereses."; VLFeedback.error(); return false }
    }
}

struct InterestsView: View {
    @Environment(SessionStore.self) private var session
    @Environment(\.dismiss) private var dismiss
    @State private var model = InterestsViewModel()

    var body: some View {
        List {
            if model.isLoading && model.categories.isEmpty { ProgressView("Cargando opciones…") }
            Section("¿Qué te interesa descubrir?") {
                ForEach(model.categories, id: \.id) { category in
                    Button {
                        if model.selectedIDs.contains(category.id) { model.selectedIDs.remove(category.id) } else { model.selectedIDs.insert(category.id) }
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: category.icon ?? "sparkles").foregroundStyle(VLTheme.indigo).frame(width: 26)
                            Text(category.name).foregroundStyle(.primary)
                            Spacer()
                            Image(systemName: model.selectedIDs.contains(category.id) ? "checkmark.circle.fill" : "circle")
                                .foregroundStyle(model.selectedIDs.contains(category.id) ? VLTheme.emerald : .secondary)
                        }
                    }
                    .buttonStyle(.plain)
                    .accessibilityValue(model.selectedIDs.contains(category.id) ? "Seleccionado" : "No seleccionado")
                }
            }
            Section("Tu estilo") {
                ForEach(model.preferenceOptions, id: \.self) { preference in
                    Button {
                        if model.preferences.contains(preference) { model.preferences.remove(preference) } else { model.preferences.insert(preference) }
                    } label: {
                        HStack { Text(preference).foregroundStyle(.primary); Spacer(); Image(systemName: model.preferences.contains(preference) ? "checkmark.circle.fill" : "circle").foregroundStyle(model.preferences.contains(preference) ? VLTheme.emerald : .secondary) }
                    }
                    .buttonStyle(.plain)
                }
            }
            if let error = model.errorMessage { Text(error).foregroundStyle(.red) }
            Section {
                Button {
                    Task { if await model.save(accessToken: session.accessToken) { dismiss() } }
                } label: { if model.isSaving { ProgressView() } else { Label("Guardar preferencias", systemImage: "checkmark") } }
                .disabled(model.isSaving || model.selectedIDs.isEmpty)
            }
        }
        .navigationTitle("Mis intereses")
        .task { await model.load(accessToken: session.accessToken) }
    }
}
