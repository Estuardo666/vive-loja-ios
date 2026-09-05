import MapKit
import SwiftUI

enum RouteFormat {
    static func distance(_ meters: CLLocationDistance) -> String {
        if meters < 1_000 { return "\(Int(meters.rounded())) m" }
        let kilometres = meters / 1_000
        if kilometres >= 10 || kilometres == kilometres.rounded() {
            return "\(Int(kilometres.rounded())) km"
        }
        return String(format: "%.1f km", kilometres)
    }

    static func duration(_ seconds: TimeInterval) -> String {
        let minutes = Int((seconds / 60).rounded())
        if minutes < 60 { return "\(max(minutes, 1)) min" }
        let hours = minutes / 60
        let rest = minutes % 60
        return rest == 0 ? "\(hours) h" : "\(hours) h \(rest) min"
    }
}

/// Guidance banner pinned over the map: what to do next, how far, and how much
/// of the trip is left. No speech — this is a silent, foreground-only guide.
struct RouteGuidanceBanner: View {
    let service: RouteService
    let onChangeMode: (RouteService.Mode) -> Void
    let onShowSteps: () -> Void
    let onStop: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if service.hasArrived {
                Label("Llegaste a \(service.destination?.name ?? "tu destino")", systemImage: "flag.checkered")
                    .font(.headline)
            } else if service.isRerouting {
                Label("Recalculando la ruta…", systemImage: "arrow.triangle.2.circlepath")
                    .font(.subheadline.weight(.semibold))
            } else if let step = service.currentStep {
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: "arrow.turn.up.right")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(VLTheme.indigo)
                        .frame(width: 34, height: 34)
                        .background(VLTheme.indigo.opacity(0.14), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                    VStack(alignment: .leading, spacing: 3) {
                        if service.distanceToNextManeuver > 0 {
                            Text(RouteFormat.distance(service.distanceToNextManeuver))
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary)
                        }
                        Text(step.instructions).font(.subheadline.weight(.semibold)).lineLimit(3)
                    }
                    Spacer(minLength: 0)
                }
            } else if service.isCalculating {
                Label("Calculando la ruta…", systemImage: "point.topleft.down.to.point.bottomright.curvepath")
                    .font(.subheadline.weight(.semibold))
            }

            if let message = service.errorMessage {
                Text(message).font(.caption).foregroundStyle(VLTheme.coral)
            }

            HStack(spacing: 10) {
                if !service.hasArrived {
                    Text("\(RouteFormat.duration(service.remainingTime)) · \(RouteFormat.distance(service.remainingDistance))")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
                Picker("Modo", selection: Binding(get: { service.mode }, set: onChangeMode)) {
                    ForEach(RouteService.Mode.allCases) { mode in
                        Image(systemName: mode.symbol).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 108)
                .accessibilityLabel("Modo de viaje")
                Button(action: onShowSteps) { Image(systemName: "list.bullet") }
                    .buttonStyle(.bordered)
                    .accessibilityLabel("Ver indicaciones")
                Button(action: onStop) { Image(systemName: "xmark") }
                    .buttonStyle(.bordered)
                    .tint(VLTheme.coral)
                    .accessibilityLabel("Terminar ruta")
            }
        }
        .padding(14)
        .vlGlass(radius: 20)
        .padding(.horizontal, 16)
        .accessibilityIdentifier("route-guidance-banner")
    }
}

/// Full list of manoeuvres, with the current one highlighted.
struct RouteStepsSheet: View {
    let service: RouteService
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(Array(service.steps.enumerated()), id: \.offset) { index, step in
                        HStack(alignment: .top, spacing: 12) {
                            Image(systemName: index == service.currentStepIndex ? "location.fill" : "arrow.turn.up.right")
                                .foregroundStyle(index == service.currentStepIndex ? VLTheme.indigo : .secondary)
                                .frame(width: 22)
                            VStack(alignment: .leading, spacing: 3) {
                                Text(step.instructions)
                                    .font(.subheadline.weight(index == service.currentStepIndex ? .semibold : .regular))
                                if step.distance > 0 {
                                    Text(RouteFormat.distance(step.distance))
                                        .font(.caption).foregroundStyle(.secondary)
                                }
                            }
                        }
                        .listRowBackground(index == service.currentStepIndex ? VLTheme.indigo.opacity(0.15) : VLTheme.surface)
                    }
                } header: {
                    if let destination = service.destination {
                        Text("Hacia \(destination.name)")
                    }
                }
            }
            .vlScreen()
            .navigationTitle("Indicaciones")
            .toolbarTitleDisplayMode(.inlineLarge)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Listo") { dismiss() } }
            }
        }
    }
}
