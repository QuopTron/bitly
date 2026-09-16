package streaming

import (
	"strings"

	"github.com/zarz/bitly/go_backend/internal/lyrics"
	"github.com/zarz/bitly/go_backend/internal/provider"
)

type StreamPackage struct {
	AudioURL string                `json:"audioUrl"`
	VideoURL string                `json:"videoUrl,omitempty"`
	Provider string                `json:"provider"`
	Quality  string                `json:"quality"`
	Track    *provider.TrackResult `json:"track"`
	Lyrics   *lyrics.Lyrics        `json:"lyrics,omitempty"`
}

// streamingProviders es la lista de proveedores que se consultan al RESOLVER
// METADATA (identidad: título, artista, ISRC, ids cross-proveedor). NO es la
// lista de fuentes de audio: ver proveedoresAudio.
//
// Acá SÍ van los catálogos (deezer, qobuz, tidal, amazon, apple, spotify),
// porque son justamente los que publican el ISRC y los ids que permiten
// confirmar que hablamos de la misma GRABACIÓN. Ese dato es el que habilita el
// rescate lossless (Internet Archive / Soulseek / flac-rescue) por identidad.
//
// Se incluye el equivalente -web de cada uno (qobuz-web, tidal-web,
// amazon-web, spotify-web) porque tras cargar las extensiones los catálogos se
// registran con ese nombre: la lista nativa sola saltaría las fuentes reales.
var streamingProviders = []string{
	"youtube", "deezer", "qobuz", "tidal", "qobuz-web", "tidal-web", "amazon",
	"ytmusic-spotiflac", "apple-music", "spotify-web", "soundcloud",
	"flac-rescue", "internetarchive", "soulseek",
}

// proveedoresAudio son las ÚNICAS fuentes de las que se acepta AUDIO.
//
// Decisión de producto (explícita): las extensiones de catálogo
// (spotify-web, qobuz-web, tidal-web, amazon, apple-music, deezer…) sirven
// para BUSCAR — aportan identidad, ISRC e ids — pero NO para streamear. Sus
// catálogos resuelven una URL solo con su sesión firmada; sin sesión fallan
// siempre, así que sondearlas en el rescate era tiempo muerto puro (medido:
// la fase exacta por ISRC gastaba 1,5-5,8s para devolver nada, y en algunos
// temas sumaba hasta 6,4s antes de que el re-subido siquiera arrancara).
//
// El audio sale de YouTube, sí o sí: ytmusic-spotiflac (yt-dlp / InnerTube) y
// youtube. Cuando la calidad pedida es sin pérdida, Internet Archive y
// flac-rescue compiten por dar el FLAC real y la política de confianza les da
// la última palabra. soundcloud va último: identifica flojo (nombre suelto) y
// es el fallback más suelto.
//
// SOULSEEK NO ESTÁ ACÁ, y es a propósito. Su GetStreamURL no existe: el
// protocolo es peer-to-peer (ConnectToPeer → QueueUpload → transferencia F),
// así que la búsqueda funciona y la reproducción directa no. Meterlo en la
// carrera no solo gastaba un turno del pool y una búsqueda P2P completa en
// cada tap: con calidad sin pérdida entraba como BLOQUEANTE (ver
// fuentesLosslessSiempre), y un resultado de YouTube/yt-dlp esperaba una
// gracia por una fuente que no puede entregar ni un byte. Su lugar es la
// DESCARGA (ver proveedoresSoloDescarga).
//
// El orden importa poco para QUIÉN gana (eso lo decide la política de
// confianza, no el orden de llegada), pero importa para CUÁNDO empieza cada
// uno: el primero de la lista reclama turno primero.
var proveedoresAudio = []string{
	"ytmusic-spotiflac", "youtube",
	"internetarchive", "flac-rescue",
	"soundcloud",
}

// proveedoresSoloDescarga pueden conseguir el audio, pero NUNCA servirlo como
// stream: su única vía es bajar el archivo (el orquestador de descargas sí los
// usa: ver orchestrator_fallback.go). Se declaran acá para que la carrera de
// streaming los ignore a propósito y no por accidente, y para que un test
// pueda pincharlo.
var proveedoresSoloDescarga = []string{"soulseek"}

