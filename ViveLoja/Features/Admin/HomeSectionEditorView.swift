import SwiftUI

/// Create or edit one home section.
///
/// The form is typed per section kind — the same contract the backend validates
/// — so nobody has to hand-write JSON from a phone. Parameters the form does not
/// show (a curated `manual` list) travel back untouched in `params`.
struct HomeSectionEditorView: View {
    struct Draft: Identifiable {
        /// `nil` while creating; the section id while editing.
        let id: String?
        var type: String
        var title: String
        var subtitle: String
        var actionLabel: String
        var layout: String
        var platform: String
        var isActive: Bool
        var params: HomeSectionParams

        init() {
            id = nil
            type = "venueList"
            title = ""
            subtitle = ""
            actionLabel = "Ver todo"
            layout = HomeSectionCatalog.defaultLayout(forType: "venueList")
            platform = "all"
            isActive = true
            var params = HomeSectionParams()
            params.sort = "recent"
            params.limit = 12
            self.params = params
        }

        init(section: HomeSectionAdmin) {
            id = section.id
            type = section.type
            title = section.title
            subtitle = section.subtitle ?? ""
            actionLabel = section.actionLabel ?? ""
            layout = section.layout
            platform = section.platform
            isActive = section.isActive
            params = section.params
        }

        /// SwiftUI identity for the sheet: a new draft must not reuse an id.
        var identifier: String { id ?? "new" }
    }

    @Environment(\.dismiss) private var dismiss
    @State private var draft: Draft
    @State private var isSaving = false
    private let onSave: (HomeSectionAdminRequest) async -> Bool

    init(draft: Draft, onSave: @escaping (HomeSectionAdminRequest) async -> Bool) {
        _draft = State(initialValue: draft)
        self.onSave = onSave
    }

