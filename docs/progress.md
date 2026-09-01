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

Último gate verde: [Actions run 33529119473](https://github.com/Estuardo666/vive-loja-ios/actions/runs/33529119473) (SwiftLint, build unsigned, XCTest/UI smoke, screenshots, hub de contenido, detalle fixture, filtros + mapa, moderación de mensajes, errores offline/401, transporte lento, Dynamic Type, wizards de creación con sesión fixture, colecciones, check-in, fotos de reseña y retry SSE tras desconexión).

## Seguridad

- No hay secretos, certificados, Team ID ni provisioning profiles en el repositorio.
- La API de producción se configura por código únicamente con su URL pública; las credenciales permanecen en el backend/hosting.

## CP2/CP3/CP5/CP6/CP7/CP8 — en curso

- [x] Navegación principal con tabs, sheets y deep links públicos.
- [x] Design tokens indigo/coral/emerald, Liquid Glass y fallback Reduce Transparency.
- [x] Contenido móvil adicional conectado al backend (promociones, rutas y colecciones).
- [ ] Snapshots claro/oscuro y Dynamic Type; UI smoke tests de tabs/explorar ya añadidos.
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

## Siguiente checkpoint

Siguiente gate: cerrar snapshots/Dynamic Type y pruebas de red lenta/modo avión; la distribución firmada queda para Codemagic/TestFlight con credenciales externas.
