import SwiftUI

private struct OnboardingSkipResponse: Decodable, Sendable { let skipped: Bool }

struct DiscoveryOnboardingView: View {
    let onFinished: () -> Void

    @Environment(SessionStore.self) private var session
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var model = InterestsViewModel()
    @State private var step = 0
    @State private var isSkipping = false

    private let totalSteps = 3

    var body: some View {
        @Bindable var model = model
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    progress
                    header
                    content(model: model)
                    if let error = model.errorMessage {
                        Text(error)
                            .font(.footnote)
                            .foregroundStyle(.red)
                            .accessibilityLabel("Error: \(error)")
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 18)
                .padding(.bottom, 110)
            }
            .safeAreaInset(edge: .bottom) { actionBar(model: model) }
            .background(VLTheme.background.ignoresSafeArea())
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Ahora no") { Task { await skip() } }
                        .disabled(isSkipping || model.isSaving)
                }
            }
            .navigationTitle("Configura tu inicio")
            .navigationBarTitleDisplayMode(.inline)
        }
        .task { await model.load(accessToken: session.accessToken) }
    }

    private var progress: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Paso \(step + 1) de \(totalSteps)")
                Spacer()
                Text(stepTitle)
            }
            .font(.caption.weight(.semibold))
            .foregroundStyle(.secondary)
            ProgressView(value: Double(step + 1), total: Double(totalSteps))
                .tint(VLTheme.indigo)
                .accessibilityLabel("Progreso de configuración")
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.largeTitle.weight(.semibold)).fixedSize(horizontal: false, vertical: true)
            Text(subtitle).font(.body).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
        }
    }

    @ViewBuilder
    private func content(model: InterestsViewModel) -> some View {
        if model.isLoading && model.categories.isEmpty {
            ProgressView("Cargando opciones…").frame(maxWidth: .infinity, minHeight: 220)
        } else if step == 0 {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 145), spacing: 12)], spacing: 12) {
                ForEach(model.categories, id: \.id) { category in
                    choiceCard(
                        title: category.name,
                        detail: nil,
                        symbol: categorySystemImage(category),
                        selected: model.selectedIDs.contains(category.id)
                    ) { toggle(category.id, in: &model.selectedIDs) }
                }
            }
        } else if step == 1 {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 155), spacing: 12)], spacing: 12) {
                ForEach(discoveryPreferenceOptions) { preference in
                    choiceCard(
                        title: preference.title,
                        detail: preference.detail,
                        symbol: preference.symbol,
                        selected: model.preferences.contains(preference.id)
                    ) { toggle(preference.id, in: &model.preferences) }
                }
            }
        } else {
            summary(model: model)
        }
    }

    private func choiceCard(title: String, detail: String?, symbol: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Image(systemName: symbol).font(.title3)
                    Spacer()
                    Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                }
                .foregroundStyle(selected ? VLTheme.indigo : .secondary)
                Spacer(minLength: 0)
                VStack(alignment: .leading, spacing: 4) {
                    Text(title).font(.headline).foregroundStyle(.primary)
                    if let detail { Text(detail).font(.caption).foregroundStyle(.secondary).lineLimit(3) }
                }
            }
            .frame(maxWidth: .infinity, minHeight: detail == nil ? 104 : 136, alignment: .leading)
            .padding(16)
            .background(selected ? VLTheme.indigo.opacity(0.09) : VLTheme.surface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(selected ? VLTheme.indigo : VLTheme.outline, lineWidth: selected ? 1.5 : 1)
            }
        }
        .buttonStyle(.plain)
        .accessibilityValue(selected ? "Seleccionado" : "No seleccionado")
    }

    private func summary(model: InterestsViewModel) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            summaryRow(symbol: "square.grid.2x2", value: model.selectedIDs.count, label: "temas para priorizar")
            Divider().padding(.leading, 52)
            summaryRow(symbol: "slider.horizontal.3", value: model.preferences.count, label: "formas de disfrutar Loja")
            Divider().padding(.leading, 52)
            HStack(alignment: .top, spacing: 14) {
                Image(systemName: "arrow.triangle.2.circlepath").frame(width: 38, height: 38).foregroundStyle(VLTheme.indigo)
                Text("La cartelera se ajustará cuando cambies estas preferencias desde Cuenta.")
                    .font(.subheadline).foregroundStyle(.secondary)
            }
            .padding(16)
        }
        .background(VLTheme.surface, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay { RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(VLTheme.outline) }
    }

    private func summaryRow(symbol: String, value: Int, label: String) -> some View {
        HStack(spacing: 14) {
            Image(systemName: symbol).frame(width: 38, height: 38).foregroundStyle(VLTheme.indigo)
            Text("\(value)").font(.title2.weight(.semibold)).monospacedDigit()
            Text(label).font(.subheadline).foregroundStyle(.secondary)
        }
        .padding(16)
    }

    private func actionBar(model: InterestsViewModel) -> some View {
        HStack(spacing: 12) {
            if step > 0 {
                Button("Atrás") {
                    if reduceMotion { step -= 1 } else { withAnimation(.easeOut(duration: 0.2)) { step -= 1 } }
                }
                .buttonStyle(.bordered)
                .frame(minHeight: 44)
            }
            Button {
                if step < totalSteps - 1 {
                    if reduceMotion { step += 1 } else { withAnimation(.easeOut(duration: 0.2)) { step += 1 } }
                } else {
                    Task { if await model.save(accessToken: session.accessToken) { onFinished() } }
                }
            } label: {
                if model.isSaving { ProgressView().tint(.white) }
                else { Text(step == totalSteps - 1 ? "Aplicar a mi inicio" : "Continuar") }
            }
            .buttonStyle(.borderedProminent)
            .tint(VLTheme.indigo)
            .frame(maxWidth: .infinity, minHeight: 44)
            .disabled(!canContinue(model: model) || model.isSaving)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(.bar)
    }

    private func canContinue(model: InterestsViewModel) -> Bool {
        if step == 0 { return model.selectedIDs.count >= 3 }
        if step == 1 { return !model.preferences.isEmpty }
        return true
    }

    private var stepTitle: String { ["Intereses", "Tu estilo", "Resumen"][step] }
    private var title: String { ["¿Qué quieres encontrar en Loja?", "¿Cómo te gusta vivir la ciudad?", "Tu inicio ya tiene una dirección"][step] }
    private var subtitle: String { ["Elige al menos tres temas. Esto define qué aparece primero.", "Combina las opciones que describen tus planes habituales.", "Usaremos estas señales para ordenar eventos y lugares. No necesitas agregar un negocio."][step] }

    private func toggle(_ value: String, in selection: inout Set<String>) {
        if selection.contains(value) { selection.remove(value) } else { selection.insert(value) }
    }

    private func skip() async {
        guard let token = session.accessToken else { onFinished(); return }
        isSkipping = true
        defer { isSkipping = false }
        let _: OnboardingSkipResponse? = try? await APIClient.shared.post("/me/onboarding/skip", body: EmptyRequest(), bearer: token)
        onFinished()
    }
}

private struct EmptyRequest: Encodable, Sendable {}
