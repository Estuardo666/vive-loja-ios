import SwiftUI

struct AgendaEvent: Decodable, Identifiable, Sendable {
    let id: String
    let title: String
    let slug: String
    let image: URL?
    let startDate: Date
    let location: String
    let price: Double?
}

struct AgendaView: View {
    @State private var period = "today"
    @State private var events: [AgendaEvent] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    private let periods = [("today", "Hoy"), ("tomorrow", "Mañana"), ("weekend", "Fin de semana"), ("upcoming", "Próximos 30 días")]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack {
                        ForEach(periods, id: \.0) { value in
                            Button(value.1) { period = value.0 }
                                .buttonStyle(.borderedProminent)
                                .tint(period == value.0 ? VLTheme.indigo : .secondary)
                                .accessibilityAddTraits(period == value.0 ? .isSelected : [])
                        }
                    }
                }
                if isLoading { ProgressView("Cargando agenda…") }
                if let errorMessage {
                    Text(errorMessage)
                    Button("Reintentar") { Task { await load() } }
                } else if !isLoading && events.isEmpty { Text("No hay eventos publicados para estas fechas.") }
                ForEach(groupedDays, id: \.self) { day in
                    Text(dayLabel(day)).font(.headline)
                    ForEach(events.filter { calendar.startOfDay(for: $0.startDate) == day }) { event in
                        NavigationLink {
                            DeepLinkDestinationView(destination: .event(slug: event.slug))
                        } label: {
                            VStack(alignment: .leading, spacing: 10) {
                                VLAsyncImage(url: event.image, height: 200).clipped()
                                VStack(alignment: .leading, spacing: 6) {
                                    Text("\(TodayInLojaView.eventTime(event.startDate)) · \(event.price.map { $0 == 0 ? "Gratis" : String(format: "$%.2f", $0) } ?? "Consultar precio")")
                                        .font(.subheadline.weight(.semibold)).foregroundStyle(VLTheme.indigo)
                                    Text(event.title).font(.title3.bold())
                                    Text(event.location).font(.subheadline).foregroundStyle(.secondary)
                                }.padding([.horizontal, .bottom], 14)
                            }.background(VLTheme.surface).clipShape(RoundedRectangle(cornerRadius: 18))
                        }.buttonStyle(.plain)
                    }
                }
            }.padding(20)
        }
        .vlScreen()
        .navigationTitle("Agenda de Loja")
        .task(id: period) { await load() }
        .refreshable { await load() }
    }

    private var calendar: Calendar {
        var value = Calendar(identifier: .gregorian)
        value.timeZone = TimeZone(identifier: "America/Guayaquil")!
        return value
    }
    private var groupedDays: [Date] { Array(Set(events.map { calendar.startOfDay(for: $0.startDate) })).sorted() }
    private func dayLabel(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "es_EC")
        formatter.timeZone = calendar.timeZone
        formatter.dateFormat = "EEEE d 'de' MMMM"
        return formatter.string(from: date)
    }
    @MainActor private func load() async {
        let requestedPeriod = period
        isLoading = true
        errorMessage = nil
        events = []
        do {
            let result: [AgendaEvent] = try await APIClient.shared.get("/agenda", query: [URLQueryItem(name: "period", value: requestedPeriod)])
            guard !Task.isCancelled, period == requestedPeriod else { return }
            events = result
        } catch {
            guard !Task.isCancelled, period == requestedPeriod else { return }
            errorMessage = "No pudimos cargar la agenda."
        }
        isLoading = false
    }
}
