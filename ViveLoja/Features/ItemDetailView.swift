import MapKit
import PhotosUI
import SwiftUI

struct ItemDetailView: View {
    let item: ExploreItem
    @Environment(SavedStore.self) private var saved
    @Environment(SessionStore.self) private var session
    @Environment(PushService.self) private var push
    @State private var showOwnerClaim = false
    /// Review the owner is answering, if any.
    @State private var replyingTo: MobileReview?
    @Environment(\.openURL) private var openURL
    @State private var resolvedItem: ExploreItem?
    @State private var venueDetail: VenueDetail?
    @State private var eventDetail: EventDetail?
    @State private var reminderScheduled = false
    @State private var showReviewComposer = false
    @State private var showQuestionComposer = false
    @State private var showCheckIn = false
    @State private var isFollowingVenue = false
    @State private var isUpdatingFollowing = false
    @State private var actionMessage: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                if eventDetail?.status == "CANCELLED" {
                    Label("Evento cancelado. Consulta al organizador si compraste entradas.", systemImage: "calendar.badge.exclamationmark")
                        .font(.headline).foregroundStyle(.red).padding()
                }
                gallery
                ItemDetailHeader(item: displayedItem, venueDetail: venueDetail)
                actionBar
                if case .event(let event) = displayedItem, eventDetail?.status != "CANCELLED" {
                    Button {
                        Task {
                            if reminderScheduled {
                                LocalReminderScheduler.shared.cancel(eventID: event.id)
                                reminderScheduled = false
                            } else {
                                // Asking here is the whole point of asking in
                                // context: the user has just said they want to
                                // be reminded. The same grant covers the server
                                // reminder, so both paths are unlocked at once.
                                if push.authorization == .notDetermined {
                                    await push.requestAuthorization()
                                }
                                if (try? await LocalReminderScheduler.shared.schedule(for: event)) != nil {
                                    reminderScheduled = true
                                    VLFeedback.success()
                                }
                            }
                        }
                    } label: {
                        Label(reminderScheduled ? "Recordatorio activo" : "Recordarme", systemImage: reminderScheduled ? "bell.fill" : "bell")
                    }
                    .buttonStyle(.bordered)
                    .tint(VLTheme.coral)
                }
                ownerSection
                servicesSection
                hoursSection
                menuSection
                productsSection
                promotionsSection
                venueEventsSection
                reviewsSection
                questionsSection
                mapSection
                detailInfoSections
                if let actionMessage { Text(actionMessage).font(.footnote).foregroundStyle(.secondary) }
            }
            // Pins the column to the scroll view's own width. Without it the
            // VStack sizes itself to its widest child, so a single subview
            // that overflows drags the entire screen past the display edges.
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(20)
        }
        .vlScreen()
        .navigationTitle("Detalle")
        .navigationBarTitleDisplayMode(.inline)
        .task { if !isUITesting { await loadDetail() } }
        .sheet(item: $replyingTo) { review in
            OwnerReplyComposerView(review: review) { Task { await loadDetail() } }
        }
        .sheet(isPresented: $showOwnerClaim) {
            if case .venue(let venue) = displayedItem {
                OwnerClaimView(venueId: venue.id, venueName: venue.name)
            }
        }
        .sheet(isPresented: $showReviewComposer) {
            ReviewComposerView(item: displayedItem) { Task { await loadDetail() } }
                .presentationDetents([.medium, .large])
        }
        .sheet(isPresented: $showQuestionComposer) {
            QuestionComposerView(item: displayedItem) { Task { await loadDetail() } }
                .presentationDetents([.medium, .large])
        }
        .sheet(isPresented: $showCheckIn) {
            if case .venue(let venue) = displayedItem {
                CheckInView(venueID: venue.id) { actionMessage = "Check-in registrado. ¡Gracias por compartir tu visita!" }
                    .presentationDetents([.medium, .large])
            }
        }
    }

    private var displayedItem: ExploreItem { resolvedItem ?? item }

    private var gallery: some View {
        Group {
            if !detailMedia.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(detailMedia) { media in
                            VLAsyncImage(url: media.url, height: 250, width: 330)
                                .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                                .accessibilityLabel(media.alt ?? "Fotografía de \(displayedItem.title)")
                        }
                    }
                }
                // An explicit height, rather than `fixedSize`: asking a scroll
                // view for its ideal size makes it report the width of its whole
                // content, and the page then lays itself out around that.
                .frame(height: 250)
            } else {
                VLAsyncImage(url: imageURL, height: 250, googleVenueSlug: googleVenueSlug)
                    .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            }
        }
    }

    private var googleVenueSlug: String? {
        if case .venue(let venue) = displayedItem { return venue.slug }
        return nil
    }

    /// Lives in ItemDetailSections so this type stays under the linter's body
    /// length limit.
    @ViewBuilder
    private var ownerSection: some View {
        if case .venue(let venue) = displayedItem {
            VenueOwnerSection(
                venue: venue,
                detail: venueDetail,
                onClaim: { showOwnerClaim = true }
            )
        }
    }

    /// Scrolls horizontally. There are up to seven actions on a claimed venue
    /// with a phone and a site, and a plain HStack made the whole screen wider
    /// than the display: the title spilled past both edges and every button was
    /// squeezed into a tall, one-letter-per-line column.
    private var actionBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                Button { saved.toggle(displayedItem, accessToken: session.accessToken) } label: {
                    Label(saved.contains(displayedItem) ? "Guardado" : "Guardar", systemImage: saved.contains(displayedItem) ? "heart.fill" : "heart")
                        .vlActionLabel()
                }
                .buttonStyle(.borderedProminent)
                .tint(VLTheme.indigo)
                ShareLink(item: shareURL) { Label("Compartir", systemImage: "square.and.arrow.up").vlActionLabel() }
                    .buttonStyle(.bordered)
                if case .venue = displayedItem, session.user != nil {
                    Button {
                        Task { await toggleFollowing() }
                    } label: {
                        Label(isFollowingVenue ? "Siguiendo" : "Seguir", systemImage: isFollowingVenue ? "bell.fill" : "bell")
                            .vlActionLabel()
                    }
                    .buttonStyle(.bordered)
                    .tint(VLTheme.coral)
                    .disabled(isUpdatingFollowing || session.accessToken == nil)
                    .accessibilityLabel(isFollowingVenue ? "Dejar de seguir local" : "Seguir local")
                }
                if case .venue(let venue) = displayedItem, let phone = venue.phone, !phone.isEmpty {
                    Button { openWhatsApp(phone: phone) } label: { Label("WhatsApp", systemImage: "message.fill").vlActionLabel() }
                        .buttonStyle(.bordered)
                        .accessibilityLabel("Contactar por WhatsApp")
                    // Not everyone uses WhatsApp, and a listing without a plain
                    // phone call is a directory that cannot be called.
                    if let callURL = URL(string: "tel://\(phone.filter { $0.isNumber || $0 == "+" })") {
                        Button { openURL(callURL) } label: { Label("Llamar", systemImage: "phone.fill").vlActionLabel() }
                            .buttonStyle(.bordered)
                            .accessibilityLabel("Llamar al local")
                    }
                }
                if case .venue(let venue) = displayedItem, let website = venue.website {
                    Button { openURL(website) } label: { Label("Sitio web", systemImage: "safari").vlActionLabel() }
                        .buttonStyle(.bordered)
                        .accessibilityLabel("Abrir sitio web")
                }
                if session.user != nil {
                    Menu {
                        Button("Escribir reseña", systemImage: "star") { showReviewComposer = true }
                        Button("Hacer pregunta", systemImage: "questionmark.bubble") { showQuestionComposer = true }
                        if case .venue = displayedItem { Button("Registrar check-in", systemImage: "checkmark.seal") { showCheckIn = true } }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .font(.title3)
                            .frame(height: 30)
                            .accessibilityLabel("Más acciones")
                    }
                }
            }
            .padding(.vertical, 2)
        }
        // The row used to bleed out of the page margin with a negative
        // horizontal padding, which proposes 40pt more than the screen to the
        // scroll view and let the whole column size itself to that width: the
        // detail screen ended up wider than the display and clipped on both
        // edges. It now stays inside the margin.
        //
        // The height is stated outright. `fixedSize(vertical:)` asks the scroll
        // view for an ideal size, and a scroll view's ideal size is its whole
        // content — including a width far past the display, which the column
        // then adopted. Every button in the row is 30pt tall by `vlActionLabel`.
        .frame(height: 38)
    }

    @ViewBuilder
    private var servicesSection: some View {
        if !detailServices.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                Text("Servicios").font(.title2.weight(.semibold))
                ForEach(detailServices) { service in
                    Label {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(service.name).font(.subheadline.weight(.semibold))
                            if let description = service.description { Text(description).font(.caption).foregroundStyle(.secondary) }
                        }
                    } icon: { Image(systemName: "checkmark.seal.fill").foregroundStyle(VLTheme.emerald) }
                }
            }
        }
    }

    @ViewBuilder
    private var hoursSection: some View {
        if case .venue = displayedItem { VenueHoursSection(venueDetail: venueDetail) }
    }

    @ViewBuilder
    private var menuSection: some View {
        // Extracted to ItemDetailSections so this type stays under the linter's
        // body length limit.
        VenueMenuSection(categories: isVenue ? detailMenu : [])
    }

    private var productsSection: some View {
        VenueProductsSection(products: isVenue ? detailProducts : [])
    }

    @ViewBuilder
    private var promotionsSection: some View {
        if case .venue = displayedItem, !detailPromotions.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                Text("Promociones").font(.title2.weight(.semibold))
                ForEach(detailPromotions) { promotion in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(promotion.title).font(.headline)
                        if let discount = promotion.discount { Label(discount, systemImage: "tag.fill").font(.caption.weight(.semibold)).foregroundStyle(VLTheme.coral) }
                        Text(promotion.description).font(.subheadline).foregroundStyle(.secondary)
                    }
                    .padding(14)
                    .vlGlass(tint: VLTheme.coral.opacity(0.1))
                    .accessibilityElement(children: .combine)
                }
            }
        }
    }

    @ViewBuilder
    private var venueEventsSection: some View {
        if case .venue = displayedItem, !detailEvents.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                Text("Próximos eventos").font(.title2.weight(.semibold))
                ForEach(detailEvents) { event in
                    HStack(spacing: 10) {
                        Image(systemName: "calendar").foregroundStyle(VLTheme.coral)
                        VStack(alignment: .leading, spacing: 3) {
                            Text(event.title).font(.subheadline.weight(.semibold))
                            Text(event.startDate.formatted(date: .abbreviated, time: .shortened)).font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                    }
                    .padding(12)
                    .background(VLTheme.surface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
            }
        }
    }

    @ViewBuilder
    private var reviewsSection: some View {
        if !detailReviews.isEmpty || session.user != nil {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Opiniones").font(.title2.weight(.semibold))
                    Spacer()
                    if session.user != nil { Button("Escribir", systemImage: "plus") { showReviewComposer = true }.font(.subheadline.weight(.semibold)) }
                }
                if detailReviews.isEmpty {
                    Text("Sé la primera persona en compartir su experiencia.").font(.subheadline).foregroundStyle(.secondary)
                } else {
                    ForEach(detailReviews) { review in
                        ReviewRow(
                            review: review,
                            canReply: venueDetail?.isOwnedByMe == true,
                            onReply: { replyingTo = review }
                        )
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var questionsSection: some View {
        if !detailQuestions.isEmpty || session.user != nil {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Preguntas").font(.title2.weight(.semibold))
                    Spacer()
                    if session.user != nil { Button("Preguntar", systemImage: "plus") { showQuestionComposer = true }.font(.subheadline.weight(.semibold)) }
                }
                if detailQuestions.isEmpty {
                    Text("Pregunta algo útil para la comunidad.").font(.subheadline).foregroundStyle(.secondary)
                } else {
                    ForEach(detailQuestions) { question in
                        VStack(alignment: .leading, spacing: 6) {
                            Text(question.content).font(.subheadline.weight(.semibold))
                            if let answer = question.answer { Label(answer, systemImage: "arrow.turn.down.right").font(.subheadline).foregroundStyle(.secondary) }
                            else { Text("Pendiente de respuesta").font(.caption).foregroundStyle(.secondary) }
                        }
                        .padding(12)
                        .background(VLTheme.surface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var mapSection: some View {
        // Extracted to ItemDetailSections so this type stays under the linter's
        // body length limit.
        ItemLocationSection(coordinate: displayedItem.coordinate, title: displayedItem.title, trackedItem: displayedItem)
    }

    @ViewBuilder
    private var detailInfoSections: some View {
        if case .venue(let value) = displayedItem {
            ItemInfoSection(address: value.address ?? value.location, phone: value.phone?.nilIfBlank ?? nil, website: value.website, priceRange: value.priceRange?.nilIfBlank ?? nil)
            if let category = value.categories.first { ItemCategorySection(category: category) }
        } else if case .event(let value) = displayedItem, let category = value.categories.first {
            ItemCategorySection(category: category)
        }
    }

}

private extension ItemDetailView {
    private var imageURL: URL? { switch displayedItem { case .venue(let value): return value.image; case .event(let value): return value.image } }
    private var detailMedia: [MobileMedia] { switch displayedItem { case .venue: return venueDetail?.media ?? []; case .event: return eventDetail?.media ?? [] } }
    private var detailServices: [MobileService] { switch displayedItem { case .venue: return venueDetail?.services ?? []; case .event: return [] } }
    private var detailMenu: [MobileMenuCategory] { venueDetail?.menu ?? [] }
    private var detailProducts: [MobileProduct] { venueDetail?.products ?? [] }
    private var detailPromotions: [MobileVenuePromotion] { venueDetail?.promotions ?? [] }
    private var detailEvents: [MobileVenueEvent] { venueDetail?.events ?? [] }
    private var detailReviews: [MobileReview] { switch displayedItem { case .venue: return venueDetail?.reviews ?? []; case .event: return eventDetail?.reviews ?? [] } }
    private var detailQuestions: [MobileQuestion] { switch displayedItem { case .venue: return venueDetail?.questions ?? []; case .event: return eventDetail?.questions ?? [] } }
    /// Canonical link, built from the same table the site and the Universal
    /// Links file use, so a shared URL reopens the app instead of Safari.
    private var shareURL: String {
        switch displayedItem {
        case .venue(let value): return AppEnvironment.current.shareURL(for: .venue, slug: value.slug).absoluteString
        case .event(let value): return AppEnvironment.current.shareURL(for: .event, slug: value.slug).absoluteString
        }
    }
    private var isVenue: Bool { if case .venue = displayedItem { return true }; return false }
    private var isUITesting: Bool { ProcessInfo.processInfo.arguments.contains("-uiTesting") }

    func loadDetail() async {
        do {
            switch item {
            case .venue(let value):
                let detail: VenueDetail = try await APIClient.shared.get("/venues/\(value.slug)")
                venueDetail = detail
                resolvedItem = .venue(ExploreVenue(id: detail.id, name: detail.name, slug: detail.slug, description: detail.description, image: detail.image, location: detail.location, address: detail.address, lat: detail.lat, lng: detail.lng, featured: detail.featured, phone: detail.phone, website: detail.website, priceRange: value.priceRange, avgRating: detail.avgRating, reviewCount: detail.reviewCount, verified: detail.verified, categories: detail.categories, openState: detail.openState))
                await loadFollowing(for: detail.id)
                let _: ViewResponse? = try? await APIClient.shared.post("/views", body: ViewRequest(kind: "venue", itemId: detail.id), bearer: session.accessToken)
            case .event(let value):
                let detail: EventDetail = try await APIClient.shared.get("/events/\(value.slug)")
                eventDetail = detail
                if detail.status == "CANCELLED" {
                    LocalReminderScheduler.shared.cancel(eventID: detail.id)
                    reminderScheduled = false
                }
                resolvedItem = .event(ExploreEvent(id: detail.id, title: detail.title, slug: detail.slug, description: detail.description, image: detail.image, startDate: detail.startDate, endDate: detail.endDate, location: detail.location, address: detail.address, lat: detail.lat, lng: detail.lng, featured: detail.featured, price: detail.price, avgRating: detail.avgRating, reviewCount: detail.reviewCount, categories: detail.categories))
                let _: ViewResponse? = try? await APIClient.shared.post("/views", body: ViewRequest(kind: "event", itemId: detail.id), bearer: session.accessToken)
            }
        } catch { actionMessage = (error as? LocalizedError)?.errorDescription }
    }

    func loadFollowing(for venueID: String) async {
        guard let token = session.accessToken else { return }
        do {
            let follows: [MobileFollowingRecord] = try await APIClient.shared.get("/me/following", bearer: token)
            isFollowingVenue = follows.contains(where: { $0.venueId == venueID })
        } catch {
            // Following is an enhancement; a stale state must not block detail rendering.
        }
    }

    func toggleFollowing() async {
        guard let token = session.accessToken, case .venue(let venue) = displayedItem else { return }
        isUpdatingFollowing = true
        defer { isUpdatingFollowing = false }
        do {
            if isFollowingVenue {
                let _: FollowingStateResponse = try await APIClient.shared.delete("/me/following", body: FollowingRequest(venueId: venue.id), bearer: token)
                isFollowingVenue = false
            } else {
                let _: FollowingStateResponse = try await APIClient.shared.post("/me/following", body: FollowingRequest(venueId: venue.id), bearer: token)
                isFollowingVenue = true
            }
            VLFeedback.success()
        } catch {
            actionMessage = (error as? LocalizedError)?.errorDescription ?? "No se pudo actualizar el seguimiento."
            VLFeedback.error()
        }
    }

    func openWhatsApp(phone: String) {
        let digits = phone.filter(\.isNumber)
        guard digits.isEmpty == false, let url = URL(string: "https://wa.me/\(digits)") else {
            actionMessage = "El número de contacto no es válido."
            return
        }
        openURL(url)
    }
}

private struct FollowingStateResponse: Decodable, Sendable {
    let following: Bool
}

private struct ReviewRow: View {
    let review: MobileReview
    /// Set when the reader owns the listing, which turns on the reply button.
    var canReply: Bool = false
    var onReply: (() -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 4) {
                ForEach(1...5, id: \.self) { index in Image(systemName: index <= review.rating ? "star.fill" : "star").font(.caption).foregroundStyle(VLTheme.coral) }
                if let name = review.user?.name { Text(name).font(.caption.weight(.semibold)).foregroundStyle(.secondary) }
                Spacer()
                Text(review.createdAt.formatted(date: .abbreviated, time: .omitted)).font(.caption2).foregroundStyle(.tertiary)
            }
            if let title = review.title { Text(title).font(.subheadline.weight(.semibold)) }
            if let content = review.content { Text(content).font(.subheadline).foregroundStyle(.secondary) }
            if !review.photos.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) { ForEach(review.photos) { photo in VLAsyncImage(url: photo.url, height: 72, width: 96).clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous)) } }
                }
                .frame(height: 72)
            }

            // Owner replies were stored by the web dashboard but never shown
            // here, so the app looked like nobody answered. Same visual
            // treatment the answered questions use.
            if let reply = review.ownerReply, !reply.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Label("Respuesta del negocio", systemImage: "arrow.turn.down.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(VLTheme.emerald)
                    Text(reply).font(.subheadline).foregroundStyle(.secondary)
                    if let repliedAt = review.ownerReplyAt {
                        Text(repliedAt.formatted(date: .abbreviated, time: .omitted))
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                }
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(VLTheme.emerald.opacity(0.08), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            } else if canReply {
                Button("Responder", systemImage: "text.bubble") { onReply?() }
                    .font(.caption.weight(.semibold))
                    .buttonStyle(.bordered)
                    .tint(VLTheme.emerald)
            }
        }
        .padding(12)
        .background(VLTheme.surface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .accessibilityElement(children: .combine)
    }
}

/// Composer for the owner's reply to a single review.
struct OwnerReplyComposerView: View {
    let review: MobileReview
    let onSaved: () -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(SessionStore.self) private var session
    @State private var reply = ""
    @State private var isSaving = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                Section("Tu respuesta") {
                    TextField("Escribe una respuesta pública", text: $reply, axis: .vertical)
                        .lineLimit(4...10)
                }
                if let errorMessage {
                    Section { Text(errorMessage).font(.subheadline).foregroundStyle(.red) }
                }
            }
            .vlScreen()
            .navigationTitle("Responder reseña")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { Button("Cancelar") { dismiss() } }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Publicar") { Task { await save() } }
                        .disabled(reply.trimmed.isEmpty || isSaving || session.accessToken == nil)
                }
            }
        }
    }

    private func save() async {
        guard let token = session.accessToken else { return }
        isSaving = true
        defer { isSaving = false }
        do {
            let _: ReviewReplyResponse = try await APIClient.shared.patch(
                "/me/reviews/\(review.id)/reply",
                body: ReviewReplyRequest(reply: reply.trimmed),
                bearer: token
            )
            VLFeedback.success()
            onSaved()
            dismiss()
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? "No se pudo publicar la respuesta."
            VLFeedback.error()
        }
    }
}

