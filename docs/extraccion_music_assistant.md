# Extracción de Music Assistant (`github.com/music-assistant`)

Investigación del ecosistema Music Assistant (MA) para ver qué se puede extraer
hacia Bitly. Fecha: 2026-09. Verificado contra la API de GitHub y la
documentación oficial.

## Qué es MA

Servidor de biblioteca musical (Python asíncrono, Home Assistant-friendly) que
conecta servicios de streaming y parlantes. Repo principal:
`music-assistant/server` (**Apache-2.0**, 44 repos en la organización).

Su valor para nosotros **no es el código de audio** (ver *Política de uso*,
abajo) sino **la arquitectura de providers y la capa de metadatos**.

## El modelo de providers (lo importante)

Cuatro categorías, cada una un directorio con `__init__.py` + `manifest.json`
(metadata + esquema de configuración):

| Categoría | Qué aporta | Ejemplos verificados |
|---|---|---|
| **music** | fuentes de audio | `deezer`, `apple_music`, `bandcamp`, `qobuz`(z), `soundcloud`(z), `spotify`(z), `tidal`(z), `filesystem_local/nfs/smb/onedrive/google_drive/cloud`, `audiobookshelf`, `emby`, `plex`(z), `audible`, `bbc_sounds`, `ard_audiothek`, `abc_radio_network`, `digitally_incorporated`, `gpodder` |
| **metadata** | arte, letras, IDs | `acoustid_lookup`, `coverartarchive`, `fanarttv`, `genius_lyrics` |
| **player** | parlantes | `airplay`, `chromecast`, `dlna`, `snapcast`(z), `sonos`(z), `slimproto`, `squeezelite`, `bluesound`, `bose_soundtouch`, `amplipi`, `alexa`, `roku`(z), `hass` |
| **plugin** | extras | `_demo_plugin_provider`, `fastmcp_server`, `ai_radio`, `ambient_sounds`, `fully_kiosk` |

Y `_demo_music_provider` / `_demo_player_provider` / `_demo_plugin_provider`:
**plantillas anotadas** para escribir un provider nuevo.

### `provider_mappings` (la idea más valiosa)

Cada `MediaItem` lleva sus mappings por proveedor:

- `item_id` — id del ítem en ese proveedor
- `provider_domain` — `spotify`, `tidal`, `apple_music`...
- `provider_instance` — para tener dos instancias del mismo proveedor
- `quality` — la calidad disponible ahí

Con eso MA **une la misma canción/álbum presente en varias fuentes** y elige la
mejor calidad al reproducir. Además distingue ítem de proveedor (`provider ==
instance_id`) de ítem de biblioteca (`provider == "library"`, id = id de la
base), y resuelve con
`music.<tipo>.get_library_item_by_prov_id(item_id, provider)`.

**Bitly ya tiene el 80% de esto** en `provider.TrackResult` con los IDs
cruzados (`SpotifyID`, `DeezerID`, `TidalID`, `QobuzID`). Lo que MA agrega es
(a) la calidad por mapping y (b) el concepto de instancia.

## Lo que Bitly ya tiene

- Provider **`musicbrainz`** completo (`go_backend/internal/provider/musicbrainz/`):
  búsqueda, álbumes, artistas, ISRC y **Cover Art Archive** (`front-250.jpg`),
  con rate limit de 1 req/s como pide MB.
- IDs cruzados en `TrackResult`.
- Enriquecimiento en `internal/rescue/enrich.go` (usa MB primero).
- Extensions con `manifest.json` (mismo patrón que MA).

## Lo que NO tiene (y vale la pena)

| Falta | Lo da MA con | Por qué sirve |
|---|---|---|
| **AcoustID** (fingerprint → MBID) | `acoustid_lookup` | Es la única vía para identificar audio sin metadata. Medido: los archivos de Internet Archive traen `urn:acoustid:` en el **100%** de los casos, contra 4,6% de `mb_recording_id`. |
| **Fanart.tv** | `fanarttv` | Fondos/logos de artista. Hoy solo hay portada de álbum (MB). |
| **Letras por API** | `genius_lyrics` | Complementa las letras que ya se muestran. |
| **Radio por internet** | (familia de providers de radio: `abc_radio_network`, `bbc_sounds`, `ard_audiothek`) | Contenido gratis y legal, sin cuentas. Categoría entera que Bitly no tiene. |
| **Bandcamp** | `bandcamp` | Catálogo de artistas que autorizan streaming. |
| **Biblioteca local / servidores** | `filesystem_*`, `plex`, `emby`, `audiobookshelf` | Importar lo que el usuario ya tiene. |

## ⚠️ Política de uso de MA (importante para no copiar de más)

El `AGENTS.md` de MA fija una política explícita: MA **solo streamea a los
parlantes del usuario** y **no acepta cambios que permitan descargar o
conservar copias**. En revisión se rechaza cualquier cambio que:

