# Repositorios de música lossless con artista real

Investigación medida contra las APIs reales (2026-09-13). Todos los números de
esta nota salieron de peticiones reales, no de documentación ni de estimaciones.

## El problema que resuelve esta nota

Audius se probó como fuente descentralizada y **no sirve para "artista real"**:
su búsqueda devuelve el *uploader*, así que buscar `bad bunny` devuelve
`Olazaran`, `JPN`, `Crypto Ravers` (remixes de la canción, no la grabación).
Sirve como descubrimiento, no como catálogo identificable.

Lo que sí trae artista real son los repositorios con metadata estructurada
(compositor / intérprete / fecha) y archivos lossless verificables.

## Fuentes verificadas

| Fuente | Tamaño | Artista real | Lossless | Range | Cuenta |
|---|---|---|---|---|---|
| **Openverse** (índice) | **5.191.141** audio | ✅ `creator` | índice: sí | n/a (índice) | ❌ (20/min, 200/día anon) |
| ↳ `wikimedia_audio` | **3.954.986** | ✅ compositor/intérprete | ✅ FLAC/OGG | ✅ | ❌ |
| ↳ `jamendo` | **644.708** | ✅ `artist_name` | ✅ **FLAC real** | ✅ | ❌ (client_id gratis) |
| ↳ `freesound` | 591.447 | ✅ uploader | ⚠️ solo preview | ✅ | ❌ (muestras, no canciones) |
| **Internet Archive** `audio_music` | 363.368 Flac | ✅ `creator` | ✅ | ✅ | ❌ |
| **Internet Archive** `etree` (conciertos) | **265.593** Flac | ✅ artista+fecha+recinto | ✅ | ✅ | ❌ |
| **Internet Archive** `78rpm` (dominio público) | 217.958 Flac | ✅ `creator` | ✅ | ✅ | ❌ |
| **Internet Archive** `netlabels` (CC) | 15.950 Flac | ✅ `creator` | ✅ | ✅ | ❌ |
| **ccMixter** | API viva | ✅ uploader | ✅ FLAC en `files` | ✅ | ❌ |

### Openverse: un índice sobre 5,19 M de audios CC

`GET https://api.openverse.org/v1/audio/` — sin clave, con filtros
`q`, `extension` (flac/ogg/mp3), `license`, `source`, `duration`, paginado.
`GET /v1/audio/stats/` publica los totales por fuente (los de la tabla).
Respuesta por ítem: `title`, `creator`, `creator_url`, `duration` (**ms**),
`url` (audio), `filetype`, `filesize`, `bit_rate`, `license`, `provider`,
`foreign_landing_url`, `thumbnail`, `tags`.

Límites reales medidos en cabeceras: `anon_burst 20/min`,
`anon_sustained 200/día`. Es un **índice**, no un CDN: por eso se usa para
descubrir y se cachea fuerte, o se pega directo a la API de cada fuente.

### Jamendo: FLAC real, verificado byte a byte

Openverse devuelve las pistas de Jamendo con la URL de almacenamiento:

```
https://prod-1.storage.jamendo.com/?trackid=275834&format=mp32
```

Cambiando `format=mp32` por `format=flac` sobre el **mismo trackid**:

```
mp32 → HTTP 200 · Content-Type: audio/mpeg     · Content-Length: 20.201.861
flac → HTTP 200 · Content-Type: audio/x-flac   · Content-Length: 41.248.997
       primeros bytes: 66 4c 61 43  →  "fLaC"
```

El FLAC es exactamente el doble de grande que el MP3 y arranca con la firma
`fLaC`: es lossless de verdad, no un MP3 renombrado. Además responde `206
Partial Content`, así que el motor de chunks funciona tal cual.

### Wikimedia Commons: 3,95 M de archivos con Range

`https://commons.wikimedia.org/w/api.php` — sin clave. Un archivo de ejemplo:

