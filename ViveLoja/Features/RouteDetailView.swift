import CoreLocation
import MapKit
import SwiftUI

@MainActor
@Observable
final class RouteDetailViewModel {
    private(set) var route: MobileRouteDetail?
    private(set) var isLoading = false
    var errorMessage: String?
    /// 1-based, mirrors `MobileRouteDay.day`.
    var selectedDay = 1

    private let api: APIClient

    init(api: APIClient = .shared) {
        self.api = api
    }

    var itinerary: [MobileRouteDay] { route?.resolvedItinerary ?? [] }
    var isMultiDay: Bool { itinerary.count > 1 }

    var stopsForSelectedDay: [MobileRouteStop] {
        guard let route else { return [] }
        // Single-day itineraries show every stop, so a route created before
        // days existed still renders in full.
        guard isMultiDay else { return route.stops }
        return itinerary.first { $0.day == selectedDay }?.stops ?? []
    }

    func load(slug: String) async {
        guard !isLoading else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            let detail: MobileRouteDetail = try await api.get("/routes/\(slug)")
            route = detail
            selectedDay = detail.resolvedItinerary.first?.day ?? 1
            errorMessage = nil
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? "No se pudo cargar la ruta."
        }
    }
}

/// Day-by-day itinerary: a day picker, the ordered stops of that day and a map
/// of the same day's geometry. Navigation between stops reuses `RouteService`,
/// which already drives MKDirections for a single destination.
struct RouteDetailView: View {
    let slug: String
    /// Shown while the detail loads, so a deep link has a title immediately.
    var placeholderTitle: String?

    @State private var model = RouteDetailViewModel()

    var body: some View {
        @Bindable var model = model
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                header
                if model.isMultiDay { dayPicker }
                map
                stopList
            }
            .padding(20)
        }
        .navigationTitle(model.route?.title ?? placeholderTitle ?? "Ruta")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if let route = model.route {
                ToolbarItem(placement: .topBarTrailing) {
                    ShareLink(item: AppEnvironment.current.shareURL(for: .route, slug: route.slug)) {
                        Image(systemName: "square.and.arrow.up")
                    }
                    .accessibilityLabel("Compartir ruta")
                }
            }
        }
        .overlay {
            if model.isLoading && model.route == nil {
                ProgressView("Cargando itinerario…")
            } else if let errorMessage = model.errorMessage, model.route == nil {
                ContentUnavailableView("No se pudo cargar", systemImage: "map", description: Text(errorMessage))
            }
        }
        .task { await model.load(slug: slug) }
    }
}

private extension RouteDetailView {
    @ViewBuilder
    var header: some View {
        if let route = model.route {
            VStack(alignment: .leading, spacing: 10) {
                Text(route.title).font(.title2.weight(.bold))
                Text(route.description).font(.body).foregroundStyle(.secondary)

                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 14) { metadata(for: route) }
                    VStack(alignment: .leading, spacing: 6) { metadata(for: route) }
                }
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder
    func metadata(for route: MobileRouteDetail) -> some View {
        if model.isMultiDay {
            Label("\(model.itinerary.count) días", systemImage: "calendar")
        }
        Label("\(route.stops.count) paradas", systemImage: "mappin.and.ellipse")
        if let distance = route.distanceMeters {
            Label(RouteDetailView.formatDistance(distance), systemImage: "figure.walk")
        }
        if let minutes = route.estimatedMinutes {
            Label(RouteDetailView.formatMinutes(minutes), systemImage: "clock")
        }
    }

    var dayPicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(model.itinerary) { day in
                    Button {
                        model.selectedDay = day.day
                    } label: {
                        Text("Día \(day.day)")
                            .font(.subheadline.weight(.semibold))
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(day.day == model.selectedDay ? VLTheme.indigo : Color.secondary.opacity(0.2))
                    .foregroundStyle(day.day == model.selectedDay ? Color.white : Color.primary)
                    .accessibilityAddTraits(day.day == model.selectedDay ? [.isSelected] : [])
                }
            }
            .padding(.vertical, 2)
        }
        .accessibilityLabel("Días del itinerario")
    }

    @ViewBuilder
    var map: some View {
        let annotations = model.stopsForSelectedDay.compactMap(RouteStopAnnotation.init)
        if annotations.isEmpty {
            EmptyView()
        } else {
            RouteItineraryMap(annotations: annotations)
                .frame(height: 220)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                .accessibilityLabel("Mapa del día \(model.selectedDay)")
        }
    }

    @ViewBuilder
    var stopList: some View {
        let stops = model.stopsForSelectedDay
        if stops.isEmpty && model.route != nil {
            Text("Este día aún no tiene paradas.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        } else {
            VStack(alignment: .leading, spacing: 14) {
                ForEach(Array(stops.enumerated()), id: \.element.id) { index, stop in
                    RouteStopRow(stop: stop, position: index + 1)
                }
            }
        }
    }

    static func formatDistance(_ meters: Int) -> String {
        meters >= 1_000
            ? String(format: "%.1f km", Double(meters) / 1_000)
            : "\(meters) m"
    }

    static func formatMinutes(_ minutes: Int) -> String {
        let hours = minutes / 60
        let rest = minutes % 60
        if hours == 0 { return "\(rest) min" }
        return rest == 0 ? "\(hours) h" : "\(hours) h \(rest) min"
    }
}

