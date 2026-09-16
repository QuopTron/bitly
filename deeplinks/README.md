# Enlaces que abren Bitly en cualquier plataforma

Lo que hace que un enlace compartido abra **la app** (y no el navegador o el
selector de apps) no es código de la app: son **dos archivos** publicados en el
dominio del enlace, más **dos declaraciones** en la app.

```
.well-known/assetlinks.json             ← Android (App Links)
.well-known/apple-app-site-association  ← iOS (Universal Links)
_headers                                ← Content-Type: application/json
open/index.html                         ← respaldo si NO hay app instalada
```

Son ~400 bytes de JSON y una página: **no es una web** ni tiene relación con el
contenido de otro sitio. Es el "dominio dueño de los enlaces": Android e iOS le
preguntan *"¿este enlace es de la app com.example.bitly?"* y, si el archivo dice
que sí, abren la app en vez del navegador.

## Plan elegido: hostearlos en `bitly-site.pages.dev`

Tu sitio (repo `QuopTron/bitly-site`, TanStack Start + Vite en Cloudflare Pages)
publica lo que esté en la carpeta **`public/`** de la raíz: Vite copia ese
contenido tal cual a `dist/client`, que es lo que Cloudflare sirve.

```
bitly-site/                 (repo aparte)
└── public/                  ← creada y publicada en master
    ├── _headers
    ├── .well-known/
    │   ├── assetlinks.json
    │   └── apple-app-site-association
    └── open/
        └── index.html
```

Quedan publicados en:

- `https://bitly-site.pages.dev/.well-known/assetlinks.json`
- `https://bitly-site.pages.dev/.well-known/apple-app-site-association`
- `https://bitly-site.pages.dev/open?s=...` (página de respaldo)

Los mismos archivos están acá en `deeplinks/` como copia de referencia.

## Qué quedó hecho en la app

| Pieza | Estado |
|---|---|
| `android/app/src/main/AndroidManifest.xml` | `android:autoVerify="true"` + `host="bitly-site.pages.dev"`, `pathPrefix="/open"` |
| `ios/Runner/Runner.entitlements` (+ `project.pbxproj`) | `applinks:bitly-site.pages.dev`, ligado a las 3 configuraciones |
| `ios/Runner/Info.plist` | esquema `bitly://` + `FlutterDeepLinkingEnabled=false` |
| `ios/Runner/AppDelegate.swift` | Universal Link y `bitly://` reenviados a Dart (`com.bitly/deep_link`) |
| `servicio_compartir.dart` | host en una sola constante (`BITLY_LINK_HOST` por `--dart-define`) y los hosts viejos siguen aceptándose |

El dominio tiene que ser **el mismo** en esos tres lugares: constante Dart,
manifest y entitlement. Si no coinciden, el enlace no abre la app directo.

## Verificación

```bash
# Los dos archivos tienen que dar 200 + application/json
curl -sI https://bitly-site.pages.dev/.well-known/assetlinks.json
curl -sI https://bitly-site.pages.dev/.well-known/apple-app-site-association

# Android: tiene que decir "verified" (después de instalar la app nueva)
adb shell pm verify-app-links --re-verify com.example.bitly
adb shell pm get-app-links com.example.bitly

# Prueba real: sin selector de apps, abre Bitly
adb shell am start -a android.intent.action.VIEW -d "https://bitly-site.pages.dev/open?s=..."
```

Sin el archivo publicado, `pm resolve-activity` devuelve `ResolverActivity` (el
selector de apps); con el dominio verificado, el enlace abre la app y recién
ahí Dart descifra el payload. Estado actual, ya comprobado en el emulador:

```
pm get-app-links com.example.bitly   →   bitly-site.pages.dev: verified
am start VIEW https://bitly-site.pages.dev/open?s=... (sin indicar la app)
   →  topResumedActivity = com.example.bitly/.MainActivity
   →  [Compartido] enlace de Pablo: NUEVAYoL (USUM72500857)
```

## iOS

Falta tu **Team ID** en `apple-app-site-association`:

```json
"appIDs": ["XXXXXXXXXX.com.example.bitly"]
```

Sale de developer.apple.com → *Membership*. Además iOS necesita **cuenta Apple
Developer paga**: los equipos personales no soportan la capability *Associated
Domains*. Apple cachea el archivo en su CDN y puede tardar hasta 24 h.

## Notas honestas

- **Firma de Android:** `assetlinks.json` ya lleva la SHA-256 de tu keystore de
  release (`2D:EF:EF:...:BA:3D`). Si algún día publicás en Play con *Play App
  Signing*, hay que **agregar** la SHA-256 de Google (Play Console → *Integridad
  de la app*) al mismo array: se pueden poner varias.
- **PC (Windows/macOS):** un `https://` no puede abrir una app de escritorio sin
  registrar un manejador de protocolo en el sistema. La página de respaldo cubre
  ese caso: copiás el enlace y lo pegás en Bitly (*Compartir → Bitly*).
- **Sin app instalada** el enlace cae en la landing, que explica qué hacer.
