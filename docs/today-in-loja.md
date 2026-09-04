# Hoy en Loja

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
