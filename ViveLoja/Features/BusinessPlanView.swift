import Foundation
import Observation
import SwiftUI

@MainActor
@Observable
final class BusinessPlanViewModel {
    private(set) var catalog: MobileBillingCatalog?
    private(set) var account: MobileBusinessAccountSnapshot?
    private(set) var isLoading = false
    private(set) var isSubmitting = false
    var errorMessage: String?
    var collaboratorEmail = ""
    var collaboratorRole = "EDITOR"

    func load(token: String?) async {
        guard let token else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            async let catalogRequest: MobileBillingCatalog = APIClient.shared.get("/billing/catalog")
            async let accountRequest: MobileBusinessAccountSnapshot = APIClient.shared.get("/me/business-account", bearer: token)
            catalog = try await catalogRequest
            account = try await accountRequest
            errorMessage = nil
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? "No se pudo cargar tu plan."
        }
    }

    func activate(plan: MobilePlan, annual: Bool, token: String?) async {
        guard let token else { errorMessage = "Inicia sesión para activar un plan."; return }
        isSubmitting = true
        defer { isSubmitting = false }
        do {
            let order: MobileBillingOrder = try await APIClient.shared.post(
                "/me/billing/checkout",
                body: MobileCheckoutRequest(planSlug: plan.slug, cycle: annual ? "ANNUAL" : "MONTHLY", idempotencyKey: UUID().uuidString, device: "ios"),
                bearer: token
            )
            if var current = account {
                // The next refresh is authoritative; keeping the order visible
                // immediately makes the beta activation feel complete offline.
                current = MobileBusinessAccountSnapshot(account: current.account, plan: current.plan, subscription: current.subscription, usage: current.usage, members: current.members, venues: current.venues, orders: [order] + current.orders)
                account = current
            }
            errorMessage = "Plan activado. Vigente hasta \(order.endsAt?.formatted(date: .abbreviated, time: .omitted) ?? "la fecha indicada")."
            VLFeedback.success()
            await load(token: token)
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? "No se pudo activar el plan."
            VLFeedback.error()
        }
    }

    func addCollaborator(token: String?) async {
        guard let token, collaboratorEmail.contains("@") else { errorMessage = "Ingresa un correo válido."; return }
        isSubmitting = true
        defer { isSubmitting = false }
        do {
            let _: MobileBusinessAccountSnapshot.MobileBusinessMember = try await APIClient.shared.post("/me/business-account/members", body: MobileAddBusinessMemberRequest(email: collaboratorEmail, role: collaboratorRole), bearer: token)
            collaboratorEmail = ""
            errorMessage = "Colaborador actualizado."
            await load(token: token)
        } catch { errorMessage = (error as? LocalizedError)?.errorDescription ?? "No se pudo actualizar el equipo." }
    }
}

struct BusinessPlanView: View {
    @Environment(SessionStore.self) private var session
    @State private var model = BusinessPlanViewModel()
    @State private var annual = false

