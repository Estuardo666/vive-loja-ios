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

Último gate verde: [Actions run 33496720473](https://github.com/Estuardo666/vive-loja-ios/actions/runs/33496720473).

## Seguridad

- No hay secretos, certificados, Team ID ni provisioning profiles en el repositorio.
- La API de producción se configura por código únicamente con su URL pública; las credenciales permanecen en el backend/hosting.

## CP2/CP3/CP6/CP7 — en curso

- [x] Navegación principal con tabs, sheets y deep links públicos.
- [x] Design tokens indigo/coral/emerald, Liquid Glass y fallback Reduce Transparency.
- [x] Contenido móvil adicional conectado al backend (promociones, rutas y colecciones).
- [ ] Snapshots claro/oscuro, Dynamic Type y UI tests de contenido.
- [ ] Paginación por cursor/carga incremental.
- [x] Perfil y reservas consumen contratos móviles autenticados.
- [x] Mensajería básica consume inbox y envío autenticado.
- [ ] Conversación detallada/SSE, cancelación de reservas y reseñas.

## Siguiente checkpoint

CP4: completar gates de accesibilidad y paginación, después cerrar pruebas geométricas/UI de MapKit.