// esProveedorSoloDescarga reporta si [name] solo puede aportar por descarga.
func esProveedorSoloDescarga(name string) bool {
	for _, n := range proveedoresSoloDescarga {
		if n == name {
			return true
		}
	}
	return false
}

// proveedoresExactos son las fuentes que pueden confirmar la GRABACIÓN EXACTA
// sin heurística de nombre. En el camino de streaming queda solo flac-rescue:
// su índice ES el ISRC, así que resolverlo es identidad, no parecido.
//
// Los catálogos (deezer/qobuz/tidal/amazon/apple) salieron de acá: definen el
// ISRC igual que flac-rescue, pero no entregan audio sin sesión firmada, y su
// lugar ahora es aportar identidad en la búsqueda/metadata, no competir por el
// stream. Ver proveedoresAudio.
var proveedoresExactos = []string{
	"flac-rescue",
}

// proveedoresReSubidos solo pueden identificar la canción por NOMBRE: no
// publican ISRC (lo infieren por parecido contra Deezer), así que son el ÚLTIMO
// recurso del rescate. Antes iban al principio de la carrera y, al responder más
// rápido, ganaban casi siempre — que es exactamente el "cae en un remix de
// YouTube/SoundCloud" que reportaba el usuario.
// internetarchive entra por el mismo motivo aunque NO sea un re-subido: su
// catálogo es propio (archive.org) y sus archivos son el audio real, pero su
// búsqueda identifica por nombre y no publica ISRC, así que no puede confirmar
// una grabación exacta. Tratarlo como re-subido le da la gracia corta que evita
// que un concierto con el mismo título le gane la reproducción a la grabación
// original de Deezer/Qobuz/Tidal.
var proveedoresReSubidos = []string{
	"ytmusic-spotiflac", "youtube", "soundcloud", "internetarchive", "soulseek",
}

// proveedoresLossless pueden entregar audio SIN PÉRDIDA de verdad (FLAC/ALAC
// real, no un transcodificado que se anuncia como tal).
//
// Para qué sirve la lista: cuando la calidad pedida es sin pérdida, un
// resultado de una fuente que NO está acá (yt-dlp, SoundCloud) no gana de
// inmediato — espera una gracia corta a que llegue una fuente que sí puede
// darlo. Es el caso "YouTube no tiene esa calidad y Soulseek o Internet
// Archive sí": si el match es bueno, suena el de ellos.
//
// Los catálogos (deezer/qobuz/tidal/amazon/apple) están porque con sesión
// propia sirven FLAC; sin sesión fallan solos y la gracia expira igual. La
// lista es una PREFERENCIA, nunca una puerta: equivocarse (marcar lossy como
// lossless o al revés) solo mueve unos segundos, jamás sirve una canción
// equivocada.
var proveedoresLossless = []string{
	"flac-rescue", "internetarchive", "soulseek",
	"deezer", "deezer-web", "qobuz", "qobuz-web", "tidal", "tidal-web",
	"amazon", "amazon-web", "apple-music",
}

// fuentesLosslessSiempre son las que NO dependen de una suscripción para dar
// sin pérdida Y pueden entregarla EN VIVO: su catálogo ES lossless (Internet
// Archive publica FLAC propio, flac-rescue resuelve FLAC por ISRC). Cuando la
// calidad pedida es sin pérdida y alguna de estas sigue en vuelo, es a ellas a
// las que se les da la gracia — no a un catálogo sin sesión, que va a fallar
// igual.
//
// Soulseek salió de esta lista aunque sus archivos SÍ sean FLAC: en la carrera
// de streaming no puede entregar nada (ver proveedoresSoloDescarga), así que
// darle la gracia era esperar 1,8s por un resultado imposible. Sigue en
// proveedoresLossless, que describe CAPACIDAD de audio (y habilita las
// descargas), no participación en la carrera.
var fuentesLosslessSiempre = []string{"flac-rescue", "internetarchive"}

// esProveedorLossless reporta si [name] puede entregar audio sin pérdida.
func esProveedorLossless(name string) bool {
	for _, n := range proveedoresLossless {
		if n == name {
			return true
		}
	}
	return false
}

