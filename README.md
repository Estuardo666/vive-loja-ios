# Vive Loja iOS

Cliente iOS nativo para Vive Loja. La aplicación consume la API versionada de `City-Listing` y usa SwiftUI, MapKit y Liquid Glass en iOS 26.

## Generar y abrir

```bash
brew install xcodegen
xcodegen generate
open ViveLoja.xcodeproj
```

El backend de referencia es `https://github.com/Estuardo666/City-Listing`.

## CI local/remoto

Los workflows usan PostgreSQL efímero para backend y un iPhone Simulator iOS 26 para Swift. Esta fase no requiere certificados ni firma; Codemagic/Sideloadly se configurarán cuando exista Apple Developer Team ID.
