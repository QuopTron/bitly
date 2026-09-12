# Instalar Bitly en un Smart TV

// Guía de instalación en TV (Android TV / Google TV / Fire TV) por sideload,
// con el mismo flujo que usan las apps tipo "Magis": se le da al usuario un
// CÓDIGO corto para escribir en la app Downloader, y Downloader baja el APK
// de la última release.
//
// Se conecta con: .github/workflows/* (genera los APK), android/app/src/main
// /AndroidManifest.xml (declara el arranque de TV) y lib/shared/utilidades
// /deteccion_plataforma.dart (elige el layout de PC en TV).
// Parte del flujo: distribución.

---

## 1. ¿En qué TV funciona?

| Dispositivo | ¿Se puede? | Cómo entra |
|---|---|---|
| **Android TV / Google TV** (Chromecast con Google TV, NVIDIA Shield, Xiaomi, TCL, Hisense, Sony, TV Box) | ✅ Sí | Downloader (sideload) o Play Store para TV |
| **Fire TV / Fire TV Stick / Fire TV Cube** (Amazon) | ✅ Sí | Downloader desde la Amazon Appstore |
| Samsung (Tizen) o LG (webOS) | ❌ No directo | Se les conecta un **Fire TV Stick / Chromecast / TV Box** por HDMI |
| Apple TV (tvOS) | ❌ No | tvOS no ejecuta apps de Android ni Flutter |

No hace falta publicar en ninguna tienda: el APK se instala "por fuera"
(sideload), que es exactamente lo que permite el flujo de número.

---

## 2. Qué APK le toca a cada TV

El release publica **un APK por arquitectura** (para que pese poco):

| Archivo | Le sirve a |
|---|---|
| `app-arm64-v8a-release.apk` | **La mayoría de TVs y sticks modernos** (Chromecast con Google TV, Shield, Fire TV Stick 4K / 4K Max / Cube, Mi Box) |
| `app-armeabi-v7a-release.apk` | TVs y sticks viejos de 32 bits (Fire TV Stick de 1.ª/2.ª gen) |
| `app-x86_64-release.apk` | Emulador y algunos boxes Intel |

> Si no sabés cuál es, empezá por **arm64-v8a**. En el 95% de los casos es esa.

URL directa del último release (siempre apunta al más nuevo, no hay que
actualizarla en la guía ni en el código):

```
https://github.com/QuopTron/bitly/releases/latest/download/app-arm64-v8a-release.apk
```

---

## 3. Flujo recomendado: Downloader + código (el de "Magis")

### 3.1 En la TV

1. Instalar la app **Downloader by AFTVnews**:
   - **Android TV / Google TV** → Play Store → buscar *Downloader*.
   - **Fire TV** → Amazon Appstore → buscar *Downloader*.
2. Habilitar la instalación de apps desconocidas **para Downloader**:
   - Android TV: *Ajustes → Apps → Acceso especial → Instalar apps
     desconocidas → Downloader → Permitir*.
   - Fire TV: *Ajustes → Mi Fire TV → Opciones de desarrollador → Instalar
     apps desconocidas → Downloader → Activar*.
   *(Si no aparece Downloader en esa lista es un bug conocido de Fire OS:
   reiniciar el dispositivo lo arregla.)*
3. Abrir **Downloader** y, en el campo de URL, escribir el **código corto**
   (por ejemplo `12345`) o pegar la URL directa de la sección 2.
4. Tocar **Go** → descargar → **Instalar**.
5. Abrir **Bitly** desde la fila de apps de la TV.

### 3.2 Las URL cortas (ya creadas, sin captcha)

El campo de Downloader acepta **código numérico, búsqueda o URL completa**.
El acortador oficial de AFTVnews (`go.aftvnews.com`) exige resolver un
reCAPTCHA para emitir el número de 5 dígitos, así que usamos **URLs cortas
propias** (creadas en spoo.me, sin captcha) que hacen exactamente lo mismo:

