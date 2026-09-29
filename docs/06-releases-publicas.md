# Releases públicas con el código en privado

## El problema

El repo del código es **privado**. Los assets de un Release privado solo se
descargan **con un token**, y la app no puede llevar uno: un APK se abre y se
lee, así que cualquier token embebido es público en la práctica.

Resultado: `checkForUpdate()` consultaba `api.github.com` sin autenticación,
recibía **404** y el aviso de "hay una versión nueva" nunca aparecía (el numerito
de la tuerca tampoco). El modal de actualización y la hoja de versiones quedaban
vacíos.

## La salida: separar CÓDIGO de BINARIOS

```
┌───────────────────────────┐        ┌──────────────────────────────┐
│  QuopTron/bitly           │        │  QuopTron/bitly-releases     │
│  (PRIVADO)                │ espeja │  (PÚBLICO)                   │
│                           │ ─────► │                              │
│  · el código              │        │  · NO tiene código           │
│  · el workflow de release │        │  · solo Releases con los     │
│  · la release "fuente"    │        │    binarios ya compilados    │
└───────────────────────────┘        └──────────────────────────────┘
                                                  ▲
                                                  │ sin token, sin login
                                       ┌──────────┴──────────┐
                                       │  la app (detector)  │
                                       └─────────────────────┘
```

El repo público **no expone nada del código**: son solo binarios que el usuario
va a bajar igual. Lo único que cambia es que la API pública responde sin
autenticación y los assets se descargan por URL directa.

## Configuración (una sola vez)

1. **Crear el repo público de releases**, por ejemplo `QuopTron/bitly-releases`.
   Que esté **vacío**: no necesita README, ni código, ni ramas con contenido.

2. **Crear un token** (fine-grained PAT) con:
   - *Repository access*: **solo** `QuopTron/bitly-releases`
   - *Permissions*: **Contents: Read and write**

   En el repo privado → *Settings → Secrets and variables → Actions → New
   repository secret*, guardarlo como **`RELEASES_TOKEN`**.

3. **(Opcional)** Si el repo público se llama distinto, definí la variable de
   repo `PUBLIC_RELEASES_REPO` (ej. `mi-org/mis-binarios`) en *Variables*. Por
   defecto el workflow usa `QuopTron/bitly-releases`.

4. **Revisar los dos nombres en el código** (tienen que coincidir con el paso 1):

   | Dónde | Qué |
   |---|---|
   | `lib/features/ajustes/update/base/update_service.dart` | `repoPublico` |
   | `.github/workflows/release.yml` (job `release-publico`) | `PUBLIC_RELEASES_REPO` |

   Todo lo demás (`releaseUrl`, la lista de versiones, el enlace de la PWA) sale
   de esa única constante `UpdateService.repoPublico`.

## Publicar

El release se lanza a mano: local con `scripts/release/release.sh --upload` (que
compila, publica en el repo privado y **verifica el espejo**, ver abajo) o desde
la web con el workflow `Release` (`workflow_dispatch`).

`release.yml` compila Android + Windows + PWA, publica la release en el repo
privado (fuente de verdad) y después el job **`release-publico`** baja esos
mismos assets y los sube al repo público con el mismo tag. No recompila nada, así
que no hay forma de que se publiquen binarios distintos en cada lado.
`release-macos.yml` (Apple) llama al MISMO espejo después de publicar el
`.dmg` y el `.ipa`, así que la release se completa sin importar qué workflow
corrió último.

### Chequeo previo (antes de compilar)

`release.sh --upload` corre un **preflight** antes de tocar nada: verifica que
`gh` esté instalado y autenticado, que su token tenga el scope `workflow` (es lo
que permite disparar el espejo), que el workflow del espejo exista y esté activo,
que el secret `RELEASES_TOKEN` esté configurado, que el repo público responda
**sin token** (como lo ve la app) y que `PUBLIC_RELEASES_REPO` —si está definida—
sea el mismo repo que lee la app. Si algo falta, **corta antes de compilar** con
el arreglo exacto: un build completo tarda mucho como para descubrir al final
que nadie iba a poder bajar el resultado.