private struct ReviewComposerView: View {
    let item: ExploreItem
    let onSaved: () -> Void
    @Environment(\.dismiss) private var dismiss
    @Environment(SessionStore.self) private var session
    @State private var rating = 5
    @State private var title = ""
    @State private var content = ""
    @State private var selectedPhotos: [PhotosPickerItem] = []
    @State private var isUploadingPhotos = false
    @State private var isSaving = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                Section("Puntuación") {
                    HStack {
                        ForEach(1...5, id: \.self) { value in
                            Button { rating = value } label: { Image(systemName: value <= rating ? "star.fill" : "star").foregroundStyle(VLTheme.coral).font(.title2) }
                                .buttonStyle(.plain).accessibilityLabel("\(value) estrellas")
                        }
                    }
                }
                Section("Tu experiencia") {
                    TextField("Título (opcional)", text: $title)
                    TextEditor(text: $content).frame(minHeight: 100)
                    PhotosPicker(selection: $selectedPhotos, maxSelectionCount: 6, matching: .images, photoLibrary: .shared()) {
                        Label("Añadir fotos (opcional)", systemImage: "photo.on.rectangle.angled")
                    }
                    if !selectedPhotos.isEmpty { Text("\(selectedPhotos.count) foto(s) seleccionada(s)").font(.caption).foregroundStyle(.secondary) }
                }
                if let errorMessage { Text(errorMessage).foregroundStyle(.red) }
                Button { Task { await save() } } label: { if isSaving { ProgressView() } else { Label("Enviar a moderación", systemImage: "paperplane.fill") } }
                    .disabled(isSaving || isUploadingPhotos || session.accessToken == nil || content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .vlScreen()
            .navigationTitle("Escribir reseña")
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cerrar") { dismiss() } } }
        }
    }

    private func save() async {
        guard let token = session.accessToken else { return }
        isSaving = true; defer { isSaving = false }
        do {
            isUploadingPhotos = true
            var photoURLs: [URL] = []
            for (index, photo) in selectedPhotos.prefix(6).enumerated() {
                if let data = try? await photo.loadTransferable(type: Data.self) {
                    let uploaded: MobileUpload = try await APIClient.shared.upload("/me/uploads", data: data, fileName: "review-\(index).jpg", mimeType: "image/jpeg", bearer: token)
                    photoURLs.append(uploaded.url)
                }
            }
            isUploadingPhotos = false
            let request = ReviewRequest(venueId: item.venueID, eventId: item.eventID, rating: rating, title: title.nilIfBlank, content: content.nilIfBlank, photos: photoURLs.isEmpty ? nil : photoURLs)
            let _: MobileReview = try await APIClient.shared.post("/me/reviews", body: request, bearer: token)
            VLFeedback.success(); onSaved(); dismiss()
        } catch { isUploadingPhotos = false; errorMessage = (error as? LocalizedError)?.errorDescription ?? "No se pudo enviar la reseña."; VLFeedback.error() }
    }
}

