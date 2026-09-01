# Distribución y release candidate

## Codemagic

1. Conectar el repositorio `Estuardo666/vive-loja-ios` y seleccionar la rama `main`.
2. Usar una máquina macOS con Xcode 26.2 y ejecutar `brew install xcodegen && xcodegen generate`.
3. Ejecutar `xcodebuild test -project ViveLoja.xcodeproj -scheme ViveLoja -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.2'`.
4. Para distribución, añadir el certificado, provisioning profile, Team ID y App ID como secretos de Codemagic; nunca guardarlos en Git.
5. Inyectar `CODE_SIGN_ENTITLEMENTS=ViveLoja/ViveLoja.entitlements` y verificar Universal Links en un dispositivo físico.

## Sideloadly (build unsigned de QA)

La build unsigned de Actions sólo sirve para validar compilación y tests. Para instalar en un dispositivo se necesita una firma válida de Apple. Exportar un `.ipa` firmado desde Codemagic/Xcode y usar Sideloadly con una cuenta autorizada, respetando la caducidad del perfil y las políticas de Apple.

## Checklist antes de TestFlight

- `NEXTAUTH_URL` y `NEXT_PUBLIC_APP_URL` apuntan a `https://viveloja.com`.
- `APPLE_CLIENT_ID` está configurado y probado en staging.
- R2, Upstash y Neon usan credenciales rotadas y secretos del hosting.
- La migración `MobileRefreshSession` fue respaldada y aprobada antes de aplicarse.
- AASA publicado con el Team ID real y `com.viveloja.app`.
- Accesibilidad, modo oscuro, Dynamic Type, modo avión y sesión vencida verificados en hardware.