## El espejo es OBLIGATORIO (y se verifica)

Sin espejo la release no existe para nadie: la app y el sitio leen el repo
público, así que si el paso no corre (o corre a medias) no hay ninguna descarga
que ofrecer. Por eso dejó de ser "best-effort":

| Situación | Qué pasa |
|---|---|
| Falta el secret `RELEASES_TOKEN` | El job **FALLA** con la instrucción de configurarlo. |
| Un asset que existe en el privado no quedó en el público, o llegó con **otro tamaño** (subida a medias) | El job **FALLA** y nombra los assets que faltan. |
| A la release le falta el binario de una plataforma (el `.dmg`/`.ipa` antes de que corra el workflow de Apple) | **AVISO** (`::warning::`): dice cuál falta y cómo completarla. No rompe el release de Android/PC. |

La verificación es asset por asset (nombre + tamaño) contra la release privada, y
el resultado queda en una tabla en la página del run (*Summary*), además de las
anotaciones:

```
| Tag      | Assets en la privada | Sin espejar | Plataformas ausentes   |
|----------|----------------------|-------------|------------------------|
| v0.9.28  | 4                    | —           | macOS(.dmg) iOS(.ipa)  |
```

Para reintentar el espejo de un tag (por ejemplo si el token se configuró
después):

```bash
gh workflow run espejo-releases.yml --repo QuopTron/bitly -f tag=v0.9.28
```

El espejo también corre **solo** cada 6 h (red de seguridad) y sincroniza las
últimas 3 releases: sube lo que falte o haya cambiado de tamaño, así que en el
caso normal no baja ni sube nada.

## Nunca un PAT clásico dentro de un binario (`ghp_…`)

Los binarios **compilan `lib/config/secretos.dart`**: lo que esté ahí viaja
adentro del APK/`.exe`, y estos binarios se publican en un repo **público**. Un
PAT clásico de GitHub (`ghp_…`) da acceso a **todos** los repos de la cuenta, así
que publicarlo es entregar la cuenta: se saca con `unzip` + `grep`.

Pasó de verdad: el APK de la **0.9.28** salió de un build **local** (con el
`secretos.dart` del momento) llevando un `ghp_…` embebido, y quedó descargable
sin token; hubo que **revocar ese token**. Los builds de CI no lo filtraban por
simple casualidad: `PREMIUM_GITHUB_TOKEN` no está configurado, así que salían
sin token premium (con la validación de códigos premium rota — mirá los
`::warning::` del run).

Lo correcto para ese token es uno **fine-grained** con `Contents: Read` **solo**
sobre `QuopTron/bitly_codes_premium`: es el único que necesita viajar dentro del
binario. Hay tres barreras antes de que un token clásico se publique:

| Dónde | Qué revisa | Efecto |
|---|---|---|
| `release.sh` (preflight, antes de compilar) | que `secretos.dart` no tenga `ghp_…` | corta sin perder el build |
| `release.sh` (con los binarios ya en `dist/`) | cada APK (`unzip` + `grep` sobre `libapp.so`) y el bundle de Windows (`build/windows/**/Release/data/app.so`) | corta antes de crear la release |
| `espejo-releases.yml` (justo antes de subir) | el APK que va a quedar público | última barrera: falla y no publica |

En el `.exe`/`.dmg`/`.ipa` el payload va comprimido y el `grep` no ve nada: por
eso el chequeo del lado del build mira el **bundle** (que va sin comprimir y es
lo que el instalador empaqueta) y no el instalador.

Si un token llegó a salir en un binario publicado, revocalo en
<https://github.com/settings/tokens>: queda inerte al instante, sin importar
cuántas copias del binario anden dando vueltas.

## Migrar las versiones que YA están instaladas

