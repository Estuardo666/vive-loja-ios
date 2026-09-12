import Observation
import SwiftUI

@MainActor
@Observable
final class TicketsViewModel {
    private let api: APIClient
    private(set) var orders: [MobileTicketOrder] = []
    private(set) var isLoading = false
    var errorMessage: String?

    init(api: APIClient = .shared) { self.api = api }

    func load(accessToken: String?) async {
        guard let accessToken else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            orders = try await api.get("/me/tickets", bearer: accessToken)
            errorMessage = nil
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? "No se pudieron cargar tus entradas."
        }
    }
}

struct TicketsView: View {
    @Environment(SessionStore.self) private var session
    @State private var model = TicketsViewModel()

    var body: some View {
        NavigationStack {
            List {
                if let errorMessage = model.errorMessage {
                    Section { Text(errorMessage).foregroundStyle(.red) }
                }
                if model.orders.isEmpty && !model.isLoading && model.errorMessage == nil {
                    ContentUnavailableView("Aún no tienes entradas", systemImage: "ticket", description: Text("Tus compras confirmadas aparecerán aquí."))
                }
                ForEach(model.orders) { order in
                    Section {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(order.event.title).font(.headline)
                            Text(order.event.startDate.formatted(date: .abbreviated, time: .shortened)).font(.subheadline).foregroundStyle(.secondary)
                            Text(order.event.location).font(.caption).foregroundStyle(.secondary)
                            Text(formatMoney(order.totalCents, currency: order.currency)).font(.subheadline.weight(.semibold)).foregroundStyle(VLTheme.indigo)
                        }
                        ForEach(order.tickets) { ticket in
                            TicketRow(ticket: ticket)
                        }
                    } header: {
                        Text(order.status == "REFUNDED" ? "Devuelta" : "Confirmada")
                    }
                }
            }
            .vlScreen()
            .navigationTitle("Mis entradas")
            .overlay { if model.isLoading && model.orders.isEmpty { ProgressView() } }
            .refreshable { await model.load(accessToken: session.accessToken) }
            .task { await model.load(accessToken: session.accessToken) }
        }
    }

    private func formatMoney(_ cents: Int, currency: String) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = currency
        return formatter.string(from: NSNumber(value: Double(cents) / 100)) ?? "\(Double(cents) / 100)"
    }
}

private struct TicketRow: View {
    let ticket: MobileTicket

    var body: some View {
        HStack(spacing: 14) {
            AsyncImage(url: ticket.qrImageUrl) { phase in
                if let image = phase.image { image.resizable().interpolation(.none).scaledToFit() }
                else if phase.error != nil { Image(systemName: "qrcode").font(.largeTitle).foregroundStyle(.secondary) }
                else { ProgressView() }
            }
            .frame(width: 92, height: 92)
            .background(.white)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            VStack(alignment: .leading, spacing: 4) {
                Text(ticket.ticketType.name).font(.subheadline.weight(.semibold))
                Text(ticket.code).font(.caption.monospaced()).foregroundStyle(.secondary)
                if let seatLabel = ticket.seatLabel { Text(seatLabel).font(.caption).foregroundStyle(.secondary) }
                Label(ticket.status == "CHECKED_IN" ? "Usada" : "Válida", systemImage: ticket.status == "CHECKED_IN" ? "checkmark.seal.fill" : "checkmark.seal")
                    .font(.caption.weight(.semibold)).foregroundStyle(ticket.status == "CHECKED_IN" ? .secondary : .green)
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
    }
}