```
GET .../Beethoven_Moonlight_1st_movement.ogg
→ HTTP 206 Partial Content
   content-type: application/ogg
   accept-ranges: bytes
   content-range: bytes 0-3/6633329
```

La metadata viene en `extmetadata`: `Artist` (enlaza al compositor/intérprete
real, p. ej. *Ludwig van Beethoven*), `LicenseShortName`, `Credit`. Hay OGG y
FLAC. Es la fuente más fuerte para clásico y dominio público.

### Internet Archive: el desglose real

`mediatype` **no** es uniforme, y esto causó un bug real en el provider:

| Consulta | Items |
|---|---|
| `format:Flac` | 1.239.197 |
| `format:Flac AND mediatype:audio` | 954.575 |
| `mediatype:etree` | 294.885 |
| `format:Flac AND (mediatype:audio OR mediatype:etree)` | **1.220.229** |
| `collection:etree AND format:Flac` | 265.593 |
| `collection:etree AND format:Flac AND mediatype:audio` | **4** |

Los conciertos del Live Music Archive se indexan como `mediatype:etree`, así
que un filtro `mediatype:audio` los deja afuera: **265.588 shows lossless** con
artista, fecha y recinto reales en su metadata (`creator`, `date`, `taper`,
`source`, `subject`). Corregido en `internal/provider/internetarchive/busqueda.go`
(constante `mediatypesAudio`).

### BitTorrent: Internet Archive ya siembra cada item

Verificado con un item real de etree (`inplainair2024-04-06`):

```
GET /download/inplainair2024-04-06/inplainair2024-04-06_archive.torrent
→ HTTP 200 · 19.051 bytes · magic d8:announce3
   announce       http://bt1.archive.org:6969/announce
   announce-list  bt1.archive.org:6969 · bt2.archive.org:6969   (ambos con TCP OK)
   web seeds      https://archive.org/download/
                  http://ia601608.us.archive.org/28/items/       (nodo de almacenamiento)
   archivos       45, con los FLAC ORIGINALES
                  inplainair2024-04-06_01.flac  19.222.975
                  inplainair2024-04-06_01.mp3    4.100.763
```

O sea: **el repositorio de torrents con FLAC ya está integrado** y es el mismo
catálogo que el provider de Internet Archive. Dos detalles que lo hacen usable:

1. Es un **torrent híbrido**: lleva `url-list` (web seeds) apuntando a IA y a su
   nodo, así que las piezas se pueden pedir por HTTP aunque no haya ni un peer.
2. Los hashes por pieza dan **verificación de integridad gratis** — hoy el
   download no puede comprobar que el FLAC bajó entero.

Cómo encaja en la arquitectura sin pelear con el motor:

| Uso | Transporte | Por qué |
|---|---|---|
| **Streaming** | HTTP `Range` (lo de hoy) | un torrent no sirve el segundo 1: hay que juntar piezas primero, y eso empeora el TTFF |
| **Descarga offline** | BitTorrent | secuencial, multi-nodo, verificado por pieza y sin el throttling por IP que archive.org aplica a las ráfagas |

## Fuentes descartadas (y por qué)

| Fuente | Motivo medido |
|---|---|
| **Funkwhale** (`open.audio`) | `GET /api/v1/` responde **401** y `/api/v1/tracks/` **404**: no hay catálogo federado legible sin cuenta. |
| **Free Music Archive** | `freemusicarchive.org/api/get/...` → **404**. API retirada; su catálogo sobrevive indexado en Openverse. |
| **Bandcamp** | `api/fuzzysearch/1/autocomplete` → `{"error":true,"error_message":"bad function"}`. Sin API pública viva. |
| **Musopen** | `api.musopen.org/v1/albums`, `/api/albums` → **404** en todos los caminos probados. |
| **Freesound** | Devuelve **previews** (`...-hq.mp3`), no el original; y es un banco de muestras, no de canciones. |
| **Audius** | ✅ stream real con Range, ✅ 294 k items — pero **artista = uploader**. Solo descubrimiento. |
| **Trackers privados de música** | Invitación + ratio (no automatizable a escala de app) y sin ISRC ni duración en el nombre: rompen justo el matching autoritativo/re-subido que ya está medido. Descartados como fuente de datos. |
| **Buscadores DHT** (BTDigg, SolidTorrents…) | Resultados tipo `Artista - Álbum (FLAC)` sin metadata verificable, sin `Range` y con ejecutables sueltos: no hay forma de confirmar la grabación ni de streamear. |

