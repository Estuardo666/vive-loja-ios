import Foundation
import Observation
import SwiftUI

@MainActor
@Observable
final class ReservationsViewModel {
    var reservations: [MobileReservation] = []
    var isLoading = false
    var errorMessage: String?

    func load(accessToken: String?) async {
        guard let accessToken else { reservations = []; return }
        isLoading = true
        defer { isLoading = false }
        do {
            reservations = try await APIClient.shared.get("/me/reservations", bearer: accessToken)
            errorMessage = nil
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? "No se pudieron cargar tus reservas."
        }
    }

    func cancel(_ reservation: MobileReservation, reason: String? = nil, accessToken: String?) async -> Bool {
        guard let accessToken else { return false }
        do {
            let updated: MobileReservation = try await APIClient.shared.patch(
                "/me/reservations/\(reservation.id)",
                body: CancelReservationRequest(status: "CANCELLED", cancelReason: reason),
                bearer: accessToken
            )
            if let index = reservations.firstIndex(where: { $0.id == updated.id }) { reservations[index] = updated }
            VLFeedback.success()
            return true
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? "No se pudo cancelar la reserva."
            VLFeedback.error()
            return false
        }
    }
}

struct ReservationsView: View {
    @Environment(SessionStore.self) private var session
    @State private var model = ReservationsViewModel()

    var body: some View {
        Group {
            if model.isLoading && model.reservations.isEmpty {
                ProgressView("Cargando reservas…")
            } else if let error = model.errorMessage, model.reservations.isEmpty {
                ContentUnavailableView("Sin conexión", systemImage: "wifi.exclamationmark", description: Text(error))
            } else if model.reservations.isEmpty {
                ContentUnavailableView("Aún no tienes reservas", systemImage: "calendar.badge.clock", description: Text("Cuando reserves un lugar, aparecerá aquí."))
            } else {
                List(model.reservations) { reservation in
                    VStack(alignment: .leading, spacing: 6) {
                        Text(reservation.venue?.name ?? reservation.event?.title ?? "Reserva en Loja").font(.headline)
                        Label(reservation.date.formatted(date: .long, time: .omitted) + " · " + reservation.time, systemImage: "calendar")
                            .font(.subheadline).foregroundStyle(.secondary)
                        Label("\(reservation.partySize) personas", systemImage: "person.2")
                            .font(.caption).foregroundStyle(.secondary)
                        Text(reservation.status.capitalized).font(.caption.weight(.semibold)).foregroundStyle(VLTheme.indigo)
                    }
                    .padding(.vertical, 6)
                    .accessibilityElement(children: .combine)
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        if reservation.status.uppercased() != "CANCELLED" {
                            Button("Cancelar", role: .destructive) {
                                Task { _ = await model.cancel(reservation, accessToken: session.accessToken) }
                            }
                        }
                    }
                }
                .listStyle(.insetGrouped)
            }
        }
        .navigationTitle("Mis reservas")
        .refreshable { await model.load(accessToken: session.accessToken) }
        .task(id: session.user?.id) { await model.load(accessToken: session.accessToken) }
    }
}
