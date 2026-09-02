import Foundation
import Observation
import SwiftUI

@MainActor
@Observable
final class MessagesViewModel {
    var conversations: [MobileConversation] = []
    var isLoading = false
    var errorMessage: String?

    func load(accessToken: String?) async {
        guard let accessToken else { conversations = []; return }
        isLoading = true; defer { isLoading = false }
        do {
            conversations = try await APIClient.shared.get("/me/messages", bearer: accessToken)
            errorMessage = nil
        } catch { errorMessage = (error as? LocalizedError)?.errorDescription ?? "No se pudieron cargar tus mensajes." }
    }
}

@MainActor
@Observable
final class ConversationViewModel {
    enum StreamStatus: Equatable, Sendable {
        case idle
        case connecting
        case connected
        case reconnecting
    }

    var messages: [MobileMessagePreview] = []
    var isLoading = false
    var isSending = false
    var errorMessage: String?
    var feedbackMessage: String?
    var isBlocked = false
    private(set) var streamStatus: StreamStatus = .idle
    private var streamTask: Task<Void, Never>?
    private let streamSession: URLSession
    private let streamURL: URL

    init(streamSession: URLSession = .shared, streamURL: URL? = nil) {
        self.streamSession = streamSession
        self.streamURL = streamURL ?? URL(string: "https://viveloja.com/api/mobile/v1/me/messages/stream")!
    }

    func load(conversation: MobileConversation, accessToken: String?) async {
        guard let accessToken else { messages = []; return }
        isLoading = true; defer { isLoading = false }
        do {
            messages = try await APIClient.shared.get("/me/messages/\(conversation.id)", bearer: accessToken)
            let _: MarkedReadResponse = try await APIClient.shared.patch("/me/messages/\(conversation.id)", body: ReadReceipt(read: true), bearer: accessToken)
            errorMessage = nil
        } catch { errorMessage = (error as? LocalizedError)?.errorDescription ?? "No se pudo cargar la conversación." }
    }

    func send(_ content: String, to conversation: MobileConversation, accessToken: String?) async -> Bool {
        guard let accessToken, !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return false }
        isSending = true; defer { isSending = false }
        do {
            let created: MobileMessagePreview = try await APIClient.shared.post(
                "/me/messages",
                body: MessageRequest(venueId: conversation.venue.id, receiverId: conversation.participant.id, content: content),
                bearer: accessToken
            )
            messages.append(created)
            VLFeedback.success()
            return true
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? "No se pudo enviar el mensaje."
            VLFeedback.error()
            return false
        }
    }

    func report(_ message: MobileMessagePreview, reason: String, accessToken: String?) async {
        guard let accessToken else { return }
        do {
            let _: MessageReportResponse = try await APIClient.shared.post(
                "/me/messages/report",
                body: MessageReportRequest(messageId: message.id, reason: reason),
                bearer: accessToken
            )
            feedbackMessage = "Gracias. Revisaremos este mensaje."
            VLFeedback.success()
        } catch {
            feedbackMessage = (error as? LocalizedError)?.errorDescription ?? "No se pudo reportar el mensaje."
            VLFeedback.error()
        }
    }

    func setBlocked(_ blocked: Bool, conversation: MobileConversation, accessToken: String?) async {
        guard let accessToken else { return }
        let request = MessageBlockRequest(venueId: conversation.venue.id, userId: conversation.participant.id, reason: "Desde iOS")
        do {
            let response: MessageBlockResponse
            if blocked {
                response = try await APIClient.shared.post("/me/messages/block", body: request, bearer: accessToken)
            } else {
                response = try await APIClient.shared.delete("/me/messages/block", body: request, bearer: accessToken)
            }
            isBlocked = response.blocked
            feedbackMessage = response.blocked ? "Usuario bloqueado." : "Usuario desbloqueado."
            VLFeedback.success()
        } catch {
            feedbackMessage = (error as? LocalizedError)?.errorDescription ?? "No se pudo actualizar el bloqueo."
            VLFeedback.error()
        }
    }

    func startStream(accessToken: String?) {
        guard let accessToken else {
            stopStream()
            return
        }
        streamTask?.cancel()
        streamStatus = .connecting
        streamTask = Task { [weak self] in
            guard let self else { return }
            var retryDelay: UInt64 = 1_000_000_000
            while !Task.isCancelled {
                var request = URLRequest(url: self.streamURL)
                request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
                request.setValue("text/event-stream", forHTTPHeaderField: "Accept")
                do {
                    let (bytes, response) = try await self.streamSession.bytes(for: request)
                    guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
                        throw APIError.transport("El stream de mensajes no está disponible.")
                    }
                    self.streamStatus = .connected
                    retryDelay = 1_000_000_000
                    for try await line in bytes.lines {
                        guard line.hasPrefix("data: "), let payload = String(line.dropFirst(6)).data(using: .utf8), let message = try? JSONDecoder.viveLoja.decode(MobileMessagePreview.self, from: payload) else { continue }
                        guard !self.messages.contains(where: { $0.id == message.id }) else { continue }
                        self.messages.append(message)
                    }
                    if !Task.isCancelled { self.streamStatus = .reconnecting }
                } catch is CancellationError {
                    return
                } catch {
                    if Task.isCancelled { return }
                    self.streamStatus = .reconnecting
                }
                do {
                    try await Task.sleep(nanoseconds: retryDelay)
                } catch {
                    return
                }
                retryDelay = min(retryDelay * 2, 30_000_000_000)
            }
        }
    }

    func stopStream() {
        streamTask?.cancel()
        streamTask = nil
        streamStatus = .idle
    }
}

