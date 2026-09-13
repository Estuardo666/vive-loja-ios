import Observation
import SwiftUI

@MainActor
@Observable
final class TicketPaymentResultViewModel {
    private let api: APIClient
    private let accessStore: TicketAccessStore
    private(set) var order: MobileTicketOrder?
    private(set) var isLoading = false
    var errorMessage: String?

    init(api: APIClient = .shared, accessStore: TicketAccessStore = TicketAccessStore()) {
        self.api = api
        self.accessStore = accessStore
    }

    func load(token: String) async {
        _ = accessStore.add(TicketAccessReference(kind: .order, token: token))
        isLoading = true
        defer { isLoading = false }
        do {
            order = try await api.get("/ticketing/orders/\(token.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? token)")
            errorMessage = nil
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? "No se pudo consultar el resultado del pago."
        }
    }
}

struct TicketPaymentResultView: View {
    let result: DeepLinkRouter.CheckoutResult
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @State private var model = TicketPaymentResultViewModel()

    private var status: String {
        model.order?.status ?? result.status.uppercased()
    }

    private var isPaid: Bool { status == "PAID" }
    private var isFailed: Bool { ["FAILED", "EXPIRED"].contains(status) || result.status == "failed" }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    Image(systemName: isPaid ? "checkmark.circle.fill" : isFailed ? "xmark.circle.fill" : "clock.badge.questionmark.fill")
                        .font(.system(size: 72))
                        .foregroundStyle(isPaid ? Color.green : isFailed ? Color.red : Color.orange)
                        .accessibilityHidden(true)

                    VStack(spacing: 8) {
                        Text(isPaid ? "¡Compra confirmada!" : isFailed ? "No se completó el pago" : "Confirmando tu pago…")
                            .font(.title2.bold())
                            .multilineTextAlignment(.center)
                        Text(message)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }

                    if let order = model.order {
                        VStack(spacing: 12) {
                            resultRow("Evento", value: order.event.title)
                            resultRow("Entradas", value: "\(order.tickets.count)")
                            resultRow("Total", value: formatMoney(order.totalCents, currency: order.currency))
                        }
                        .padding(18)
                        .background(.background)
                        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    }

                    if let errorMessage = model.errorMessage {
                        Text(errorMessage).font(.footnote).foregroundStyle(.red).multilineTextAlignment(.center)
                    }

                    VStack(spacing: 12) {
                        if isPaid {
                            NavigationLink(destination: TicketsView()) {
                                Label("Ver mis entradas", systemImage: "ticket.fill")
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.borderedProminent)
                            .controlSize(.large)
                        } else if isFailed, status == "PENDING_PAYMENT" {
                            Button {
                                openURL(AppEnvironment.current.ticketCheckoutURL(token: result.token))
                            } label: {
                                Label("Intentar pago de nuevo", systemImage: "arrow.clockwise")
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.borderedProminent)
                            .controlSize(.large)
                        } else if isFailed, let slug = model.order?.event.slug {
                            NavigationLink(destination: EventTicketingView(slug: slug)) {
                                Label("Intentar de nuevo", systemImage: "arrow.clockwise")
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.borderedProminent)
                            .controlSize(.large)
                        } else {
                            Button {
                                Task { await model.load(token: result.token) }
                            } label: {
                                Label("Consultar de nuevo", systemImage: "arrow.clockwise")
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.borderedProminent)
                            .controlSize(.large)
                            .disabled(model.isLoading)
                        }

                        Button("Cerrar") { dismiss() }
                            .buttonStyle(.bordered)
                            .controlSize(.large)
                    }
                }
                .padding(24)
                .frame(maxWidth: 560)
                .frame(maxWidth: .infinity)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Resultado del pago")
            .navigationBarTitleDisplayMode(.inline)
            .overlay { if model.isLoading && model.order == nil { ProgressView() } }
            .task { await model.load(token: result.token) }
        }
    }

    private var message: String {
        if isPaid { return "Tus entradas están listas y guardadas en este dispositivo." }
        if isFailed && status == "PENDING_PAYMENT" { return "El pago se canceló antes de completarse. Tu reserva sigue activa y puedes intentarlo otra vez." }
        if isFailed { return "No se realizó ningún cobro. Puedes volver al evento e intentarlo nuevamente." }
        return "Estamos comprobando la respuesta de PayPhone."
    }

    @ViewBuilder
    private func resultRow(_ label: String, value: String) -> some View {
        HStack { Text(label).foregroundStyle(.secondary); Spacer(); Text(value).fontWeight(.semibold).multilineTextAlignment(.trailing) }
    }

    private func formatMoney(_ cents: Int, currency: String) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = currency
        return formatter.string(from: NSNumber(value: Double(cents) / 100)) ?? "\(Double(cents) / 100)"
    }
}
