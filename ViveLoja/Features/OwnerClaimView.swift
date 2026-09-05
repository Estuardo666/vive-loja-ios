import PhotosUI
import SwiftUI

@MainActor
@Observable
final class OwnerClaimViewModel {
    enum Step: Int, CaseIterable {
        case details
        case code
        case evidence
        case done
    }

    var step: Step = .details

    // Step 1
    var claimerName = ""
    var claimerEmail = ""
    var claimerPhone = ""
    var claimerRole = ""
    var message = ""

    // Step 2
    var code = ""
    private(set) var attemptsLeft = 5

    // Step 3
    private(set) var confidenceScore = 0
    private(set) var claimId: String?

    var isSubmitting = false
    var errorMessage: String?

    private let api: APIClient

    init(api: APIClient = .shared) {
        self.api = api
    }

    var canSubmitDetails: Bool {
        claimerName.trimmingCharacters(in: .whitespaces).count >= 2
            && claimerEmail.contains("@")
            && !isSubmitting
    }

    var canSubmitCode: Bool { code.count == 6 && !isSubmitting }

    func submitDetails(venueId: String, token: String?) async {
        guard let token else { errorMessage = "Inicia sesión para reclamar este local."; return }
        isSubmitting = true
        defer { isSubmitting = false }

        do {
            let response: CreateClaimResponse = try await api.post(
                "/me/claims",
                body: CreateClaimRequest(
                    venueId: venueId,
                    claimerName: claimerName.trimmingCharacters(in: .whitespaces),
                    claimerEmail: claimerEmail.trimmingCharacters(in: .whitespaces),
                    claimerPhone: claimerPhone.nilIfEmpty,
                    claimerRole: claimerRole.nilIfEmpty,
                    message: message.nilIfEmpty
                ),
                bearer: token
            )
            claimId = response.claimId
            confidenceScore = response.confidenceScore
            errorMessage = nil
            step = .code
            VLFeedback.success()
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? "No se pudo enviar el reclamo."
            VLFeedback.error()
        }
    }

    func submitCode(token: String?) async {
        guard let token, let claimId else { return }
        isSubmitting = true
        defer { isSubmitting = false }

        do {
            let response: VerifyClaimResponse = try await api.post(
                "/me/claims/\(claimId)/verify",
                body: VerifyClaimRequest(code: code),
                bearer: token
            )
            confidenceScore = response.confidenceScore
            attemptsLeft = response.attemptsLeft
            errorMessage = nil
            step = .evidence
            VLFeedback.success()
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? "El código no es válido."
            VLFeedback.error()
        }
    }

    /// Evidence is optional: it only raises the confidence score an admin sees.
    func attachEvidence(data: Data, filename: String, token: String?) async {
        guard let token, let claimId else { return }
        isSubmitting = true
        defer { isSubmitting = false }

        do {
            // Same multipart upload the review photos and the avatar use.
            let upload: MobileUpload = try await api.upload(
                "/me/uploads",
                data: data,
                fileName: filename,
                mimeType: "image/jpeg",
                bearer: token
            )
            let scored: ClaimEvidenceResponse = try await api.post(
                "/me/claims/\(claimId)/evidence",
                body: ClaimEvidenceRequest(evidenceUrl: upload.url, evidenceName: filename),
                bearer: token
            )
            confidenceScore = scored.confidenceScore
            errorMessage = nil
            step = .done
            VLFeedback.success()
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? "No se pudo adjuntar la evidencia."
            VLFeedback.error()
        }
    }

    func skipEvidence() {
        step = .done
    }
}

struct ClaimEvidenceResponse: Codable, Sendable {
    let confidenceScore: Int
}

/// Business-owner claim, mirroring the web flow: details, e-mail code, optional
/// proof. An admin makes the final call; the claimant is pushed the result.
struct OwnerClaimView: View {
    let venueId: String
    let venueName: String

    @Environment(SessionStore.self) private var session
    @Environment(\.dismiss) private var dismiss
    @State private var model = OwnerClaimViewModel()
    @State private var evidenceItem: PhotosPickerItem?