struct MessagesView: View {
    @Environment(SessionStore.self) private var session
    @State private var model = MessagesViewModel()

    var body: some View {
        NavigationStack {
            Group {
                if session.user == nil {
                    ContentUnavailableView("Inicia sesión para escribir", systemImage: "message", description: Text("Podrás conversar con los locales de Loja."))
                } else if model.isLoading && model.conversations.isEmpty {
                    ProgressView("Cargando mensajes…")
                } else if let error = model.errorMessage, model.conversations.isEmpty {
                    ContentUnavailableView("Sin conexión", systemImage: "wifi.exclamationmark", description: Text(error))
                } else if model.conversations.isEmpty {
                    ContentUnavailableView("Aún no tienes conversaciones", systemImage: "message", description: Text("Escribe a un local desde su detalle para empezar."))
                } else {
                    List(model.conversations) { conversation in
                        NavigationLink {
                            ConversationView(conversation: conversation)
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: "building.2.crop.circle.fill").font(.title2).foregroundStyle(VLTheme.indigo)
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(conversation.venue.name).font(.headline)
                                    Text(conversation.lastMessage?.content ?? "Nueva conversación").font(.subheadline).foregroundStyle(.secondary).lineLimit(1)
                                }
                                Spacer()
                                if conversation.unreadCount > 0 { Text("\(conversation.unreadCount)").font(.caption.bold()).padding(6).background(VLTheme.coral, in: Circle()).foregroundStyle(.white) }
                            }
                        }
                        .accessibilityElement(children: .combine)
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .navigationTitle("Mensajes")
            .toolbarTitleDisplayMode(.inlineLarge)
            .refreshable { await model.load(accessToken: session.accessToken) }
            .task(id: session.user?.id) { await model.load(accessToken: session.accessToken) }
        }
    }
}

struct ConversationView: View {
    let conversation: MobileConversation
    @Environment(SessionStore.self) private var session
    @Environment(\.scenePhase) private var scenePhase
    @State private var model = ConversationViewModel()
    @State private var composer = ""
    @State private var showBlockConfirmation = false

