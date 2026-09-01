# Universal Links

La app ya declara `applinks:viveloja.com` y enruta URLs públicas mediante `DeepLinkRouter`.

Antes de firmar una build, registrar el mismo App ID en Apple Developer y publicar en
`https://viveloja.com/.well-known/apple-app-site-association` un archivo AASA con el Team ID
real y el bundle ID `com.viveloja.app`. El Team ID se deja fuera del repositorio y se inyecta
en el perfil de firma de CI/Distribución.

Validación del release:

1. Instalar la build firmada en un dispositivo físico.
2. Abrir `https://viveloja.com/locales/<slug>` y `https://viveloja.com/eventos/<slug>` desde Mail/Mensajes.
3. Confirmar que el sistema ofrece Vive Loja y que el router muestra el detalle correcto.
