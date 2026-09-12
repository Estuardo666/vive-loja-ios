import Foundation
import Observation
import SwiftUI

@MainActor
@Observable
final class EventTicketingViewModel {
    private let api: APIClient
    var ticketing: MobileTicketing?
    var quantities: [String: Int] = [:]
    var selectedSeats: [String: Set<String>] = [:]
    var hold: MobileTicketHold?
    var checkout: MobileTicketCheckout?
    var isLoading = false
    var isSubmitting = false
    var errorMessage: String?
    let sessionKey = UUID().uuidString

    init(api: APIClient = .shared) { self.api = api }

    func load(slug: String) async {
        guard ticketing == nil else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            ticketing = try await api.get("/events/\(slug.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? slug)/ticketing")
            errorMessage = nil
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? "No se pudo cargar la boletería."
        }
    }

    func quantity(for type: MobileTicketType) -> Int {
        type.kind == "ASSIGNED_SEAT" ? selectedSeats[type.id]?.count ?? 0 : quantities[type.id] ?? 0
    }

    func updateQuantity(for type: MobileTicketType, delta: Int) {
        let current = quantity(for: type)
        let minimum = type.minPerOrder
        let maximum = min(type.maxPerOrder, type.available ?? type.maxPerOrder)
        let next = current == 0 && delta > 0 ? minimum : max(0, min(maximum, current + delta))
        quantities[type.id] = next
        errorMessage = nil
    }

    func toggleSeat(_ seat: MobileSeat, for type: MobileTicketType) {
        var current = selectedSeats[type.id] ?? []
        if current.contains(seat.id) { current.remove(seat.id) }
        else if current.count < type.maxPerOrder { current.insert(seat.id) }
        else { errorMessage = "Puedes seleccionar hasta \(type.maxPerOrder) asientos de este tipo."; return }
        selectedSeats[type.id] = current
        errorMessage = nil
    }

    var selections: [MobileTicketSelection] {
        (ticketing?.ticketTypes ?? []).compactMap { type in
            let count = quantity(for: type)
            guard count > 0 else { return nil }
            let seats = type.kind == "ASSIGNED_SEAT" ? Array(selectedSeats[type.id] ?? []) : nil
            return MobileTicketSelection(ticketTypeId: type.id, quantity: count, eventSeatIds: seats)
        }
    }

    var selectedCount: Int { selections.reduce(0) { $0 + $1.quantity } }

    var subtotalCents: Int {
        selections.reduce(0) { total, selection in
            total + (ticketing?.ticketTypes?.first(where: { $0.id == selection.ticketTypeId })?.priceCents ?? 0) * selection.quantity
        }
    }

    var feeCents: Int {
        guard ticketing?.feeIncidence != nil, ticketing?.feeIncidence != "NONE" else { return 0 }
        let basisPoints = ticketing?.feePercentBps ?? 0
        return (subtotalCents * basisPoints + 5_000) / 10_000 + (ticketing?.feeFixedCents ?? 0)
    }

    var totalCents: Int {
        ticketing?.feeIncidence == "ORGANIZER_ABSORBS" ? subtotalCents : subtotalCents + feeCents
    }

    func reserve(slug: String, accessToken: String?) async {
        guard !selections.isEmpty else { return }
        isSubmitting = true
        errorMessage = nil
        defer { isSubmitting = false }
        do {
            let request = MobileTicketHoldRequest(eventSlug: slug, sessionKey: sessionKey, items: selections)
            hold = try await api.post("/ticketing/holds", body: request, bearer: accessToken, headers: ["Idempotency-Key": UUID().uuidString])
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? "No se pudo reservar la entrada."
        }
    }

    func startCheckout(accessToken: String?, buyer: MobileTicketBuyer) async {
        guard let hold else { return }
        isSubmitting = true
        errorMessage = nil
        defer { isSubmitting = false }
        do {
            checkout = try await api.post("/ticketing/checkouts", body: MobileTicketCheckoutRequest(holdToken: hold.token ?? "", buyerName: buyer.name, buyerEmail: buyer.email, buyerPhone: buyer.phone, billingDocumentId: buyer.billingDocumentId), bearer: accessToken, headers: ["Idempotency-Key": UUID().uuidString])
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? "No se pudo iniciar el pago."
        }
    }
}