    var body: some View {
        List {
            if let account = model.account {
                Section("Plan efectivo") {
                    LabeledContent("Plan", value: account.plan.name)
                    LabeledContent("Origen", value: account.plan.source == "ADMIN_OVERRIDE" ? "Asignado por Vive Loja" : "Heredado por la cuenta")
                    LabeledContent("Ubicaciones", value: "\(account.usage.locations.used) / \(limit(account.usage.locations.limit))")
                    LabeledContent("Miembros", value: "\(account.usage.members.used) / \(limit(account.usage.members.limit))")
                    if let credits = account.usage.boostCredits {
                        LabeledContent("Impulsos usados este mes", value: "\(credits.used) / \(limit(credits.limit))")
                    }
                }
                Section("Uso por local") {
                    ForEach(account.venues, id: \.id) { venue in
                        VStack(alignment: .leading, spacing: 5) {
                            Text(venue.name).font(.headline)
                            Text("Multimedia \(venue.media.used)/\(limit(venue.media.limit)) · eventos \(venue.events.used)/\(limit(venue.events.limit)) · promociones \(venue.promotions.used)/\(limit(venue.promotions.limit))")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }
                if !account.orders.isEmpty {
                    Section("Actividad reciente") {
                        ForEach(account.orders.prefix(8)) { order in
                            LabeledContent(order.plan?.name ?? order.addon?.name ?? "Operación") {
                                Text(order.status).font(.caption)
                            }
                        }
                    }
                }
                Section("Equipo") {
                    ForEach(account.members, id: \.id) { member in
                        LabeledContent(member.user.name ?? member.user.email, value: member.role)
                    }
                    if ["OWNER", "ADMIN"].contains(account.account?.role ?? "") {
                        TextField("correo@ejemplo.com", text: $model.collaboratorEmail)
                            .textInputAutocapitalization(.never).keyboardType(.emailAddress)
                        Picker("Rol", selection: $model.collaboratorRole) {
                            Text("Editor").tag("EDITOR")
                            Text("Administrador").tag("ADMIN")
                        }
                        Button("Añadir o actualizar") { Task { await model.addCollaborator(token: session.accessToken) } }
                            .disabled(model.isSubmitting || !model.collaboratorEmail.contains("@"))
                    }
                }
            }
            Section {
                Picker("Ciclo", selection: $annual) {
                    Text("Mensual").tag(false)
                    Text("Anual · ahorra 17%").tag(true)
                }
                .pickerStyle(.segmented)
            }
            if let plans = model.catalog?.plans {
                ForEach(plans) { plan in
                    planCard(plan)
                }
            } else if model.isLoading {
                Section { ProgressView("Cargando planes…") }
            }
            if let error = model.errorMessage {
                Section { Text(error).font(.subheadline).foregroundStyle(error.hasPrefix("Plan activado") ? VLTheme.emerald : .red) }
            }
            Section("Beta") {
                Text("Activación beta sin costo. No pedimos tarjeta, no cobramos y no renovamos automáticamente.")
                    .font(.subheadline).foregroundStyle(.secondary)
            }
        }
        .vlScreen()
        .navigationTitle("Mi plan")
        .navigationBarTitleDisplayMode(.inline)
        .refreshable { await model.load(token: session.accessToken) }
        .task { await model.load(token: session.accessToken) }
    }

    private func limit(_ value: Int?) -> String { value.map(String.init) ?? "∞" }

    @ViewBuilder
    private func planCard(_ plan: MobilePlan) -> some View {
        let isCurrent = model.account?.plan.slug == plan.slug
        let isRed = plan.slug == "red"
        Section {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text(plan.name).font(.headline)
                    Spacer()
                    if isCurrent { Text("Actual").font(.caption.weight(.semibold)).foregroundStyle(.secondary) }
                }
                if let description = plan.description { Text(description).font(.subheadline).foregroundStyle(.secondary) }
                Text(price(plan)).font(.title2.weight(.semibold).monospacedDigit())
                if !isCurrent {
                    if isRed {
                        Text("Habla con Vive Loja para configurarlo.").font(.subheadline).foregroundStyle(.secondary)
                    } else {
                        Button {
                            Task { await model.activate(plan: plan, annual: annual, token: session.accessToken) }
                        } label: {
                            if model.isSubmitting { ProgressView() } else { Text("Activar beta sin costo") }
                        }
                        .buttonStyle(.borderedProminent)
                        .frame(minHeight: 44)
                        .disabled(model.isSubmitting || model.catalog?.simulation.enabled != true)
                    }
                }
            }
        }
    }

    private func price(_ plan: MobilePlan) -> String {
        if plan.slug == "red" { return "Desde $99" }
        let value = annual ? (plan.annualPrice ?? 0) : (plan.monthlyPrice ?? 0)
        return String(format: "$%.2f", value)
    }
}
