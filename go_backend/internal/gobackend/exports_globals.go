package gobackend

import (
	"github.com/zarz/bitly/go_backend/internal/bin"
	"github.com/zarz/bitly/go_backend/internal/bundled_extensions"
	"github.com/zarz/bitly/go_backend/internal/download"
	"github.com/zarz/bitly/go_backend/internal/extensions"
	"github.com/zarz/bitly/go_backend/internal/library"
	"github.com/zarz/bitly/go_backend/internal/lyrics"
	"github.com/zarz/bitly/go_backend/internal/playback"
	"github.com/zarz/bitly/go_backend/internal/premium"
	"github.com/zarz/bitly/go_backend/internal/provider"
	"github.com/zarz/bitly/go_backend/internal/recommend"
	"github.com/zarz/bitly/go_backend/internal/rescue"
	"github.com/zarz/bitly/go_backend/internal/scrobble"
	"github.com/zarz/bitly/go_backend/internal/search"
)

// =========================================================================
// GLOBALES DEL PUENTE
// =========================================================================

// Instancias globales inicializadas en InitGlobalState. Se guardan a nivel de
// paquete porque cada función exportada del puente (una llamada directa desde
// Flutter) las necesita sin pasar por una estructura compartida.
var (
	// reg es el registro central de proveedores de música (extensiones + nativos).
	reg *provider.Registry

	// searchEngine agrega resultados de búsqueda de todos los proveedores.
	searchEngine *search.Engine

	// downloadOrch orquesta descargas (mp3/flac/video/letras) por track.
	downloadOrch *download.Orchestrator

	// rescueSvc rescata URLs de streaming caídas probando fuentes alternas.
	rescueSvc *rescue.Rescuer

	// enricher completa metadata de tracks encontrados por rescue.
	enricher *rescue.Enricher

	// recommendEng genera recomendaciones a partir del historial de likes.
	recommendEng *recommend.Engine

	// lyricsClient busca letras (lrclib/genius/extensiones).
	lyricsClient *lyrics.Client

	// scrobbleClient reporta escuchas (last.fm, etc.).
	scrobbleClient *scrobble.Client

	// extRegistry registra y ejecuta extensiones JS (Spotify-web, etc.).
	extRegistry *extensions.Registry

	// lib es la biblioteca local (tracks descargados, likes, playlists).
	lib *library.Library

	// binMgr gestiona binarios descargados (yt-dlp, ffmpeg).
	binMgr *bin.Manager

	// ytdlpPath es la ruta resuelta del binario yt-dlp.
	ytdlpPath string

	// streamer arranca el servidor HTTP de streaming local para Flutter.
	streamer interface {
		StartServer(int) (string, error)
		StopServer() error
		StreamChunk(string, int64, int64) ([]byte, error)
	}

	// playbackTracker registra la reproducción actual (scrobble/premium).
	playbackTracker *playback.Tracker

	// premiumChecker valida el estado premium local.
	premiumChecker *premium.Checker

	// sessionMgr gestiona sesiones firmadas de extensiones (cookies/oauth).
	sessionMgr *extensions.SessionManager

	// sessionConfigs guarda la configuración firmada por extensión.
	sessionConfigs map[string]*extensions.SignedSessionConfig

	// flutterCallbackID es el id del callback que Flutter registró.
	flutterCallbackID string

	// bundledExts son las extensiones embebidas (-web) cargadas al iniciar.
	bundledExts []bundled_extensions.RegisteredExtension

	// staging escribe descargas atómicamente vía archivos .partial.
	staging *download.StagingManager

	// cancelReg registra contextos para cancelar descargas en curso.
	cancelReg *download.CancelRegistry

	// downloadDir es el directorio de descargas configurado desde Flutter.
	downloadDir string

	// userMode es el modo de usuario ("free", "premium", etc.) desde Flutter.
	userMode string

	// streamCacheMaxMB es el tope del caché de streaming en MB.
	streamCacheMaxMB int

	// extSettings guarda la configuración por extensión enviada desde Flutter.
	extSettings map[string]map[string]string
)