private struct QuestionComposerView: View {
    let item: ExploreItem
    let onSaved: () -> Void
    @Environment(\.dismiss) private var dismiss
    @Environment(SessionStore.self) private var session
    @State private var content = ""
    @State private var isSaving = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                Section("Pregunta") { TextEditor(text: $content).frame(minHeight: 130) }
                if let errorMessage { Text(errorMessage).foregroundStyle(.red) }
                Button { Task { await save() } } label: { if isSaving { ProgressView() } else { Label("Enviar pregunta", systemImage: "paperplane.fill") } }
                    .disabled(isSaving || session.accessToken == nil || content.trimmingCharacters(in: .whitespacesAndNewlines).count < 5)
            }
            .vlScreen()
            .navigationTitle("Hacer pregunta")
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cerrar") { dismiss() } } }
        }
    }

    private func save() async {
        guard let token = session.accessToken else { return }
        isSaving = true; defer { isSaving = false }
        let request = QuestionRequest(venueId: item.venueID, eventId: item.eventID, content: content.trimmingCharacters(in: .whitespacesAndNewlines))
        do {
            let _: MobileQuestion = try await APIClient.shared.post("/me/questions", body: request, bearer: token)
            VLFeedback.success(); onSaved(); dismiss()
        } catch { errorMessage = (error as? LocalizedError)?.errorDescription ?? "No se pudo enviar la pregunta."; VLFeedback.error() }
    }
}

private extension ExploreItem {
    var venueID: String? { if case .venue(let value) = self { return value.id }; return nil }
    var eventID: String? { if case .event(let value) = self { return value.id }; return nil }
}

private extension String {
    var nilIfBlank: String? { let value = trimmingCharacters(in: .whitespacesAndNewlines); return value.isEmpty ? nil : value }
}
