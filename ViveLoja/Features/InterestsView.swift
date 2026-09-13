import Observation
import SwiftUI

struct DiscoveryPreferenceOption: Identifiable, Sendable {
    let id: String
    let title: String
    let detail: String
    let symbol: String
}

let discoveryPreferenceOptions = [
    DiscoveryPreferenceOption(id: "NIGHTLIFE", title: "Salir con amigos", detail: "Bares, música y planes para la noche", symbol: "person.2"),
    DiscoveryPreferenceOption(id: "DATES", title: "Planes en pareja", detail: "Lugares tranquilos y experiencias para dos", symbol: "heart"),
    DiscoveryPreferenceOption(id: "FAMILY", title: "En familia", detail: "Actividades y espacios para todas las edades", symbol: "figure.2.and.child.holdinghands"),
    DiscoveryPreferenceOption(id: "REMOTE_WORK", title: "Trabajar fuera", detail: "Cafés y espacios cómodos para concentrarse", symbol: "laptopcomputer"),
    DiscoveryPreferenceOption(id: "CONCERTS", title: "Música en vivo", detail: "Conciertos, festivales y presentaciones", symbol: "music.note"),
    DiscoveryPreferenceOption(id: "NATURE", title: "Aire libre", detail: "Naturaleza, rutas y miradores", symbol: "leaf"),
    DiscoveryPreferenceOption(id: "GASTRONOMY", title: "Comer bien", detail: "Restaurantes, sabores locales y novedades", symbol: "fork.knife"),
    DiscoveryPreferenceOption(id: "INSTAGRAMMABLE", title: "Lugares con buena vista", detail: "Arquitectura, paisajes y espacios fotogénicos", symbol: "camera"),
    DiscoveryPreferenceOption(id: "SPORTS", title: "Deporte", detail: "Partidos, entrenamiento y actividad física", symbol: "figure.run"),
    DiscoveryPreferenceOption(id: "CULTURE", title: "Arte y cultura", detail: "Teatro, museos, cine y exposiciones", symbol: "building.columns"),
    DiscoveryPreferenceOption(id: "COFFEE_HOPPING", title: "Café y conversación", detail: "Cafeterías para descubrir sin prisa", symbol: "cup.and.saucer"),
    DiscoveryPreferenceOption(id: "WELLNESS", title: "Bienestar", detail: "Salud, descanso y cuidado personal", symbol: "heart.text.square")
]

@MainActor
@Observable
final class InterestsViewModel {
    var categories: [Category] = []
    var selectedIDs: Set<String> = []
    var preferences: Set<String> = []
    var isLoading = false
    var isSaving = false
    var errorMessage: String?

    func load(accessToken: String?) async {
        guard let accessToken else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            async let home: HomePayload = APIClient.shared.get("/home")
            async let current: MobileInterests = APIClient.shared.get("/me/interests", bearer: accessToken)
            let (homePayload, interests) = try await (home, current)
            categories = homePayload.categories
            selectedIDs = Set(interests.categories.map(\.id))
            preferences = Set(interests.preferences)
            errorMessage = nil
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? "No se pudieron cargar tus preferencias."
        }
    }

    func save(accessToken: String?) async -> Bool {
        guard let accessToken else { return false }
        isSaving = true
        defer { isSaving = false }
        do {
            let _: MobileInterests = try await APIClient.shared.put(
                "/me/interests",
                body: InterestsRequest(categoryIds: Array(selectedIDs), preferences: Array(preferences)),
                bearer: accessToken
            )
            errorMessage = nil
            NotificationCenter.default.post(name: .discoveryPreferencesChanged, object: nil)
            VLFeedback.success()
            return true
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? "No se pudieron guardar tus preferencias."
            VLFeedback.error()
            return false
        }
    }
}

extension Notification.Name {
    static let discoveryPreferencesChanged = Notification.Name("discoveryPreferencesChanged")
}

struct InterestsView: View {
    @Environment(SessionStore.self) private var session
    @Environment(\.dismiss) private var dismiss
    @State private var model = InterestsViewModel()

    var body: some View {
        @Bindable var model = model
        Form {
            Section {
                Text("Tus elecciones cambian el orden de eventos y lugares en Inicio. Puedes volver cuando quieras.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Section("Temas que quieres ver") {
                ForEach(model.categories, id: \.id) { category in
                    selectionRow(
                        title: category.name,
                        detail: nil,
                        symbol: categorySystemImage(category),
                        isSelected: model.selectedIDs.contains(category.id)
                    ) {
                        toggle(category.id, in: &model.selectedIDs)
                    }
                }
            }

            Section("Cómo disfrutas la ciudad") {
                ForEach(discoveryPreferenceOptions) { preference in
                    selectionRow(
                        title: preference.title,
                        detail: preference.detail,
                        symbol: preference.symbol,
                        isSelected: model.preferences.contains(preference.id)
                    ) {
                        toggle(preference.id, in: &model.preferences)
                    }
                }
            }

            if let error = model.errorMessage {
                Section { Text(error).foregroundStyle(.red).accessibilityLabel("Error: \(error)") }
            }
        }
        .vlScreen()
        .navigationTitle("Preferencias del inicio")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Guardar") {
                    Task { if await model.save(accessToken: session.accessToken) { dismiss() } }
                }
                .disabled(model.isSaving || model.selectedIDs.count < 3 || model.preferences.isEmpty)
            }
        }
        .overlay { if model.isLoading { ProgressView("Cargando preferencias…") } }
        .task { await model.load(accessToken: session.accessToken) }
    }

    private func selectionRow(title: String, detail: String?, symbol: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: symbol)
                    .frame(width: 24)
                    .foregroundStyle(isSelected ? VLTheme.indigo : .secondary)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).foregroundStyle(.primary)
                    if let detail { Text(detail).font(.caption).foregroundStyle(.secondary) }
                }
                Spacer()
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isSelected ? VLTheme.emerald : .secondary)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .frame(minHeight: 44)
        .accessibilityValue(isSelected ? "Seleccionado" : "No seleccionado")
    }

    private func toggle(_ value: String, in selection: inout Set<String>) {
        if selection.contains(value) { selection.remove(value) } else { selection.insert(value) }
    }
}

func categorySystemImage(_ category: Category) -> String {
    let value = "\(category.name) \(category.slug)".folding(options: .diacriticInsensitive, locale: .current).lowercased()
    if value.contains("cafe") || value.contains("panader") { return "cup.and.saucer" }
    if value.contains("restaur") || value.contains("comida") || value.contains("gastronom") { return "fork.knife" }
    if value.contains("musica") || value.contains("concierto") { return "music.note" }
    if value.contains("arte") || value.contains("cultura") || value.contains("museo") { return "building.columns" }
    if value.contains("naturaleza") || value.contains("parque") || value.contains("sender") { return "leaf" }
    if value.contains("deporte") || value.contains("gimnasio") { return "figure.run" }
    if value.contains("bar") || value.contains("noche") { return "moon.stars" }
    return "mappin"
}