La separación código/binarios no resuelve sola un detalle: las apps publicadas
**hasta la 0.9.25 inclusive** consultan `https://api.github.com/repos/QuopTron/bitly/releases/latest`
— el repo del CÓDIGO — porque el cambio a `repoPublico` recién entra en la 0.9.26.

Mientras ese repo esté **privado**, la API responde **404 anónimo** y esas apps no
ven ninguna actualización (era el síntoma con 0.9.21…0.9.25). No se puede parchear:
ya están instaladas.

La salida es una **ventana pública**: por unos días `QuopTron/bitly` se pone público,
la release privada pasa a ser legible sin token y el parque instalado se actualiza a
la 0.9.26; después se vuelve a privado. No hay que repetirlo: de la 0.9.26 en adelante
el detector apunta al espejo público.

```bash
# 1) Abrir la ventana (con el release nuevo ya publicado)
gh api -X PATCH repos/QuopTron/bitly -f private=false

# 2) Comprobarlo como lo ve la app: 200 + el tag nuevo
curl -s https://api.github.com/repos/QuopTron/bitly/releases/latest | grep '"tag_name"'

# ... esperar a que el parque se actualice ...

# 3) Cerrar la ventana
gh api -X PATCH repos/QuopTron/bitly -f private=true
```

Durante la ventana el **código queda visible** (todo el historial). Antes de abrirla,
revisá que no haya secretos commiteados:

```bash
git log --all --diff-filter=A --name-only --pretty=format: \
  | sort -u | grep -iE 'secretos|\.env$|key\.properties|keystore|\.pem$'
```

Un 404 persistente con el repo ya público suele ser que la última release es igual
a la instalada (no hay nada que mostrar) o que se agotó el límite anónimo de 60
consultas por hora y por IP.

## Comprobar que quedó bien

```bash
# Debe responder 200 con la última versión (sin token, como la app):
curl -s https://api.github.com/repos/QuopTron/bitly-releases/releases/latest \
  | grep '"tag_name"'

# Los assets tienen que estar y ser descargables sin autenticación:
curl -sI https://github.com/QuopTron/bitly-releases/releases/download/v0.9.26/app-arm64-v8a-release.apk \
  | head -1
```

Si el primero devuelve **404**, es que el repo público todavía no tiene ninguna
release publicada (GitHub responde 404, no una lista vacía).

## Detalles que importan

- **Nombres de asset**: tienen que seguir siendo `app-arm64-v8a-release.apk`,
  `app-armeabi-v7a-release.apk`, `app-x86_64-release.apk`, `Bitly-Setup-X.Y.Z.exe`
  (y `Bitly-Setup-X.Y.Z-arm64.exe` en las PCs ARM) y `Bitly-X.Y.Z-macos.dmg`.
  Son los que busca `UpdateAssets.patronesAsset` para elegir el archivo correcto
  según la plataforma y la arquitectura del equipo. En iOS y Linux el detector
  no ofrece descarga in-app a propósito: ahí no hay binario que instalar desde
  acá (iOS va por TestFlight/App Store; el proyecto no publica nada para Linux).
- **Sin `generate_release_notes`** en el repo público: las notas se generarían
  desde los commits del repo privado y terminarían públicas.
- **Límite de la API**: sin token son 60 consultas por hora y por IP. La app
  consulta una vez por apertura, así que sobra. Si algún día molesta, el mismo
  JSON se puede servir desde el Worker que ya existe, sin tocar la app.
- **La release privada no hace falta borrarla**: sirve como fuente de verdad y
  para el historial del repo. Si preferís no publicar nada ahí, se puede dejar
  solo el espejo público quitando los pasos `softprops/action-gh-release`.
- **`/releases/latest` no es "la versión más alta"**, es la release CREADA más
  recientemente: si el espejo sube tarde una release vieja, `latest` apunta hacia
  atrás. Por eso el detector de la app usa `latest` como camino rápido y, si eso
  no da una actualización, elige la versión más alta del listado que tenga
  binario para esa plataforma (`UpdateService.elegirReleaseMasNueva`).