struct MobileTicketBuyer: Sendable {
    var name = ""
    var email = ""
    var phone = ""
    var document = ""

    var billingDocumentId: String? {
        let normalized = document.trimmingCharacters(in: .whitespacesAndNewlines)
        return normalized.isEmpty ? nil : normalized
    }
}

struct EventTicketingView: View {
    let slug: String
    @Environment(SessionStore.self) private var session
    @Environment(\.openURL) private var openURL
    @State private var model = EventTicketingViewModel()
    @State private var buyer = MobileTicketBuyer()
    @State private var showCheckout = false

    var body: some View {
        NavigationStack {
            Group {
                if model.isLoading && model.ticketing == nil {
                    ProgressView("Cargando entradas…")
                } else if let ticketing = model.ticketing {
                    content(ticketing)
                } else {
                    ContentUnavailableView("Boletería no disponible", systemImage: "ticket", description: Text(model.errorMessage ?? "Este evento no tiene entradas configuradas."))
                }
            }
            .navigationTitle("Entradas")
            .navigationBarTitleDisplayMode(.inline)
            .vlScreen()
            .task { await model.load(slug: slug) }
            .sheet(isPresented: $showCheckout, onDismiss: { model.checkout = nil }) {
                if let url = model.checkout?.checkoutUrl { VLSafariView(url: url).ignoresSafeArea() }
            }
        }
    }

    @ViewBuilder
    private func content(_ ticketing: MobileTicketing) -> some View {
        if ticketing.mode == "EXTERNAL", let url = ticketing.externalUrl {
            VStack(alignment: .leading, spacing: 16) {
                Label("Compra en \(ticketing.externalProviderLabel ?? "el sitio del organizador")", systemImage: "arrow.up.right.square")
                    .font(.headline)
                Text("Vive Loja te llevará al sitio autorizado para completar la compra.")
                    .font(.subheadline).foregroundStyle(.secondary)
                Button { openURL(url) } label: { Label("Comprar entradas", systemImage: "ticket.fill") }
                    .buttonStyle(.borderedProminent)
            }
            .padding(20)
        } else if ticketing.mode != "INTERNAL" {
            ContentUnavailableView("Entradas no disponibles", systemImage: "ticket", description: Text("El organizador todavía no activó la venta."))
        } else {
            Form {
                selectionSection(ticketing)
                summarySection(ticketing)
                if let hold = model.hold {
                    buyerSection(hold)
                }
                if let errorMessage = model.errorMessage {
                    Section { Text(errorMessage).foregroundStyle(.red) }
                }
            }
        }
    }

    @ViewBuilder
    private func selectionSection(_ ticketing: MobileTicketing) -> some View {
        let ticketTypes = ticketing.ticketTypes ?? []
        Section("Tipos de entrada") {
            ForEach(ticketTypes) { type in
                ticketTypeRow(type, ticketing: ticketing)
            }
        }
    }

