# Vive Loja iOS — progreso

## CP1 — base iOS y autenticación (cerrado)

- [x] Proyecto SwiftUI reproducible con XcodeGen, deployment iOS 26 y módulo `ViveLoja`.
- [x] URLSession/DTOs/errores, Observation y Keychain.
- [x] Login, registro, refresh/logout y sesión restaurable contra `/api/mobile/v1`.
- [x] Home/Explore/Saved/Account con fixtures para desarrollo sin red.
- [x] Liquid Glass en superficies funcionales y fallback de contenido sólido.
- [x] MapKit nativo con clustering, selección, radio de proximidad y búsqueda al mover cámara.
- [x] Detalle con hidratación remota, guardado local y enlace a Apple Maps.
- [x] Guardados con persistencia local y sincronización opcional contra `/me/favorites` cuando hay sesión.
- [x] Blog público desde `/content`, categorías dinámicas y estados vacío/error/offline.
- [x] CI macOS 26/Xcode 26.2 unsigned con build, XCTest y artifact `.xcresult`.
- [x] Sign in with Apple preparado: nonce criptográfico, identity token y nombre enviados al endpoint móvil.
- [x] Router de deep links para `viveloja.com/locales|eventos|blog/...` y esquema `viveloja://`.
- [x] Hub de contenido público con historias, promociones, rutas y colecciones; estados vacío/error y pull-to-refresh.
- [x] Pruebas XCTest para identificadores, persistencia, URL canónica y deep links.
- [x] Cuenta conectada a perfil remoto con edición de nombre y estadísticas.
- [x] Pantalla de reservas autenticadas con estados de carga, vacío, error y refresh.
- [x] Inbox móvil con conversaciones, unread count y composer básico.
- [x] Wizard de publicación de eventos con fecha futura, validación y estado pendiente de moderación.
- [x] Accesibilidad base en tarjetas/categorías y feedback háptico de selección, éxito y error.
- [x] Distancias Haversine y radios de proximidad cubiertos por XCTest.
- [x] Recordatorios locales de eventos con UserNotifications y cancelación.

