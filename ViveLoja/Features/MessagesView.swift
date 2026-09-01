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
        isLoading = true
        defer { isLoading = false }
        do {
            conversations = try await APIClient.shared.get("/me/messages", bearer: accessToken)
            errorMessage = nil
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? "No se pudieron cargar tus mensajes."
        }
    }

    func send(_ content: String, to conversation: MobileConversation, accessToken: String?) async -> Bool {
        guard let accessToken, !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return false }
        do {
            let _: MobileMessagePreview = try await APIClient.shared.post(
                "/me/messages",
                body: MessageRequest(venueId: conversation.venue.id, receiverId: conversation.participant.id, content: content),
                bearer: accessToken
            )
            await load(accessToken: accessToken)
            VLFeedback.success()
            return true
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? "No se pudo enviar el mensaje."
            VLFeedback.error()
            return false
        }
    }
}

struct MessagesView: View {
    @Environment(SessionStore.self) private var session
    @State private var model = MessagesViewModel()
    @State private var composer = ""
    @State private var selectedConversation: MobileConversation?

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
                        Button { selectedConversation = conversation } label: {
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
                        .buttonStyle(.plain)
                        .accessibilityElement(children: .combine)
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .navigationTitle("Mensajes")
            .refreshable { await model.load(accessToken: session.accessToken) }
            .task(id: session.user?.id) { await model.load(accessToken: session.accessToken) }
            .sheet(item: $selectedConversation) { conversation in
                NavigationStack {
                    VStack(spacing: 16) {
                        ContentUnavailableView("Conversación con \(conversation.venue.name)", systemImage: "message", description: Text("La vista completa de mensajes se habilitará en el siguiente checkpoint."))
                        TextField("Escribe un mensaje", text: $composer, axis: .vertical)
                            .textFieldStyle(.roundedBorder).padding(.horizontal)
                        Button("Enviar", systemImage: "paperplane.fill") {
                            Task {
                                if await model.send(composer, to: conversation, accessToken: session.accessToken) { composer = ""; selectedConversation = nil }
                            }
                        }
                        .buttonStyle(.borderedProminent).tint(VLTheme.indigo)
                        .disabled(composer.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                    .padding()
                    .navigationTitle("Mensaje")
                }
            }
        }
    }
}
