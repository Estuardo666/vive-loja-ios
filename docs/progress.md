# Vive Loja iOS — progreso

## CP1 — base iOS y autenticación

- [x] Proyecto SwiftUI reproducible con XcodeGen, deployment iOS 26 y módulo `ViveLoja`.
- [x] URLSession/DTOs/errores, Observation y Keychain.
- [x] Login, registro, refresh/logout y sesión restaurable contra `/api/mobile/v1`.
- [x] Home/Explore/Saved/Account con fixtures para desarrollo sin red.
- [x] Liquid Glass en superficies funcionales y fallback de contenido sólido.
- [x] MapKit nativo con clustering, selección, radio de proximidad y búsqueda al mover cámara.
- [x] Detalle con hidratación remota, guardado local y enlace a Apple Maps.
- [x] CI macOS 26/Xcode 26.2 unsigned con build, XCTest y artifact `.xcresult`.

Último gate verde: [Actions run 33487048614](https://github.com/Estuardo666/vive-loja-ios/actions/runs/33487048614).

## Seguridad

- No hay secretos, certificados, Team ID ni provisioning profiles en el repositorio.
- La API de producción se configura por código únicamente con su URL pública; las credenciales permanecen en el backend/hosting.

## Siguiente checkpoint

CP2/CP3: design tokens y navegación profunda, estados de accesibilidad, paginación y contenido público adicional (blog/ofertas/rutas).