Gate funcional previo: [Actions run 33546960854](https://github.com/Estuardo666/vive-loja-ios/actions/runs/33546960854) sobre `8658000` (SwiftLint sin warnings de aislamiento, build unsigned, 15 XCTest + 13 UI tests, matriz Dynamic Type default/XS/Accessibility3/Accessibility5, exportación de attachments a los artifacts `ios-test-results`/`ios-screenshots`, hub de contenido, detalle fixture, filtros + mapa, moderación de mensajes, errores offline/401, transporte lento, wizards de creación con sesión fixture, colecciones, check-in, fotos de reseña, retry SSE tras desconexión, rotación/limpieza de sesiones expiradas, recuperación UI y capturas ampliadas dark mode/Dynamic Type). El harness oscuro usa `-uiTesting-dark` y sólo aplica `.preferredColorScheme(.dark)` durante UI testing para que las capturas sean deterministas sin afectar producción.

El gate de accesibilidad de tabs también quedó verde en [Actions run 33555197439](https://github.com/Estuardo666/vive-loja-ios/actions/runs/33555197439), sobre `1f307b4`: build unsigned, SwiftLint, 15 XCTest y 14 UI tests sin fallos. `testMainTabsPassAccessibilityAudit` valida el auditor de accesibilidad de Xcode; la portada usa una fuente escalable y la acción del mapa una superficie opaca de alto contraste. Los avisos de telemetría del runner y la advertencia de deprecación de Node.js 20 pertenecen a la infraestructura de GitHub y no afectan el resultado.

El `manifest.json` exportado en ese run contiene 13 attachments PNG asociados a los flujos de tabs, explorar/mapa, hub de contenido, detalle, Dynamic Type, dark mode, sesión vencida y wizards autenticados. Las dimensiones y nombres esperados están presentes; el baseline pixelado comparativo sigue deliberadamente pendiente hasta revisar una captura aprobada en el mismo dispositivo objetivo.

## Seguridad

- No hay secretos, certificados, Team ID ni provisioning profiles en el repositorio.
- La API de producción se configura por código únicamente con su URL pública; las credenciales permanecen en el backend/hosting.
- QA en dispositivo real queda pendiente de un host macOS con Xcode/devicectl y un iPhone emparejado; este workspace Windows sólo puede validar el Simulator de GitHub Actions.

## CP2/CP3/CP5/CP6/CP7/CP8 — en curso

- [x] Navegación principal con tabs, sheets y deep links públicos.
- [x] Design tokens indigo/coral/emerald, Liquid Glass y fallback Reduce Transparency.
- [x] Contenido móvil adicional conectado al backend (promociones, rutas y colecciones).
- [ ] Snapshots comparativas exhaustivas claro/oscuro; UI smoke ya exporta capturas claras y oscuras en `ios-screenshots`, el auditor de accesibilidad pasa en Simulator y el baseline pixelado sigue pendiente.
- [x] Dynamic Type de accesibilidad verificado con `UICTContentSizeCategoryAccessibility3` y `Accessibility5`; la matriz automatizada del Simulator cubre default, `XS`, `Accessibility3` y `Accessibility5`; queda pendiente la validación completa en dispositivo.
- [x] Carga incremental de historias con `postSkip` y metadatos de continuación.
- [x] Perfil y reservas consumen contratos móviles autenticados.
- [x] Mensajería básica consume inbox y envío autenticado.
- [x] Conversación detallada, marcado leído y SSE best-effort en foreground.
- [x] Cancelación de reservas con ventana de seguridad y rollback de favoritos.
- [x] Detalle con galería/servicios, reseñas y preguntas; formularios autenticados.
- [x] Reseñas con hasta seis fotos mediante upload multipart a R2.
- [x] Primer flujo de creación de evento conectado a `/me/events`.
- [x] Portada de evento mediante PhotosPicker + upload multipart a R2.
- [x] Colecciones privadas y check-in de local con validación de proximidad.
- [x] Wizards de evento, local, artículo y ruta; todos crean borradores `PENDING`.
- [x] Onboarding de intereses y preferencias conectado a `/me/interests`.
- [x] Decodificación XCTest de reseñas con fotos y compatibilidad con payload legado (`comment`).
- [x] APIClient XCTest con URLProtocol para éxito, 401 y modo offline; UI smoke adjunta capturas claras y Dynamic Type de accesibilidad.
- [x] SwiftLint integrado en GitHub Actions con reglas de estilo activas y excepción documentada sólo para longitud de línea.
- [x] Exploración iOS expone filtros paridad backend (rating, abierto, verificado, promociones, servicios, precio y fechas).
- [x] Mensajería iOS permite reportar y bloquear/desbloquear participantes con confirmación y feedback háptico.
- [x] El stream SSE se detiene en background y se reinicia al volver a foreground; el refresh REST sigue siendo la fuente autoritativa.
- [x] UI smoke de mapa y aplicación de filtros en Simulator; XCTest de conteo/reset de filtros.
- [x] XCTest de transporte lento y reconexión SSE con URLProtocol; el workflow cancela runs obsoletos del mismo branch.
- [x] Hub de contenido navegable con fixtures y estado vacío verificable sin red.
- [x] Entorno de UI testing autenticado aislado (`-uiTesting-authenticated`) y navegación verificable de los cuatro wizards sin tráfico externo.
- [x] Workflow Codemagic unsigned reproducible en `codemagic.yaml`; README documenta límites de firma y secretos.
- [x] `SessionStore.refresh()` rota tokens y limpia credenciales sólo cuando el refresh responde 401; cobertura XCTest con almacenamiento seguro inyectable.
- [x] Al expirar la sesión, la raíz muestra recuperación accesible hacia inicio de sesión; fixture UI `-uiTesting-expired-session` verificado en CI.
- [x] Auditor de accesibilidad de las tabs principales en Simulator; la portada respeta Dynamic Type y el CTA del mapa supera el contraste WCAG en `33555197439`.

## Siguiente checkpoint

Siguiente gate: cerrar snapshots comparativas claro/oscuro con baseline revisado y la matriz completa de accesibilidad en dispositivo; las pruebas de red lenta, modo avión, sesión vencida y retry SSE ya tienen cobertura automatizada. La distribución firmada queda para Codemagic/TestFlight con credenciales externas.