// esFuenteLosslessSiempre reporta si [name] da sin pérdida sin suscripción.
func esFuenteLosslessSiempre(name string) bool {
	for _, n := range fuentesLosslessSiempre {
		if n == name {
			return true
		}
	}
	return false
}

// calidadPideLossless interpreta la calidad pedida por el usuario. El vocabulario
// que usa la app es ['flac', 'hifi', 'high', 'medium', 'low'] (ver
// ajustes_descarga.dart) más los nombres crudos que pasan las extensiones
// ("FLAC", "HI_RES_LOSSLESS"), así que se compara por contenido y sin
// distinguir mayúsculas.
func calidadPideLossless(quality string) bool {
	q := strings.ToLower(strings.TrimSpace(quality))
	if q == "" {
		return false
	}
	return strings.Contains(q, "flac") ||
		strings.Contains(q, "lossless") ||
		strings.Contains(q, "hifi") ||
		strings.Contains(q, "hi_res") ||
		strings.Contains(q, "hires")
}

// esProveedorReSubido reporta si [name] identifica canciones por nombre (sin
// ISRC propio) y por lo tanto debe intentarse después de las fuentes exactas.
func esProveedorReSubido(name string) bool {
	for _, n := range proveedoresReSubidos {
		if n == name {
			return true
		}
	}
	return false
}

// esProviderStreaming reporta si [name] es una fuente de AUDIO aceptada
// (proveedoresAudio). Los catálogos de búsqueda devuelven false a propósito:
// así el atajo de reproducción no pierde medio segundo sondeando una URL que
// sin sesión firmada no puede existir, y el rescate no los incluye en la
// carrera.
func esProviderStreaming(name string) bool {
	for _, p := range proveedoresAudio {
		if p == name {
			return true
		}
	}
	return false
}

// isPlayableStreamURL reports whether a resolved "stream URL" is actually
// streamable by the player. Some providers (amazon/qobuz DRM) return a local
// path to an encrypted file instead of an http stream — media_kit cannot decode
// that and would loop "Error decoding audio". Only http(s) URLs are playable.
func esURLReproducible(u string) bool {
	return strings.HasPrefix(u, "http://") || strings.HasPrefix(u, "https://")
}

// fullStreamProviders yield full-length http streams. The fast-play path should
// only be served from these; preview-prone providers (apple-music, spotify-web)
// return 30s audio clips that would cut playback short, so playback for those
// goes straight to the produced download instead.
//
// deezer/qobuz-web/tidal-web are included because their extensions now export a
// real getDownloadUrl that resolves the Zarz download descriptor and returns
// El plain http audio URL solo cuando el stream necesita sin cliente-side// decryption (Deezer lossy tiers, Qobuz direct files, TIDAL "direct" kind).
// Without a verified session they fail fast (null) and the flow falls through
// to the download pipeline, which performs any required decryption.
var fullStreamProviders = []string{
	"youtube", "ytmusic-spotiflac", "soundcloud", "deezer",
	"qobuz-web", "tidal-web", "flac-rescue",
}

// IsFullStreamProvider reports whether [name] can serve a full-length stream
// (as opposed to a 30s preview).
func IsFullStreamProvider(name string) bool {
	for _, p := range fullStreamProviders {
		if p == name {
			return true
		}
	}
	return false
}

// trimKnownPrefix strips an "<provider>:" id prefix (feed items carry ids like
// "amazon:abc" that extensions don't understand).
func quitarPrefijoConocido(id string) string {
	if i := strings.Index(id, ":"); i > 0 {
		return id[i+1:]
	}
	return id
}

// StreamQuick resolves a playable direct stream for a track using its
// cross-provider identifiers (spotify/deezer/tidal/qobuz ids + ISRC) via
// CheckAvailability instead of slow name searches — the same route the download
// orchestrator uses. When a real http stream exists it is found in ~1-2s, so
// playback can begin immediately; providers that only expose 30s previews or
// DRM files fail fast so the caller falls through to the cached, identifier-based
// download. Returns (url, provider, err).
//
// The resuelto id es NEVER trusted blindly: cuando se wasn't obtained de an// authoritative identifier (ISRC / cross-provider id), it is verified against
// el consulta title/artista so un wrong/similar canción (e.g. otro feed's id fed a// Un completo-stream proveedor) es nunca served — reproducción falls un través de en su lugar.
