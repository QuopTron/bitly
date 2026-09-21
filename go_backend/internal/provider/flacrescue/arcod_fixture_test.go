// ─────────────────────────────────────────────────────────────
// arcod_fixture_test.go — Respuestas RECORTADAS de la API de arcod.xyz,
// capturadas en vivo, para los tests del canal de stream (ver arcod_test.go).
//
// Guardarlas acá mantiene cada archivo por debajo del tope de líneas y deja
// los datos en un solo lugar.
// ─────────────────────────────────────────────────────────────

package flacrescue

// jsonCatalogoArcod es un recorte REAL de /api/get-music: la canción pedida y
// el ruido que devuelve su búsqueda (buscando "NUEVAYoL" aparecen diez pistas
// con ese título y solo una es de Bad Bunny). Los cuatro datos que no son
// obvios están tal cual llegan:
//
//	· el artista de una pista viene en `performer` (no en `artist`),
//	· el ISRC viaja en la pista (y su catálogo SÍ se puede buscar por él),
//	· los permisos son streamable/downloadable/displayable,
//	· el cuarto resultado es un caso REAL de pista no descargable.
const jsonCatalogoArcod = `{
  "success": true,
  "data": {
    "query": "QMFMF2447055",
    "tracks": {
      "total": 4,
      "offset": 0,
      "limit": 10,
      "items": [
        {
          "id": 312055179,
          "isrc": "QMFMF2447055",
          "title": "NUEVAYoL",
          "duration": 183,
          "maximum_bit_depth": 24,
          "maximum_sampling_rate": 96,
          "audio_info": {"replaygain_track_peak": 0.998871, "replaygain_track_gain": -10.38},
          "streamable": true,
          "downloadable": true,
          "displayable": true,
          "performer": {"name": "Bad Bunny", "id": 2739838},
          "album": {
            "id": "lwyrfdrp293ub",
            "title": "DeBÍ TiRAR MáS FOToS",
            "tracks_count": 17,
            "release_date_original": "2025-01-05",
            "artist": {"name": "Bad Bunny", "id": 2739838, "albums_count": 372}
          }
        },
        {
          "id": "393153762",
          "isrc": "SE5752656567",
          "title": "NUEVAYoL",
          "duration": 170,
          "maximum_bit_depth": 16,
          "streamable": true,
          "downloadable": true,
          "displayable": true,
          "performer": {"name": "DJ MO", "id": 114004},
          "album": {"id": "gkqwc7z7utfiz", "title": "NUEVAYoL"}
        },
        {
          "id": 312055198,
          "isrc": "ITTL52560131",
          "title": "NUEVAYOL",
          "duration": 175,
          "maximum_bit_depth": 16,
          "streamable": true,
          "downloadable": false,
          "displayable": true,
          "performer": {"name": "Zero J", "id": 556677},
          "album": {"id": "hcth2kmawn4ot", "title": "AFRO VIBRATIONS"}
        }
      ]
    },
    "albums": {"total": 1, "offset": 0, "limit": 10, "items": [{"id": "lwyrfdrp293ub", "title": "DeBí TiRAR MáS FOToS"}]},
    "artists": {"total": 1, "offset": 0, "limit": 10, "items": [{"id": 2739838, "name": "Bad Bunny"}]}
  }
}`

// jsonStreamArcod es la respuesta REAL de /api/player/stream/<id>: el enlace
// firmado del FLAC (con soporte de Range) y su tipo.
const jsonStreamArcod = `{"url":"https://api.arcod.xyz/v2/stream/play?t=v1.abc","mimeType":"audio/flac","quality":6,"trackId":"312055179"}`

// jsonSinCuentasArcod es la respuesta REAL del sitio cuando su pool de tokens
// de Qobuz se queda vacío: no es un catálogo sin resultados, es el sitio
// entero caído. Se conserva el motivo porque es lo que ve el log.
const jsonSinCuentasArcod = `{"success":false,"error":"No healthy Qobuz tokens available — add or reset tokens in admin panel"}`
