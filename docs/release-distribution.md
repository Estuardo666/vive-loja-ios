# Distribución y release candidate

## Codemagic

`codemagic.yaml` define dos workflows, ambos sin firma:

- **`ios-simulator`** — XcodeGen, SwiftLint, build y tests en simulador. Es el que valida cada cambio.
- **`ios-unsigned-ipa`** — archive con `CODE_SIGNING_ALLOWED=NO` y empaquetado de un `.ipa` sin firmar.

Ninguno necesita secretos. Para una build firmada hay que añadir certificado, provisioning profile, Team ID y App ID como variables cifradas de Codemagic; nunca en Git.

## Capacidades que el App ID debe tener antes de firmar

`ViveLoja/ViveLoja.entitlements` declara dos capacidades. Si el App ID o el provisioning profile no las incluyen, la firma falla con *"Provisioning profile doesn't include the … entitlement"*, aunque la build sin firma pase sin problema:

| Entitlement | Capacidad a habilitar en el App ID |
|---|---|
| `aps-environment` | **Push Notifications** |
| `com.apple.developer.associated-domains` (`applinks:` + `webcredentials:`) | **Associated Domains** |

Ambas requieren una cuenta de pago. Una cuenta personal gratuita no las soporta: para sideload con Apple ID gratuito hay que quitar esas claves del entitlements antes de firmar, y la app funciona sin push remoto ni Universal Links (los recordatorios locales de eventos siguen operando).

## APNs: development frente a production

`aps-environment` **no** está fijo: se resuelve desde `VL_APS_ENVIRONMENT`, definido por configuración.

| Configuración | `VL_APS_ENVIRONMENT` | Entitlement | Token que registra la app |
|---|---|---|---|
| Debug, Staging | `development` | sandbox | `sandbox` |
| Release, Production | `production` | producción | `production` |

La app lee ese mismo valor (`AppEnvironment.apnsEnvironment`) y lo manda en `POST /me/devices`, así que el entitlement y el token no pueden discrepar. Importa porque un token de sandbox enviado a la puerta de producción de APNs se rechaza con `BadDeviceToken`, el backend borra el `DeviceToken` por muerto, y no hay ningún error visible: simplemente nunca llega una notificación.

Codemagic debe archivar con `-configuration Production` para TestFlight. `ViveLojaTests.testAPNsEnvironmentIsAValueTheBackendAccepts` falla si el valor deja de ser uno que `/me/devices` acepta.

## Sideloadly (build unsigned de QA)

El `.ipa` sin firmar sólo sirve para validar que compila y empaqueta. Para instalarlo en un dispositivo hace falta una firma válida de Apple: exportar un `.ipa` firmado desde Codemagic o Xcode y usar Sideloadly con una cuenta autorizada, respetando la caducidad del perfil y las políticas de Apple.

Con Apple ID gratuito, ver la nota sobre capacidades más arriba.

## Checklist antes de TestFlight

- `NEXTAUTH_URL` y `NEXT_PUBLIC_APP_URL` apuntan a `https://viveloja.com`.
- `APPLE_CLIENT_ID` está configurado y probado en staging.
- R2, Upstash y Neon usan credenciales rotadas y secretos del hosting.
- Las migraciones fueron verificadas contra una rama de Neon con
  `node scripts/verify-itinerary-migration.mjs` (repo backend) y respaldadas antes de aplicarse.
- `APPLE_TEAM_ID` configurado en el hosting: sin él la ruta AASA responde 404 a propósito y los Universal Links quedan inertes.
- AASA publicado con el Team ID real y `com.viveloja.app`, incluyendo `/rutas/*` y `/colecciones/*`.
- Clave APNs (`.p8`) cargada en el backend (`APNS_KEY_ID`, `APNS_TEAM_ID`, `APNS_PRIVATE_KEY`) y push probado en hardware.
- Accesibilidad, modo oscuro, Dynamic Type, modo avión y sesión vencida verificados en hardware.
