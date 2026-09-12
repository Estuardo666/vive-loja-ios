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
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? "No se pudo validar la entrada. Verifica tu conexión."
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

    var body: some View {
        ZStack {
            QRCodeScannerView { code in
                guard lastCode != code else { return }
                lastCode = code
                Task { await model.checkIn(eventId: eventId, rawCode: code, accessToken: session.accessToken) }
            }
            .ignoresSafeArea()
            Color.black.opacity(0.2).ignoresSafeArea()
            VStack {
                Label("Escaneando: \(eventTitle)", systemImage: "qrcode.viewfinder")
                    .font(.headline).foregroundStyle(.white)
                    .padding(.horizontal, 16).padding(.vertical, 10)
                    .background(.black.opacity(0.6), in: Capsule())
                Spacer()
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(.white, lineWidth: 3)
                    .frame(width: 260, height: 260)
                Spacer()
                VStack(spacing: 10) {
                    Text("Validación en línea")
                        .font(.subheadline.weight(.semibold)).foregroundStyle(.white)
                    if model.isSubmitting { ProgressView().tint(.white) }
                    if let result = model.result {
                        Label(result.result == "ACCEPTED" ? "Entrada válida" : result.result, systemImage: result.result == "ACCEPTED" ? "checkmark.circle.fill" : "xmark.circle.fill")
                            .font(.headline).foregroundStyle(result.result == "ACCEPTED" ? .green : .red)
                        if let code = result.code { Text(code).font(.caption.monospaced()).foregroundStyle(.white) }
                        if let seat = result.seatLabel { Text(seat).font(.caption).foregroundStyle(.white) }
                        Button("Escanear siguiente") { lastCode = nil; model.result = nil; model.errorMessage = nil }
                            .buttonStyle(.borderedProminent)
                    } else if let errorMessage = model.errorMessage {
                        Text(errorMessage).font(.subheadline).multilineTextAlignment(.center).foregroundStyle(.white)
                        Button("Intentar de nuevo") { lastCode = nil; model.errorMessage = nil }
                            .buttonStyle(.bordered)
                            .tint(.white)
                    }
                }
                .padding(16)
                .frame(maxWidth: .infinity)
                .background(.black.opacity(0.65))
            }
            .padding(.top, 20)
        }
        .toolbar(.hidden, for: .navigationBar)
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
