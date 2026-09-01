# QA del cliente iOS

## Flujos críticos

- Inicio, explorar lista/mapa y detalle de local/evento.
- Favorito optimista con rollback cuando la API falla.
- Registro, login, refresh de un solo uso, logout y restauración de sesión.
- Reserva, idempotencia, cancelación fuera/dentro de la ventana y estado vacío.
- Conversación, marcado leído, SSE en foreground y reconexión tras volver a la app.
- Reseña con moderación, hasta seis fotos y pregunta autenticada.
- Intereses, avatar, recordatorios locales y permisos de ubicación/fotos/notificaciones.
- Colecciones, check-in cercano y wizards de evento/local/artículo/ruta.

## Matriz visual

Ejecutar en iPhone 17 Pro Simulator (iOS 26.2) con modo claro/oscuro, tamaños Dynamic Type `xSmall`, `default` y `accessibility3`, Reduce Motion y Reduce Transparency. Guardar los `.xcresult` y capturas como artifacts de la ejecución de Actions.

La matriz automatizada actual cubre default, `XS`, `Accessibility3` y `Accessibility5` y comprueba los tabs, controles principales y labels accesibles: [Actions run 33540266729](https://github.com/Estuardo666/vive-loja-ios/actions/runs/33540266729) (15 XCTest + 13 UI tests, 0 fallos). La validación final de VoiceOver, tamaños extremos y navegación táctil debe repetirse en un iPhone físico antes de firmar.

## Fallos de red

Simular latencia de 3G, respuestas 401/409/422/5xx, modo avión e imágenes ausentes. La interfaz debe mostrar estado de carga, error recuperable y acción de reintento sin perder datos escritos.