    var body: some View {
        @Bindable var model = model
        NavigationStack {
            Form {
                switch model.step {
                case .details: detailsStep(model: model)
                case .code: codeStep(model: model)
                case .evidence: evidenceStep
                case .done: doneStep
                }

                if let errorMessage = model.errorMessage {
                    Section {
                        Text(errorMessage).font(.subheadline).foregroundStyle(.red)
                    }
                }
            }
            .vlScreen()
            .navigationTitle("Reclamar negocio")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cerrar") { dismiss() }
                }
            }
            .disabled(model.isSubmitting)
        }
    }
}

private extension OwnerClaimView {
    @ViewBuilder
    func detailsStep(model: OwnerClaimViewModel) -> some View {
        @Bindable var model = model
        Section {
            Text("Verificaremos que administras \(venueName) antes de darte acceso.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        Section("Tus datos") {
            TextField("Nombre completo", text: $model.claimerName)
                .textContentType(.name)
            TextField("Correo del negocio", text: $model.claimerEmail)
                .textContentType(.emailAddress)
                .keyboardType(.emailAddress)
                .textInputAutocapitalization(.never)
            TextField("Teléfono (opcional)", text: $model.claimerPhone)
                .keyboardType(.phonePad)
            TextField("Tu cargo (opcional)", text: $model.claimerRole)
        }
        Section {
            TextField("Cuéntanos algo más (opcional)", text: $model.message, axis: .vertical)
                .lineLimit(3...6)
        } footer: {
            Text("Un correo con dominio del negocio acelera la verificación.")
        }
        Section {
            Button("Enviar código") {
                Task { await model.submitDetails(venueId: venueId, token: session.accessToken) }
            }
            .disabled(!model.canSubmitDetails)
        }
    }

    @ViewBuilder
    func codeStep(model: OwnerClaimViewModel) -> some View {
        @Bindable var model = model
        Section {
            Text("Enviamos un código de 6 dígitos a \(model.claimerEmail). Caduca en 15 minutos.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        Section("Código") {
            TextField("000000", text: $model.code)
                .keyboardType(.numberPad)
                .textContentType(.oneTimeCode)
                .font(.title2.monospacedDigit())
        }
        Section {
            Button("Verificar") {
                Task { await model.submitCode(token: session.accessToken) }
            }
            .disabled(!model.canSubmitCode)
        }
    }

    @ViewBuilder
    var evidenceStep: some View {
        Section {
            Text("Correo verificado. Puedes adjuntar una foto del RUC, una factura o el letrero del local para acelerar la aprobación.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            ConfidenceRow(score: model.confidenceScore)
        }
        Section {
            PhotosPicker(selection: $evidenceItem, matching: .images) {
                Label("Adjuntar evidencia", systemImage: "doc.badge.plus")
            }
            Button("Continuar sin evidencia") { model.skipEvidence() }
        }
        .onChange(of: evidenceItem) { _, item in
            guard let item else { return }
            Task {
                guard let data = try? await item.loadTransferable(type: Data.self) else { return }
                await model.attachEvidence(
                    data: data,
                    filename: "evidencia-\(UUID().uuidString).jpg",
                    token: session.accessToken
                )
            }
        }
    }

    @ViewBuilder
    var doneStep: some View {
        Section {
            Label("Reclamo enviado", systemImage: "checkmark.seal.fill")
                .font(.headline)
                .foregroundStyle(VLTheme.emerald)
            Text("Un administrador revisará tu solicitud. Te avisaremos con una notificación en cuanto haya respuesta.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            ConfidenceRow(score: model.confidenceScore)
        }
        Section {
            Button("Listo") { dismiss() }
        }
    }
}

/// The score an admin weighs the claim by; showing it explains why adding proof
/// is worth the extra step.
private struct ConfidenceRow: View {
    let score: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Confianza del reclamo").font(.caption).foregroundStyle(.secondary)
            ProgressView(value: Double(score), total: 100)
                .tint(score >= 60 ? VLTheme.emerald : VLTheme.coral)
            Text("\(score) / 100").font(.caption.monospacedDigit()).foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Confianza del reclamo: \(score) de 100")
    }
}