    var body: some View {
        Form {
            Section("Contenido") {
                Picker("Tipo", selection: $draft.type) {
                    ForEach(HomeSectionCatalog.types, id: \.value) { Text($0.label).tag($0.value) }
                }
                .onChange(of: draft.type) { _, newValue in
                    draft.layout = HomeSectionCatalog.defaultLayout(forType: newValue)
                    draft.params = HomeSectionParams()
                }
                Picker("Diseño", selection: $draft.layout) {
                    ForEach(HomeSectionCatalog.layouts, id: \.value) { Text($0.label).tag($0.value) }
                }
                TextField("Título", text: $draft.title)
                TextField("Subtítulo", text: $draft.subtitle)
                TextField("Texto de la acción", text: $draft.actionLabel)
            }

            Section("Visibilidad") {
                Toggle("Visible", isOn: $draft.isActive)
                Picker("Dónde se muestra", selection: $draft.platform) {
                    ForEach(HomeSectionCatalog.platforms, id: \.value) { Text($0.label).tag($0.value) }
                }
            }

            parameters

            if let errorMessage {
                Section { Text(errorMessage).foregroundStyle(VLTheme.coral) }
            }
        }
        .navigationTitle(draft.id == nil ? "Nueva sección" : "Editar sección")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancelar") { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Guardar") { Task { await save() } }
                    .disabled(draft.title.trimmingCharacters(in: .whitespaces).isEmpty || isSaving)
            }
        }
    }

    // MARK: - Type-specific parameters

    @ViewBuilder private var parameters: some View {
        switch draft.type {
        case "hero":
            Section("Hero") {
                TextField("Texto", text: binding(\.body))
                TextField("Botón", text: binding(\.ctaLabel))
                TextField("Destino", text: binding(\.ctaDeeplink))
            }
        case "venueList":
            Section("Filtros") {
                TextField("Categoría (slug)", text: binding(\.categorySlug))
                Picker("Orden", selection: optionalBinding(\.sort, default: "recent")) {
                    ForEach(HomeSectionCatalog.venueSorts, id: \.value) { Text($0.label).tag($0.value) }
                }
                Toggle("Solo destacados", isOn: boolBinding(\.featured))
                Toggle("Solo verificados", isOn: boolBinding(\.verified))
                Toggle("Con promoción activa", isOn: boolBinding(\.hasPromotion))
                limitStepper
            }
        case "eventList":
            Section("Filtros") {
                TextField("Categoría (slug)", text: binding(\.categorySlug))
                Picker("Fechas", selection: optionalBinding(\.dateRange, default: "all")) {
                    ForEach(HomeSectionCatalog.dateRanges, id: \.value) { Text($0.label).tag($0.value) }
                }
                Picker("Orden", selection: optionalBinding(\.sort, default: "soon")) {
                    ForEach(HomeSectionCatalog.eventSorts, id: \.value) { Text($0.label).tag($0.value) }
                }
                Toggle("Solo destacados", isOn: boolBinding(\.featured))
                limitStepper
            }
        case "ranked":
            Section("Ranking") {
                Picker("Contenido", selection: optionalBinding(\.kind, default: "venue")) {
                    Text("Locales").tag("venue")
                    Text("Eventos").tag("event")
                }
                Picker("Ventana", selection: optionalBinding(\.window, default: "24h")) {
                    Text("Últimas 24 horas").tag("24h")
                    Text("Últimos 7 días").tag("7d")
                }
                limitStepper
            }
        case "collection":
            Section("Colección") {
                TextField("Slug de la colección", text: binding(\.slug))
                limitStepper
            }
        case "posts":
            Section("Blog") {
                TextField("Etiqueta (slug)", text: binding(\.tagSlug))
                Toggle("Solo destacados", isOn: boolBinding(\.featured))
                limitStepper
            }
        case "routes":
            Section("Rutas") {
                Toggle("Solo destacadas", isOn: boolBinding(\.featured))
                limitStepper
            }
        case "promotions", "categoryChips":
            Section("Opciones") { limitStepper }
        case "manual":
            Section("Selección manual") {
                Text("\(draft.params.items?.count ?? 0) elementos elegidos.")
                Text("La lista se edita desde el panel web; aquí se conserva tal cual.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        default:
            Section("Opciones") {
                Text("Esta sección la construye la app; solo decides si aparece y dónde.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var limitStepper: some View {
        Stepper(
            "Cantidad: \(draft.params.limit ?? 12)",
            value: Binding(get: { draft.params.limit ?? 12 }, set: { draft.params.limit = $0 }),
            in: 1...30
        )
    }

    // MARK: - Bindings

    /// Text fields write `nil` instead of an empty string so an untouched
    /// optional filter is not sent as `""`.
    private func binding(_ keyPath: WritableKeyPath<HomeSectionParams, String?>) -> Binding<String> {
        Binding(
            get: { draft.params[keyPath: keyPath] ?? "" },
            set: { draft.params[keyPath: keyPath] = $0.isEmpty ? nil : $0 }
        )
    }

    private func boolBinding(_ keyPath: WritableKeyPath<HomeSectionParams, Bool?>) -> Binding<Bool> {
        Binding(
            get: { draft.params[keyPath: keyPath] ?? false },
            set: { draft.params[keyPath: keyPath] = $0 ? true : nil }
        )
    }

    private func optionalBinding(
        _ keyPath: WritableKeyPath<HomeSectionParams, String?>,
        default defaultValue: String
    ) -> Binding<String> {
        Binding(
            get: { draft.params[keyPath: keyPath] ?? defaultValue },
            set: { draft.params[keyPath: keyPath] = $0 }
        )
    }

    @State private var errorMessage: String?

    private func save() async {
        isSaving = true
        defer { isSaving = false }
        let request = HomeSectionAdminRequest(
            type: draft.type,
            title: draft.title.trimmingCharacters(in: .whitespaces),
            subtitle: draft.subtitle.isEmpty ? nil : draft.subtitle,
            actionLabel: draft.actionLabel.isEmpty ? nil : draft.actionLabel,
            layout: draft.layout,
            platform: draft.platform,
            isActive: draft.isActive,
            params: draft.params
        )
        if await onSave(request) {
            dismiss()
        } else {
            errorMessage = "No se pudo guardar la sección. Revisa los datos e inténtalo de nuevo."
        }
    }
}