private struct RouteStopRow: View {
    let stop: MobileRouteStop
    let position: Int

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Text("\(position)")
                .font(.caption.weight(.bold))
                .foregroundStyle(.white)
                .frame(width: 26, height: 26)
                .background(Circle().fill(VLTheme.indigo))

            VStack(alignment: .leading, spacing: 4) {
                Text(stop.venue?.name ?? stop.title).font(.headline)
                if let subtitle = stop.venue?.location, !subtitle.isEmpty {
                    Text(subtitle).font(.subheadline).foregroundStyle(.secondary)
                }
                if let notes = stop.notes, !notes.isEmpty {
                    Text(notes).font(.subheadline).foregroundStyle(.secondary)
                }
                let timing = [stop.startTime, stop.duration].compactMap { $0 }.joined(separator: " · ")
                if !timing.isEmpty {
                    Label(timing, systemImage: "clock").font(.caption).foregroundStyle(.secondary)
                }
                if let travel = stop.travelMinutes, travel > 0 {
                    Label(
                        "\(RouteDetailView.formatMinutes(travel)) desde la parada anterior",
                        systemImage: "arrow.turn.down.right"
                    )
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
                if let coordinate = stop.coordinate {
                    Button("Cómo llegar", systemImage: "location.fill") {
                        openInMaps(coordinate: coordinate, name: stop.venue?.name ?? stop.title)
                    }
                    .font(.caption.weight(.semibold))
                    .buttonStyle(.bordered)
                    .tint(VLTheme.emerald)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(14)
        .vlGlass(tint: VLTheme.emerald.opacity(0.08))
        .accessibilityElement(children: .combine)
    }

    /// Apple Maps rather than the in-app MKDirections banner: an itinerary stop
    /// is usually the start of a walk the user takes now, away from the phone.
    private func openInMaps(coordinate: (lat: Double, lng: Double), name: String) {
        let placemark = MKPlacemark(
            coordinate: CLLocationCoordinate2D(latitude: coordinate.lat, longitude: coordinate.lng)
        )
        let item = MKMapItem(placemark: placemark)
        item.name = name
        item.openInMaps(launchOptions: [MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeWalking])
    }
}

/// Pin plus the polyline joining the stops of one day, in order.
struct RouteStopAnnotation: Identifiable {
    let id: String
    let title: String
    let coordinate: CLLocationCoordinate2D

    init?(stop: MobileRouteStop) {
        guard let coordinate = stop.coordinate else { return nil }
        self.id = stop.id
        self.title = stop.venue?.name ?? stop.title
        self.coordinate = CLLocationCoordinate2D(latitude: coordinate.lat, longitude: coordinate.lng)
    }
}

private struct RouteItineraryMap: UIViewRepresentable {
    let annotations: [RouteStopAnnotation]

    func makeUIView(context: Context) -> MKMapView {
        let map = MKMapView()
        map.delegate = context.coordinator
        map.isRotateEnabled = false
        map.pointOfInterestFilter = .excludingAll
        return map
    }

    func updateUIView(_ map: MKMapView, context: Context) {
        map.removeAnnotations(map.annotations)
        map.removeOverlays(map.overlays)

        let points = annotations.map { annotation -> MKPointAnnotation in
            let point = MKPointAnnotation()
            point.coordinate = annotation.coordinate
            point.title = annotation.title
            return point
        }
        map.addAnnotations(points)

        if annotations.count > 1 {
            let coordinates = annotations.map(\.coordinate)
            map.addOverlay(MKPolyline(coordinates: coordinates, count: coordinates.count))
        }

        guard !points.isEmpty else { return }
        map.showAnnotations(points, animated: false)
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    final class Coordinator: NSObject, MKMapViewDelegate {
        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            guard let polyline = overlay as? MKPolyline else { return MKOverlayRenderer(overlay: overlay) }
            let renderer = MKPolylineRenderer(polyline: polyline)
            renderer.strokeColor = UIColor(VLTheme.indigo)
            renderer.lineWidth = 4
            renderer.lineDashPattern = [2, 6]
            return renderer
        }
    }
}
