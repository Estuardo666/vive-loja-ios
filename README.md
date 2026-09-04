# Vive Loja iOS

Cliente iOS nativo para Vive Loja. La aplicación consume la API versionada de `City-Listing` y usa SwiftUI, MapKit y Liquid Glass en iOS 26.

## Generar y abrir

```bash
brew install xcodegen
xcodegen generate
open ViveLoja.xcodeproj
```

El backend de referencia es `https://github.com/Estuardo666/City-Listing`.

## Fotos de locales desde Google

Las tarjetas de Inicio, Explorar y Guardados, las tarjetas de locales de Hoy en Loja y el detalle usan la foto propia primero. Si falta o falla, solicitan `GET /api/venues/{slug}/google-photo?size=small|large` al mismo host configurado para la API. El backend debe incluir este endpoint y tener `GOOGLE_PLACES_API_KEY` configurada; la clave nunca se incluye en la app.

El cliente obtiene la imagen directamente de Google usando una sesión efímera sin caché en disco. Muestra Google Maps y los autores, con acceso a la fuente original. VoiceOver dispone de la acción «Ver foto y fuente» en las tarjetas. Si no hay foto, falla la red o se recibe un límite de peticiones, se mantiene el marcador de imagen.

La integración requiere una nueva compilación instalada de iOS. Las peticiones de fotos pueden generar consumo de Google Places; la alerta de presupuesto del proyecto no corta automáticamente el servicio.

## CI local/remoto

Los workflows usan PostgreSQL efímero para backend y un iPhone Simulator iOS 26 para Swift. Esta fase no requiere certificados ni firma; Codemagic/Sideloadly se configurarán cuando exista Apple Developer Team ID.

### Codemagic unsigned

`codemagic.yaml` contiene un workflow manual para generar el proyecto con XcodeGen, ejecutar SwiftLint, compilar sin firma y correr XCTest/UI tests en un simulador. No incluye certificados, perfiles, Team ID ni tokens. Cuando exista un equipo de Apple, se puede añadir un workflow separado de distribución con secretos administrados por Codemagic sin modificar este pipeline de validación.
