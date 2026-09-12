import AVFoundation
import Foundation
import Observation
import SwiftUI
import UIKit

@MainActor
@Observable
final class TicketScannerPickerModel {
    private let api: APIClient
    private(set) var events: [MobileEventDraft] = []
    private(set) var isLoading = false
    var errorMessage: String?

    init(api: APIClient = .shared) { self.api = api }

    func load(accessToken: String?) async {
        guard let accessToken else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            events = try await api.get("/me/events", bearer: accessToken)
            errorMessage = nil
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? "No se pudieron cargar tus eventos."
        }
    }
}

struct TicketScannerPickerView: View {
    @Environment(SessionStore.self) private var session
    @State private var model = TicketScannerPickerModel()

    var body: some View {
        List {
            if let errorMessage = model.errorMessage { Section { Text(errorMessage).foregroundStyle(.red) } }
            if model.events.isEmpty && !model.isLoading && model.errorMessage == nil {
                ContentUnavailableView("No tienes eventos", systemImage: "calendar", description: Text("Crea o administra un evento para poder validar sus entradas."))
            }
            ForEach(model.events) { event in
                NavigationLink {
                    TicketScannerView(eventId: event.id, eventTitle: event.title)
                } label: {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(event.title).font(.headline)
                        Text(event.startDate.formatted(date: .abbreviated, time: .shortened)).font(.subheadline).foregroundStyle(.secondary)
                        Text(event.status).font(.caption.weight(.semibold)).foregroundStyle(event.status == "APPROVED" ? .green : .secondary)
                    }
                }
            }
        }
        .vlScreen()
        .navigationTitle("Validar entradas")
        .overlay { if model.isLoading && model.events.isEmpty { ProgressView() } }
        .refreshable { await model.load(accessToken: session.accessToken) }
        .task { await model.load(accessToken: session.accessToken) }
    }
}

@MainActor
@Observable
final class TicketScannerModel {
    private let api: APIClient
    var isSubmitting = false
    var result: MobileTicketCheckIn?
    var errorMessage: String?

    init(api: APIClient = .shared) { self.api = api }

    func checkIn(eventId: String, rawCode: String, accessToken: String?) async {
        guard let accessToken, !isSubmitting else { return }
        let token = Self.token(from: rawCode)
        isSubmitting = true
        result = nil
        errorMessage = nil
        defer { isSubmitting = false }
        do {
            result = try await api.post("/ticketing/check-ins", body: MobileTicketCheckInRequest(eventId: eventId, token: token, deviceId: UIDevice.current.identifierForVendor?.uuidString), bearer: accessToken, headers: ["Idempotency-Key": UUID().uuidString])
            VLFeedback.success()
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? "No se pudo validar la entrada. Verifica tu conexión."
            VLFeedback.error()
        }
    }

    private static func token(from rawCode: String) -> String {
        guard let components = URLComponents(string: rawCode), let token = components.queryItems?.first(where: { $0.name == "token" })?.value, !token.isEmpty else { return rawCode }
        return token
    }
}

struct TicketScannerView: View {
    let eventId: String
    let eventTitle: String
    @Environment(SessionStore.self) private var session
    @State private var model = TicketScannerModel()
    @State private var lastCode: String?
    @State private var scannerLocked = false

    var body: some View {
        ZStack {
            QRCodeScannerView { code in
                guard !scannerLocked, lastCode != code else { return }
                scannerLocked = true
                lastCode = code
                Task { await model.checkIn(eventId: eventId, rawCode: code, accessToken: session.accessToken) }
            }
            .ignoresSafeArea()
            Color.black.opacity(model.result == nil ? 0.22 : 0.48).ignoresSafeArea()
            VStack(spacing: 0) {
                Label("Escaneando: \(eventTitle)", systemImage: "qrcode.viewfinder")
                    .font(.headline).foregroundStyle(.white)
                    .padding(.horizontal, 16).padding(.vertical, 10)
                    .background(.black.opacity(0.68), in: Capsule())
                    .padding(.top, 8)
                Spacer()
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(scannerLocked ? Color.white.opacity(0.35) : Color.white, lineWidth: 3)
                    .frame(width: 260, height: 260)
                Spacer()
                validationPanel
                    .padding(.horizontal, 16)
                    .padding(.bottom, 14)
            }
            .padding(.top, 20)
        }
        .toolbar(.hidden, for: .navigationBar)
        .toolbar(.hidden, for: .tabBar)
        .animation(.spring(response: 0.36, dampingFraction: 0.86), value: model.result?.ticketId)
        .animation(.easeOut(duration: 0.2), value: model.errorMessage)
    }