## Conclusión de arquitectura

El catálogo libre se arma en **dos capas separadas**, y mezclarlas es lo que
rompe la experiencia:

1. **Descubrimiento** (qué existe, con artista real): Openverse + las APIs
   directas de Jamendo y Commons + Internet Archive. Devuelven artista,
   álbum/grupo, duración y licencia → entran como entradas de primera clase.
2. **Audio** (de dónde baja el bit): se resuelve **por fuente de origen**
   (Jamendo a `format=flac`, Wikimedia a su upload URL, IA al nodo directo
   `d1/d2 + dir`). Todas responden `Range`, así que el mismo motor de chunks y
   readahead sirve para las tres.

Regla que se desprende de las mediciones: **no pedirle a ninguna de estas
fuentes que rescate una canción comercial**. Ya está medido con Internet
Archive (15 de 16 candidatos eran karaoke/cover, 0 limpios y en rango). Sirven
como catálogo propio —clásico, conciertos, 78rpm, netlabels, CC— y ahí sí
entregan FLAC con artista real y sin ninguna cuenta.

---

## ISRC: de dónde sale gratis y sin cuenta

Medido contra las APIs reales (2026-09-14). El ISRC es la llave del matching
**autoritativo** (ver `matching_isrc_autoridad.go`), así que la pregunta era si
se puede obtener sin cuenta en los catálogos de pago.

| Catálogo | ISRC sin cuenta | Endpoint | Evidencia |
|---|---|---|---|
| **Deezer** | ✅ | `api.deezer.com/track/<id>` | `"isrc":"GBDUW0000059"` |
| **Qobuz** | ✅ | `.../track/search?app_id=735532640` | `"isrc":"GBDUW0000053"` |
| **Tidal** | ✅ | `/v1/search/tracks` + `/v1/tracks/<id>` | `"isrc":"GBDUW0000053"` |
| **Apple** | ❌ | `itunes.apple.com/search` | devuelve `trackName`, **sin ISRC** |

Qobuz y Tidal devolvieron el MISMO ISRC para el mismo tema (`GBDUW0000053`,
*One More Time*): los catálogos se pueden **cruzar** para validar el ISRC antes
de usarlo como llave. Apple queda afuera de la capa de identidad.

Consecuencia de arquitectura: **el ISRC viene de la capa de metadata (gratis) y
el audio de la capa libre.** Ningún catálogo de pago necesita credenciales para
aportar su ISRC.

## Regla: qué se conserva y qué no

- **Lo que exige pago o datos personales NO se usa como fuente de audio** (ARL
de Deezer, token de Tidal, cuenta de Qobuz).
- **Las extensiones de pago NO se borran.** Se conservan como **autoridad de
  ISRC y metadata**: su `isrc` viene del sello y `matching_isrc_autoridad.go` ya
  las marca como autoritativas. Aportan identidad, no bits.
- **Soulseek** es la única fuente de catálogo comercial **sin invitación** cuyo
  registro es del lado del cliente (`slskd`: usuario y contraseña propios, sin
  mail ni captcha — *"Enter the account and password you want directly. There's
  no website needed"*). Único candidato real a "cuenta interna autocreada".
  **No medido aún.**

Esto es consistente con lo ya descartado arriba: los trackers privados siguen
fuera por invitación + ratio + falta de ISRC en el nombre.
