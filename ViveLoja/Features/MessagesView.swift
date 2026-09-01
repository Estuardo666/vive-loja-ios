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
    var messages: [MobileMessagePreview] = []
    var isLoading = false
    var isSending = false
    var errorMessage: String?
    var feedbackMessage: String?
    private var streamTask: Task<Void, Never>?

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

    func startStream(accessToken: String?) {
        guard let accessToken else { return }
        streamTask?.cancel()
        streamTask = Task { [weak self] in
            guard let url = URL(string: "https://viveloja.com/api/mobile/v1/me/messages/stream") else { return }
            var request = URLRequest(url: url)
            request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
            request.setValue("text/event-stream", forHTTPHeaderField: "Accept")
            do {
                let (bytes, _) = try await URLSession.shared.bytes(for: request)
                for try await line in bytes.lines {
                    guard line.hasPrefix("data: "), let payload = String(line.dropFirst(6)).data(using: .utf8), let message = try? JSONDecoder.viveLoja.decode(MobileMessagePreview.self, from: payload) else { continue }
                    guard let self, !self.messages.contains(where: { $0.id == message.id }) else { continue }
                    self.messages.append(message)
                }
            } catch is CancellationError {
                return
            } catch {
                // Foreground streaming is best-effort; the next refresh remains authoritative.
            }
        }
    }

    func stopStream() {
        streamTask?.cancel()
        streamTask = nil
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
            .refreshable { await model.load(accessToken: session.accessToken) }
            .task(id: session.user?.id) { await model.load(accessToken: session.accessToken) }
        }
    }
}

struct ConversationView: View {
    let conversation: MobileConversation
    @Environment(SessionStore.self) private var session
    @State private var model = ConversationViewModel()
    @State private var composer = ""

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
            composerBar
        }
        .navigationTitle(conversation.venue.name)
        .navigationBarTitleDisplayMode(.inline)
        .task { await model.load(conversation: conversation, accessToken: session.accessToken) }
        .onAppear { model.startStream(accessToken: session.accessToken) }
        .onDisappear { model.stopStream() }
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