    @ViewBuilder
    private var validationPanel: some View {
        if let result = model.result {
            acceptedCard(result)
                .transition(.move(edge: .bottom).combined(with: .opacity))
        } else if let errorMessage = model.errorMessage {
            rejectedCard(errorMessage)
                .transition(.move(edge: .bottom).combined(with: .opacity))
        } else {
            HStack(spacing: 10) {
                if model.isSubmitting { ProgressView().tint(.white) }
                Image(systemName: model.isSubmitting ? "shield.lefthalf.filled" : "viewfinder")
                Text(model.isSubmitting ? "Verificando con Vive Loja…" : "Coloca el QR dentro del recuadro")
                    .font(.subheadline.weight(.semibold))
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 18).padding(.vertical, 14)
            .frame(maxWidth: .infinity)
            .background(.black.opacity(0.72), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        }
    }

    private func acceptedCard(_ result: MobileTicketCheckIn) -> some View {
        VStack(spacing: 14) {
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 58, weight: .bold))
                .symbolRenderingMode(.palette)
                .foregroundStyle(.white, Color.white.opacity(0.25))
                .symbolEffect(.bounce, value: result.ticketId)

            VStack(spacing: 4) {
                Text("ACCESO AUTORIZADO")
                    .font(.caption.weight(.black))
                    .tracking(1.2)
                Text(result.buyerName ?? "Comprador verificado")
                    .font(.title2.weight(.bold))
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
            }

            HStack(spacing: 0) {
                scannerMetric(value: result.ticketType ?? "Entrada", label: "Tipo", icon: "ticket.fill")
                Divider().overlay(Color.white.opacity(0.32)).padding(.vertical, 4)
                scannerMetric(
                    value: "\(result.orderTicketCount ?? 1)",
                    label: (result.orderTicketCount ?? 1) == 1 ? "Entrada comprada" : "Entradas compradas",
                    icon: "person.2.fill"
                )
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(Color.black.opacity(0.12), in: RoundedRectangle(cornerRadius: 16, style: .continuous))

            HStack {
                if let sequence = result.ticketSequence, let total = result.orderTicketCount {
                    Label("Entrada \(sequence) de \(total)", systemImage: "number.circle.fill")
                }
                Spacer()
                if let seat = result.seatLabel { Label(seat, systemImage: "chair.lounge.fill") }
            }
            .font(.caption.weight(.semibold))

            if let code = result.code {
                Text(code)
                    .font(.caption.monospaced().weight(.semibold))
                    .textSelection(.enabled)
                    .opacity(0.82)
            }

            Button {
                resetScanner()
            } label: {
                Label("Escanear siguiente", systemImage: "qrcode.viewfinder")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(.white)
            .foregroundStyle(VLTheme.success)
            .controlSize(.large)
        }
        .foregroundStyle(.white)
        .padding(20)
        .background(
            LinearGradient(colors: [VLTheme.success, VLTheme.emerald], startPoint: .topLeading, endPoint: .bottomTrailing),
            in: RoundedRectangle(cornerRadius: 28, style: .continuous)
        )
        .shadow(color: Color.black.opacity(0.3), radius: 24, y: 10)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Acceso autorizado para \(result.buyerName ?? "comprador verificado")")
    }

    private func rejectedCard(_ message: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "xmark.octagon.fill")
                .font(.system(size: 48, weight: .bold))
                .foregroundStyle(.white)
            Text("NO PERMITIR EL INGRESO")
                .font(.headline.weight(.black))
            Text(message)
                .font(.subheadline.weight(.medium))
                .multilineTextAlignment(.center)
            Button {
                resetScanner()
            } label: {
                Label("Escanear otro código", systemImage: "arrow.clockwise")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(.white)
            .foregroundStyle(Color.red)
            .controlSize(.large)
        }
        .foregroundStyle(.white)
        .padding(20)
        .background(Color.red.gradient, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
        .shadow(color: Color.black.opacity(0.3), radius: 24, y: 10)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Ingreso rechazado. \(message)")
    }

    private func scannerMetric(value: String, label: String, icon: String) -> some View {
        VStack(spacing: 4) {
            Label(value, systemImage: icon)
                .font(.subheadline.weight(.bold))
                .lineLimit(1)
                .minimumScaleFactor(0.72)
            Text(label)
                .font(.caption2.weight(.medium))
                .opacity(0.82)
        }
        .frame(maxWidth: .infinity)
    }

    private func resetScanner() {
        lastCode = nil
        scannerLocked = false
        model.result = nil
        model.errorMessage = nil
    }
}

struct QRCodeScannerView: UIViewControllerRepresentable {
    let onCode: (String) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(onCode: onCode) }

    func makeUIViewController(context: Context) -> UIViewController {
        let controller = UIViewController()
        controller.view.backgroundColor = .black
        guard let device = AVCaptureDevice.default(for: .video), let input = try? AVCaptureDeviceInput(device: device) else { return controller }
        let capture = AVCaptureSession()
        guard capture.canAddInput(input) else { return controller }
        capture.addInput(input)
        let output = AVCaptureMetadataOutput()
        guard capture.canAddOutput(output) else { return controller }
        capture.addOutput(output)
        output.setMetadataObjectsDelegate(context.coordinator, queue: .main)
        output.metadataObjectTypes = [.qr]
        let preview = AVCaptureVideoPreviewLayer(session: capture)
        preview.videoGravity = .resizeAspectFill
        preview.frame = controller.view.bounds
        controller.view.layer.addSublayer(preview)
        controller.view.layer.setNeedsLayout()
        controller.view.layoutIfNeeded()
        capture.startRunning()
        context.coordinator.capture = capture
        context.coordinator.preview = preview
        return controller
    }

    func updateUIViewController(_ controller: UIViewController, context: Context) {
        context.coordinator.preview?.frame = controller.view.bounds
    }

    static func dismantleUIViewController(_ controller: UIViewController, coordinator: Coordinator) {
        coordinator.capture?.stopRunning()
    }

    final class Coordinator: NSObject, AVCaptureMetadataOutputObjectsDelegate {
        let onCode: (String) -> Void
        var capture: AVCaptureSession?
        var preview: AVCaptureVideoPreviewLayer?
        private var lastCode: String?

        init(onCode: @escaping (String) -> Void) { self.onCode = onCode }

        func metadataOutput(_ output: AVCaptureMetadataOutput, didOutput metadataObjects: [AVMetadataObject], from connection: AVCaptureConnection) {
            guard let object = metadataObjects.first as? AVMetadataMachineReadableCodeObject, let value = object.stringValue, value != lastCode else { return }
            lastCode = value
            onCode(value)
        }
    }
}
