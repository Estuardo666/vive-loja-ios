# Hoy en Loja

## Agenda and layout update

Home events use a paged, one-card-per-view image carousel. Tourist routes in Home
and Discover use image grids. AgendaView consumes `/agenda` with today, tomorrow,
weekend and upcoming filters, grouped using America/Guayaquil dates. Unknown price
is labelled as such. Route creation includes numeric minutes, cover image URL and
ordered custom stops with coordinates, backed by the existing moderated `/me/routes`.

Saved → Changes in events consumes `/me/event-updates`. Event detail reads the
optional status, marks cancellations and removes an existing local reminder when
the cancelled detail is opened. Push delivery uses the existing APNs setup; an
offline local reminder cannot be withdrawn remotely without the app handling the update.

MapItemPeekView measures its content for the presentation detent, avoiding a fixed
empty area underneath while accommodating longer addresses and larger text.
Backend migration `20260904020000_event_update_notices` must precede rollout.

Home presents `TodayInLojaView`, backed by `/api/mobile/v1/today` from the same
API environment as the rest of the app. Cards navigate through DeepLinkRouter
to existing venue, event, route and public collection screens. Event times use
America/Guayaquil rather than the phone's timezone. Empty/error/retry states do
not invent places or reuse yesterday's content as today's suggestions.

Directions from the map peek, item detail and route stops call InteractionTracker
without waiting for analytics. Authenticated saves are measured server-side in
the favorites transaction; local-only anonymous saves are not uploaded as analytics.
BusinessDashboardView reads optional `interactions` from the venue insights API,
so older server responses still decode.

Tests: TodayTests (contract, time zone, collection navigation) and
testTodayEmptyStateWithoutNetwork (`-uiTesting-today`). Existing screenshot
fixtures retain their previous content; the new section has its own fixture.

Release backend/web and its additive InteractionEvent migration first, then build
the iOS app with the existing Production configuration. Xcode build/UI tests must
run on macOS CI; they have not been executed in this Windows implementation session.