- exponga la URL del audio del servicio fuera del servidor,
- decodifique audio protegido más allá de lo que la cuenta del usuario permite,
- permita descargar/exportar/archivar el audio, "sin importar cómo se
  presente",
- saltee el tier de suscripción, la disponibilidad regional o el límite de
  streams concurrentes.

Y aclara que los guardas que hoy existen (el *readrate pacing* de los endpoints
de stream y la restricción de análisis de audio a solo filesystem) **están ahí
por eso**: si los copiáramos sin saberlo, romperían la razón de ser de Bitly.

**Conclusión: de MA se extraen ideas y capas de metadata, nunca el pipeline de
audio.** Apache-2.0 permite reusar código con atribución, pero su código de
streaming viene con guardas que contradicen a Bitly.

## Orden sugerido de extracción

1. **AcoustID lookup** como provider de metadata (lo que más desbloquea: es el
   puente para identificar audio sin ISRC, no la solución de ISRC).
2. **Fanart.tv** para fondos de artista.
3. **Radio por internet** como categoría propia (contenido libre, sin cuentas).
4. **Bandcamp** como fuente adicional.
5. **Calidad por mapping** en `TrackResult` (la única mejora de arquitectura
   que vale la pena adoptar de `provider_mappings`).

## ¿MA ya resuelve el catálogo unificado? (verificado en el código)

Leído `music_assistant/controllers/music/controller.py` (3.625 líneas).

**Sí trae:**

- **Un solo punto de entrada**: `search(search_query, media_types,
  limit=25)` (línea 449) devuelve `SearchResults` con una lista por tipo
  (`artists`, `albums`, `tracks`, `playlists`, `radio`, `audiobooks`,
  `podcasts`, `genres`), agregando la biblioteca local + TODOS los providers en
  paralelo.
- **Filtro por tipo** en la misma llamada.
- **Caché de búsqueda** por clave `query-tipos-limit` (línea 502).
- **Salteo de repetidos**: `_get_covered_media_types` (línea 2792) devuelve los
  pares `(media_type, provider)` que la biblioteca ya cubre con una coincidencia
  de nombre casi exacta, y esos combos **no se vuelven a consultar**.
- **`provider_mappings`** + reconciliación: la misma grabación en varias fuentes
  se une a nivel de **biblioteca** y se reproduce la mejor calidad.

**No trae (y es lo que queremos):**

- **Scroll infinito**: la búsqueda solo acepta `limit` por tipo. El único cursor
  del archivo (línea 213) es para el *walk de reconciliación* de la biblioteca,
  no para paginar resultados. `browse` es un árbol por provider, no un feed
  mezclado y paginado.
- **Un ítem con N IDs**: en vez de fusionar las copias en una sola tarjeta con
  todos los mappings, **saltea** el provider ya cubierto. Bitly necesita lo
  contrario: una entrada con `SpotifyID`/`DeezerID`/`TidalID`/`QobuzID` para
  elegir la mejor calidad al vuelo.
- **Agregación sin estado**: MA exige una **base SQLite + sync/escaneo** de cada
  provider. Bitly es bajo demanda; adoptar el modelo de MA sería un cambio de
  arquitectura grande y contrario a su naturaleza.
- **Descarga/offline** y **cadena de rescate** por reproducción: MA no las tiene
  (su política las prohíbe).

**Veredicto:** MA resuelve ~la mitad (punto de entrada único, modelo
normalizado, filtro por tipo, linking en biblioteca, mejor calidad). La otra
mitad —scroll infinito, ítem fusionado con N IDs, agregación viva sin DB, y
rescate— **hay que construirla**, y encaja sobre lo que Bitly ya tiene
(`internal/search/`): su `Engine` ya agrega providers y ya tiene `ranker` y
`Deduper`. Falta: (a) **fusionar** en vez de descartar, (b) **cursor**,
(c) **filtros**, (d) adapters de las fuentes libres.

## Otros proyectos del ecosistema

- **`tkem/mopidy-internetarchive`** (Apache-2.0) — backend de Mopidy para
  Internet Archive. Ideas reutilizables.
- **RelistenNet** (AGPLv3 ⚠️ copyleft) — LMA/etree + phish.in. Modelo
  artista → año → show → tracks.
- **`internetarchive/internetarchive`** (`ia` CLI) — cliente oficial de IA.

## Referencias

- Arquitectura y política: `music-assistant/server` → `AGENTS.md`, `DEVELOPMENT.md`
- Providers: `music_assistant/providers/<nombre>/` + `manifest.json`
- Plantillas: `_demo_music_provider`, `_demo_player_provider`, `_demo_plugin_provider`
- Docs: https://music-assistant.io/music-providers/