    var body: some View {
        VStack(spacing: 0) {
            if model.isLoading && model.messages.isEmpty {
                ProgressView("Cargando conversación…").frame(maxHeight: .infinity)
            } else if let error = model.errorMessage, model.messages.isEmpty {
                ContentUnavailableView("No se pudo cargar", systemImage: "wifi.exclamationmark", description: Text(error)).frame(maxHeight: .infinity)
            } else if model.messages.isEmpty {
                ContentUnavailableView("Sin mensajes", systemImage: "message", description: Text("Escribe para iniciar la conversación.")).frame(maxHeight: .infinity)
            } else {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 10) {
                            ForEach(model.messages) { message in
                                MessageBubble(message: message, isMine: message.senderId == session.user?.id)
                                    .id(message.id)
                                    .contextMenu {
                                        Menu("Reportar mensaje", systemImage: "exclamationmark.bubble") {
                                            reportButton(for: message, reason: "SPAM", title: "Spam")
                                            reportButton(for: message, reason: "HARASSMENT", title: "Acoso")
                                            reportButton(for: message, reason: "SCAM", title: "Estafa")
                                            reportButton(for: message, reason: "OTHER", title: "Otro motivo")
                                        }
                                    }
                            }
                        }
                        .padding(16)
                    }
                    .onChange(of: model.messages.count) { _, _ in
                        if let last = model.messages.last { withAnimation(.snappy) { proxy.scrollTo(last.id, anchor: .bottom) } }
                    }
                }
            }
            if model.streamStatus == .connecting || model.streamStatus == .reconnecting {
                Label("Reconectando mensajes…", systemImage: "wifi.exclamationmark")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 6)
            }
            composerBar
        }
        .navigationTitle(conversation.venue.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    if model.isBlocked {
                        Button("Desbloquear usuario", systemImage: "lock.open") {
                            Task { await model.setBlocked(false, conversation: conversation, accessToken: session.accessToken) }
                        }
                    } else {
                        Button("Bloquear usuario", systemImage: "lock") { showBlockConfirmation = true }
                    }
                } label: {
                    Image(systemName: model.isBlocked ? "lock.fill" : "ellipsis.circle")
                }
                .accessibilityLabel(model.isBlocked ? "Desbloquear usuario" : "Opciones de conversación")
            }
        }
        .task { await model.load(conversation: conversation, accessToken: session.accessToken) }
        .onAppear { model.startStream(accessToken: session.accessToken) }
        .onDisappear { model.stopStream() }
        .onChange(of: scenePhase) { _, phase in
            switch phase {
            case .active:
                model.startStream(accessToken: session.accessToken)
            case .inactive, .background:
                model.stopStream()
            @unknown default:
                break
            }
        }
        .confirmationDialog("¿Bloquear a este usuario?", isPresented: $showBlockConfirmation, titleVisibility: .visible) {
            Button("Bloquear", role: .destructive) {
                Task { await model.setBlocked(true, conversation: conversation, accessToken: session.accessToken) }
            }
            Button("Cancelar", role: .cancel) {}
        } message: {
            Text("No podrá enviarte nuevos mensajes en este local.")
        }
        .alert("Reporte", isPresented: Binding(
            get: { model.feedbackMessage != nil },
            set: { if !$0 { model.feedbackMessage = nil } }
        )) {
            Button("Aceptar", role: .cancel) { model.feedbackMessage = nil }
        } message: {
            Text(model.feedbackMessage ?? "")
        }
    }

    private func reportButton(for message: MobileMessagePreview, reason: String, title: String) -> some View {
        Button(title, systemImage: "flag") {
            Task { await model.report(message, reason: reason, accessToken: session.accessToken) }
        }
    }

    private var composerBar: some View {
        HStack(alignment: .bottom, spacing: 10) {
            TextField("Escribe un mensaje", text: $composer, axis: .vertical)
                .textFieldStyle(.roundedBorder).lineLimit(1...4)
            Button {
                let draft = composer; composer = ""
                Task {
                    if !(await model.send(draft, to: conversation, accessToken: session.accessToken)) { composer = draft }
                }
            } label: { Image(systemName: model.isSending ? "hourglass" : "paperplane.fill") }
                .buttonStyle(.borderedProminent).tint(VLTheme.indigo)
                .disabled(model.isSending || composer.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .accessibilityLabel("Enviar mensaje")
        }
        .padding(12)
        .background(.bar)
    }
}

private struct MessageBubble: View {
    let message: MobileMessagePreview
    let isMine: Bool

    var body: some View {
        HStack {
            if isMine { Spacer(minLength: 48) }
            VStack(alignment: isMine ? .trailing : .leading, spacing: 4) {
                Text(message.content ?? "").font(.body)
                Text(message.createdAt.formatted(date: .omitted, time: .shortened)).font(.caption2).foregroundStyle(.secondary)
            }
            .padding(.horizontal, 14).padding(.vertical, 10)
            .background(isMine ? VLTheme.indigo : Color(uiColor: .secondarySystemBackground), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .foregroundStyle(isMine ? .white : .primary)
            if !isMine { Spacer(minLength: 48) }
        }
        .accessibilityElement(children: .combine)
    }
}

private struct ReadReceipt: Codable, Sendable { let read: Bool }
private struct MarkedReadResponse: Decodable, Sendable { let markedRead: Int }

private extension JSONDecoder {
    static var viveLoja: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}
