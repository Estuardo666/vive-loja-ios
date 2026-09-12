import Observation
import SwiftUI

@MainActor
@Observable
final class TicketsViewModel {
    private let api: APIClient
    private let accessStore: TicketAccessStore
    private(set) var orders: [MobileTicketOrder] = []
    private(set) var isLoading = false
    var errorMessage: String?

    init(api: APIClient = .shared, accessStore: TicketAccessStore = TicketAccessStore()) {
        self.api = api
        self.accessStore = accessStore
    }

    func load(accessToken: String?) async {
        isLoading = true
        defer { isLoading = false }

        var loadedOrders: [MobileTicketOrder] = []
        var firstError: String?

        if let accessToken {
            do {
                loadedOrders.append(contentsOf: try await api.get("/me/tickets", bearer: accessToken))
            } catch {
                firstError = (error as? LocalizedError)?.errorDescription ?? "No se pudieron cargar tus entradas."
            }
        }

        // Public references are bearer secrets stored in the Keychain. They
        // make guest purchases available on this phone without exposing a
        // discovery endpoint that accepts an arbitrary email address.
        for reference in accessStore.references() {
            do {
                let order: MobileTicketOrder = try await api.get(reference.endpoint)
                loadedOrders.append(order)
            } catch let error as APIError {
                if case .server(_, _, 404) = error {
                    accessStore.remove(reference)
                } else if firstError == nil {
                    firstError = error.errorDescription
                }
            } catch {
                if firstError == nil { firstError = error.localizedDescription }
            }
        }

        var seen = Set<String>()
        orders = loadedOrders.filter { seen.insert($0.id).inserted }
        errorMessage = orders.isEmpty ? firstError : nil
    }

    @discardableResult
    func importReference(from input: String) -> Bool {
        guard let reference = TicketAccessReference.parse(input) else {
            errorMessage = "Pega el enlace privado de una entrada o compra de Vive Loja."
            return false
        }
        guard accessStore.add(reference) else {
            errorMessage = "No se pudo guardar el enlace en este dispositivo."
            return false
        }
        errorMessage = nil
        return true
    }
}

struct TicketsView: View {
    @Environment(SessionStore.self) private var session
    @State private var model = TicketsViewModel()
    @State private var showImportSheet = false
    @State private var importText = ""

    var body: some View {
        NavigationStack {
            List {
                if let errorMessage = model.errorMessage {
                    Section { Text(errorMessage).foregroundStyle(.red) }
                }
                if model.orders.isEmpty && !model.isLoading && model.errorMessage == nil {
                    ContentUnavailableView("Aún no tienes entradas", systemImage: "ticket", description: Text("Tus compras confirmadas o importadas aparecerán aquí."))
                }
                ForEach(model.orders) { order in
                    Section {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(order.event.title).font(.headline)
                            Text(order.event.startDate.formatted(date: .abbreviated, time: .shortened)).font(.subheadline).foregroundStyle(.secondary)
                            Text(order.event.location).font(.caption).foregroundStyle(.secondary)
                            Text("\(order.tickets.count) entrada\(order.tickets.count == 1 ? "" : "s")")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary)
                            Text(formatMoney(order.totalCents, currency: order.currency)).font(.subheadline.weight(.semibold)).foregroundStyle(VLTheme.indigo)
                        }
                        ForEach(order.tickets) { ticket in
                            TicketRow(ticket: ticket)
                        }
                    } header: {
                        Text(statusLabel(order.status))
                    }
                }
            }
            .vlScreen()
            .navigationTitle("Mis entradas")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showImportSheet = true } label: {
                        Label("Agregar entrada", systemImage: "plus")
                    }
                    .accessibilityLabel("Agregar entradas desde un enlace")
                }
            }
            .overlay { if model.isLoading && model.orders.isEmpty { ProgressView() } }
            .refreshable { await model.load(accessToken: session.accessToken) }
            .task { await model.load(accessToken: session.accessToken) }
            .sheet(isPresented: $showImportSheet) {
                NavigationStack {
                    Form {
                        Section("Enlace privado") {
                            Text("Copia desde tu correo el enlace «Abrir entrada y QR» y pégalo aquí. También puedes pegar el enlace «Ver mis entradas» de una compra.")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            TextField("Pega el enlace aquí", text: $importText, axis: .vertical)
                                .lineLimit(3...6)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()
                        }
                        if let errorMessage = model.errorMessage {
                            Section { Text(errorMessage).foregroundStyle(.red) }
                        }
                        Section {
                            Button {
                                guard model.importReference(from: importText) else { return }
                                importText = ""
                                showImportSheet = false
                                Task { await model.load(accessToken: session.accessToken) }
                            } label: {
                                Label("Agregar entradas", systemImage: "checkmark.circle.fill")
                            }
                            .disabled(importText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        }
                    }
                    .vlScreen()
                    .navigationTitle("Agregar entradas")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Cerrar") { showImportSheet = false }
                        }
                    }
                }
                .presentationDetents([.medium, .large])
            }
        }
    }

    private func statusLabel(_ status: String) -> String {
        switch status {
        case "REFUNDED": return "Devuelta"
        case "REFUND_PENDING": return "Reembolso en proceso"
        case "PENDING_PAYMENT": return "Pago pendiente"
        default: return "Confirmada"
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
                    .font(.caption.weight(.semibold)).foregroundStyle(ticket.status == "CHECKED_IN" ? Color.secondary : Color.green)
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
    }
}
