import SwiftUI

/// Filter sheet for the explore screen. Lives in its own file so ExploreView
/// stays within the file-length budget.
struct ExploreFiltersView: View {
    @Bindable var model: ExploreViewModel
    let onApply: () -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                if !model.categories.isEmpty {
                    Section("Categoría") {
                        ForEach(model.categories, id: \.id) { category in
                            Button {
                                if let index = model.categorySlugs.firstIndex(of: category.slug) {
                                    model.categorySlugs.remove(at: index)
                                } else {
                                    model.categorySlugs.append(category.slug)
                                }
                            } label: {
                                HStack {
                                    Text("\(category.icon ?? "📍")  \(category.name)").foregroundStyle(.primary)
                                    Spacer()
                                    if model.categorySlugs.contains(category.slug) {
                                        Image(systemName: "checkmark").foregroundStyle(VLTheme.indigo)
                                    }
                                }
                            }
                            .accessibilityAddTraits(model.categorySlugs.contains(category.slug) ? [.isSelected] : [])
                        }
                    }
                }
                Section("Generales") {
                    Picker("Calificación mínima", selection: Binding(get: { model.minRating ?? 0 }, set: { model.minRating = $0 == 0 ? nil : $0 })) {
                        Text("Cualquiera").tag(Double(0))
                        Text("3 estrellas").tag(Double(3))
                        Text("4 estrellas").tag(Double(4))
                        Text("4.5 estrellas").tag(Double(4.5))
                    }
                    Toggle("Abierto ahora", isOn: $model.openNow)
                    Toggle("Verificados", isOn: $model.verified)
                    Toggle("Con promociones", isOn: $model.hasPromotions)
                    Toggle("Con próximos eventos", isOn: $model.hasUpcomingEvents)
                }
                Section("Locales") {
                    Picker("Precio", selection: Binding(get: { model.priceRange ?? "" }, set: { model.priceRange = $0.isEmpty ? nil : $0 })) {
                        Text("Cualquiera").tag("")
                        Text("$").tag("$"); Text("$$").tag("$$"); Text("$$$").tag("$$$"); Text("$$$$").tag("$$$$")
                    }
                    Picker("Servicio", selection: Binding(get: { model.services.first ?? "" }, set: { model.services = $0.isEmpty ? [] : [$0] })) {
                        Text("Cualquiera").tag("")
                        Text("Reservas").tag("Reservas"); Text("Delivery").tag("Delivery"); Text("Wi-Fi").tag("Wi-Fi")
                    }
                }
                Section("Eventos") {
                    Picker("Precio del evento", selection: Binding(get: { model.eventPrice ?? "" }, set: { model.eventPrice = $0.isEmpty ? nil : $0 })) {
                        Text("Cualquiera").tag(""); Text("Gratis").tag("free"); Text("De pago").tag("paid")
                    }
                    Picker("Fecha", selection: Binding(get: { model.eventDatePreset ?? "" }, set: { model.eventDatePreset = $0.isEmpty ? nil : $0 })) {
                        Text("Cualquiera").tag(""); Text("Hoy").tag("today"); Text("Mañana").tag("tomorrow"); Text("Este fin de semana").tag("thisWeekend")
                    }
                    TextField("Precio máximo", value: Binding(
                        get: { model.eventMaxPrice ?? 0 },
                        set: { model.eventMaxPrice = $0 == 0 ? nil : $0 }
                    ), format: .number)
                        .keyboardType(.decimalPad)
                }
            }
            .navigationTitle("Filtros")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Restablecer") { model.resetFilters() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Aplicar") { onApply(); dismiss() }
                }
            }
        }
    }
}