    @ViewBuilder
    private func ticketTypeRow(_ type: MobileTicketType, ticketing: MobileTicketing) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text(type.name).font(.headline)
                    if let description = type.description { Text(description).font(.caption).foregroundStyle(.secondary) }
                    Text(formatMoney(type.priceCents, currency: ticketing.currency)).font(.subheadline.weight(.semibold)).foregroundStyle(VLTheme.indigo)
                }
                Spacer()
                if type.kind == "ASSIGNED_SEAT" {
                    Text("\(model.quantity(for: type)) seleccionados").font(.caption).foregroundStyle(.secondary)
                } else {
                    Stepper(value: Binding(get: { model.quantity(for: type) }, set: { model.quantities[type.id] = $0 }), in: 0...min(type.maxPerOrder, type.available ?? type.maxPerOrder)) { Text("\(model.quantity(for: type))") }
                        .labelsHidden()
                }
            }
            if type.kind == "ASSIGNED_SEAT", let seatMap = ticketing.seatMap {
                Text(seatMap.name ?? "Selecciona tus asientos").font(.caption.weight(.semibold))
                let seats = seatMap.seats.filter { ($0.ticketTypeId == nil || $0.ticketTypeId == type.id) && $0.status == "AVAILABLE" }
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 48), spacing: 8)], spacing: 8) {
                    ForEach(seats) { seat in
                        Button { model.toggleSeat(seat, for: type) } label: { Text(seat.seatNumber).frame(maxWidth: .infinity).padding(.vertical, 8) }
                            .buttonStyle(.bordered)
                            .tint(model.selectedSeats[type.id]?.contains(seat.id) == true ? VLTheme.indigo : .secondary)
                            .accessibilityLabel("Asiento \(seat.seatNumber)")
                    }
                }
            }
            if let available = type.available { Text(available > 0 ? "\(available) disponibles" : "Agotado").font(.caption2).foregroundStyle(available > 0 ? Color.secondary : Color.red) }
        }
        .disabled(type.available == 0)
    }

    @ViewBuilder
    private func summarySection(_ ticketing: MobileTicketing) -> some View {
        Section("Resumen") {
            HStack { Text("Entradas"); Spacer(); Text("\(model.selectedCount)").foregroundStyle(.secondary) }
            HStack { Text("Subtotal"); Spacer(); Text(formatMoney(model.subtotalCents, currency: ticketing.currency)) }
            if model.feeCents > 0 { HStack { Text("Tarifa de servicio"); Spacer(); Text(formatMoney(model.feeCents, currency: ticketing.currency)) } }
            HStack { Text("Total").font(.headline); Spacer(); Text(formatMoney(model.totalCents, currency: ticketing.currency)).font(.headline) }
            if model.hold == nil {
                Button { Task { await model.reserve(slug: slug, accessToken: session.accessToken) } } label: { if model.isSubmitting { ProgressView() } else { Label("Continuar", systemImage: "arrow.right") } }
                    .disabled(model.isSubmitting || model.selections.isEmpty || ticketing.status != "READY" && ticketing.status != "ON_SALE")
            }
        }
    }

    @ViewBuilder
    private func buyerSection(_ hold: MobileTicketHold) -> some View {
        Section("Datos del comprador") {
            Text("Reserva activa hasta \(hold.expiresAt.formatted(date: .omitted, time: .shortened))").font(.caption).foregroundStyle(.secondary)
            TextField("Nombre completo", text: Binding(get: { buyer.name }, set: { buyer.name = $0 })).textContentType(.name)
            TextField("Correo electrónico", text: Binding(get: { buyer.email }, set: { buyer.email = $0 })).textContentType(.emailAddress).keyboardType(.emailAddress).textInputAutocapitalization(.never)
            TextField("Teléfono", text: Binding(get: { buyer.phone }, set: { buyer.phone = $0 })).textContentType(.telephoneNumber).keyboardType(.phonePad)
            TextField("Cédula / RUC (opcional)", text: Binding(get: { buyer.document }, set: { buyer.document = $0 })).keyboardType(.numberPad)
            Button { Task { await model.startCheckout(accessToken: session.accessToken, buyer: buyer); if model.checkout?.checkoutUrl != nil { showCheckout = true } else if let checkout = model.checkout, let token = model.hold?.token { openURL(AppEnvironment.current.checkoutResultURL(token: token, clientTransactionId: checkout.clientTransactionId)) } } } label: { if model.isSubmitting { ProgressView() } else { Label("Pagar \(formatMoney(model.totalCents, currency: model.ticketing?.currency ?? "USD"))", systemImage: "lock.fill") } }
                .disabled(model.isSubmitting || buyer.name.trimmingCharacters(in: .whitespacesAndNewlines).count < 2 || !buyer.email.contains("@") || buyer.phone.filter(\.isNumber).count < 7)
        }
    }

    private func formatMoney(_ cents: Int, currency: String?) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = currency ?? "USD"
        return formatter.string(from: NSNumber(value: Double(cents) / 100)) ?? "\(Double(cents) / 100)"
    }
}
