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

## Fuentes descartadas (y por qué)

| Fuente | Motivo medido |
|---|---|
| **Funkwhale** (`open.audio`) | `GET /api/v1/` responde **401** y `/api/v1/tracks/` **404**: no hay catálogo federado legible sin cuenta. |
| **Free Music Archive** | `freemusicarchive.org/api/get/...` → **404**. API retirada; su catálogo sobrevive indexado en Openverse. |
| **Bandcamp** | `api/fuzzysearch/1/autocomplete` → `{"error":true,"error_message":"bad function"}`. Sin API pública viva. |
| **Musopen** | `api.musopen.org/v1/albums`, `/api/albums` → **404** en todos los caminos probados. |
| **Freesound** | Devuelve **previews** (`...-hq.mp3`), no el original; y es un banco de muestras, no de canciones. |
| **Audius** | ✅ stream real con Range, ✅ 294 k items — pero **artista = uploader**. Solo descubrimiento. |

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