| URL corta a escribir en Downloader | Baja |
|---|---|
| **`https://spoo.me/bitly-tv`** | arm64-v8a (TVs y sticks modernos) |
| **`https://spoo.me/bitly-tv32`** | armeabi-v7a (Fire TV Stick viejo, 32 bits) |
| **`https://spoo.me/bitly-tvx64`** | x86_64 (emulador / boxes Intel) |

> Apuntan a `releases/latest/download/...`, así que **sirven para todas las
> versiones futuras** sin volver a generarlas. Si querés igual el número de 5
> dígitos, entrá a **https://go.aftvnews.com/**, pegá la URL del APK y resolvé
> el captcha **una sola vez** (queda fijo para siempre).

### 3.3 Alternativa sin ningún acortador

- **Tu web**: publicar un enlace `/tv` que redirija al último APK; el usuario
  escribe `bitly-site.pages.dev/tv` en Downloader.
- **URL directa**: pegar la URL completa de GitHub de la sección 2.

---

## 4. Alternativa para desarrolladores: `adb`

Con la TV en la misma red y depuración por red activada:

```bash
adb connect 192.168.1.50:5555
adb install -r dist/app-arm64-v8a-release.apk
```

En el emulador de TV de Android Studio (x86_64) se usa
`app-x86_64-release.apk`.

---

## 5. Qué ya trae el repo para TV (verificado)

| Pieza | Dónde | Qué hace |
|---|---|---|
| `android.hardware.touchscreen` = `false` | `AndroidManifest.xml` | La TV no tiene pantalla táctil: sin esto la tienda filtraría la app |
| `android.software.leanback` = `false` | `AndroidManifest.xml` | Declara que la app corre en TV (la declara opcional, así también entra en el celular) |
| `LEANBACK_LAUNCHER` | `AndroidManifest.xml` | Hace que Bitly **aparezca en el menú de la TV** |
| `banner_tv.png` (320×180) | `res/drawable-xhdpi/` | El "póster" que la TV muestra en su fila de apps |
| Detección de TV | `lib/shared/utilidades/deteccion_tv.dart` + `MainActivity.kt` | Pregunta al sistema (`uiMode` + `leanback`) y usa el **layout de escritorio en TV** |
| Layout | `lib/shared/utilidades/deteccion_plataforma.dart` | TV entra por `usarLayoutEscritorio` → ve el mismo diseño que PC |

El mismo APK sirve para **celular y TV**: es la app la que detecta dónde corre
y cambia de diseño.

---

## 6. Estado del control remoto (honesto)

Esto es lo que **funciona hoy** con el control y lo que **todavía no**:

| Zona | Estado con el control remoto |
|---|---|
| Barra lateral de navegación | ✅ Funciona (sus botones son `InkWell`, o sea enfocables) |
| Tarjetas de **canción** (feed, búsqueda) | ✅ Funcionan |
| Barra de búsqueda | ✅ Funciona (abre el teclado en pantalla de la TV) |
| Modal de descarga, ajustes, tutorial | ✅ Funcionan (botones estándar) |
| Tarjetas de **álbum / playlist** (grillas del feed y de Mi Espacio) | ⚠️ **Aún no**: usan `GestureDetector`, que **no recibe foco** del control remoto |
| Chips de tipo de búsqueda, burbujas de ajustes | ⚠️ Aún no, por lo mismo |

**Qué falta**: cambiar `GestureDetector` por `InkWell` (o envolver con
`Focus`/`Actions`) en las tarjetas de grilla y los chips. Es el paso que de
verdad deja la app "100% manejable con el control". Mientras eso no esté, la
TV se puede *usar* (reproducir canciones, buscar), pero navegar las grillas
con el control todavía no.

---

## 7. Resumen para el usuario final (texto para la web)

> **Bitly en tu TV**
> 1. Instala **Downloader** desde la tienda de tu TV.
> 2. Ábrela y escribe **`spoo.me/bitly-tv`** (o el código corto que te demos).
> 3. Espera la descarga y toca **Instalar**.
> 4. Abre **Bitly** y listo.
>
> *(Solo para Android TV, Google TV y Fire TV. En Samsung o LG, conectá un
> Fire TV Stick o un Chromecast por HDMI.)*
