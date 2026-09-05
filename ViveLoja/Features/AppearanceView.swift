import SwiftUI
import UIKit

/// Cuenta → Apariencia. Theme family, the flavours that family ships, and
/// light / dark / system, each previewed with the colours it actually applies.
struct AppearanceView: View {
    @Environment(ThemeStore.self) private var theme

    var body: some View {
        @Bindable var theme = theme

        List {
            Section("Tema") {
                ForEach(VLPalette.allCases) { palette in
                    Button {
                        theme.palette = palette
                    } label: {
                        ThemeRow(
                            title: palette.label,
                            detail: palette.detail,
                            flavor: previewFlavor(for: palette),
                            isSelected: theme.palette == palette
                        )
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("palette-\(palette.rawValue)")
                    .accessibilityAddTraits(theme.palette == palette ? .isSelected : [])
                }
            }
            .accessibilityIdentifier("palette-picker")

            if theme.palette.variations.count > 1 {
                Section {
                    ForEach(theme.palette.variations) { variation in
                        Button {
                            theme.variation = variation
                        } label: {
                            ThemeRow(
                                title: variation.label,
                                detail: variation.detail,
                                flavor: variation.flavor,
                                isSelected: theme.variation == variation
                            )
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("variation-\(variation.rawValue)")
                        .accessibilityAddTraits(theme.variation == variation ? .isSelected : [])
                    }
                } header: {
                    Text("Variación")
                } footer: {
                    Text("Latte es el único sabor claro de Catppuccin, así que se usa siempre en modo claro y el sabor que elijas aquí en modo oscuro.")
                }
            }

            Section {
                Picker("Modo", selection: $theme.appearance) {
                    ForEach(VLAppearance.allCases) { mode in
                        Label(mode.label, systemImage: mode.symbol).tag(mode)
                    }
                }
                .pickerStyle(.inline)
                .labelsHidden()
                .accessibilityIdentifier("appearance-picker")
            } header: {
                Text("Modo")
            } footer: {
                Text("«Sistema» sigue el ajuste de iOS.")
            }

            Section("Vista previa") {
                PreviewCard()
                    .listRowInsets(EdgeInsets(top: 12, leading: 16, bottom: 12, trailing: 16))
            }
        }
        .vlScreen()
        .navigationTitle("Apariencia")
        .toolbarTitleDisplayMode(.inlineLarge)
    }

    /// The swatch shown next to a family uses the flavour that family would be
    /// wearing right now, not a fixed one.
    private func previewFlavor(for palette: VLPalette) -> VLFlavor {
        let variation = palette == theme.palette ? theme.variation : palette.variations[0]
        return variation.flavor
    }
}

private struct ThemeRow: View {
    let title: String
    let detail: String
    let flavor: VLFlavor
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 12) {
            Swatches(flavor: flavor)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.body.weight(.semibold)).foregroundStyle(VLTheme.text)
                Text(detail).font(.caption).foregroundStyle(VLTheme.subtext)
            }
            Spacer(minLength: 8)
            Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                .font(.title3)
                .foregroundStyle(isSelected ? VLTheme.indigo : VLTheme.muted)
        }
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }
}

/// Four dots — base, blue, peach, teal — is enough to tell the flavours apart
/// at a glance, which a name alone is not.
private struct Swatches: View {
    let flavor: VLFlavor

    private var slots: [UInt32] { [flavor.blue, flavor.mauve, flavor.peach, flavor.teal] }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color(uiColor: UIColor(rgb: flavor.base)))
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(Color(uiColor: UIColor(rgb: flavor.surface1)), lineWidth: 1)
            HStack(spacing: 3) {
                ForEach(slots, id: \.self) { hex in
                    Circle()
                        .fill(Color(uiColor: UIColor(rgb: hex)))
                        .frame(width: 8, height: 8)
                }
            }
        }
        .frame(width: 52, height: 40)
        .accessibilityHidden(true)
    }
}

/// Shows the tokens the rest of the app draws with, so a choice can be judged
/// here instead of by walking back through the tabs.
private struct PreviewCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Parque Central").font(.headline).foregroundStyle(VLTheme.text)
            Text("Centro histórico · Abierto ahora")
                .font(.subheadline)
                .foregroundStyle(VLTheme.subtext)
            HStack(spacing: 8) {
                Chip(title: "Lugar", color: VLTheme.emerald)
                Chip(title: "Evento", color: VLTheme.coral)
                Chip(title: "Ruta", color: VLTheme.navy)
            }
            Button("Acción principal") {}
                .buttonStyle(.borderedProminent)
                .tint(VLTheme.indigo)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(VLTheme.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(VLTheme.outline, lineWidth: 1)
        }
    }
}

/// The accent is the dot and the border. Tinting the label *and* its background
/// with the same accent is what drops a chip to ~2:1 on the pastel flavours, so
/// the text stays on `text` and the accent only has to clear the 3:1 non-text
/// minimum.
private struct Chip: View {
    let title: String
    let color: Color

    var body: some View {
        HStack(spacing: 5) {
            Circle().fill(color).frame(width: 7, height: 7)
            Text(title).foregroundStyle(VLTheme.text)
        }
        .font(.caption.weight(.semibold))
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(VLTheme.surfaceElevated, in: Capsule())
        .overlay { Capsule().strokeBorder(color.opacity(0.55), lineWidth: 1) }
        .accessibilityElement(children: .combine)
    }
}
