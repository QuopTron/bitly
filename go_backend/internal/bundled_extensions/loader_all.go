package bundled_extensions

import (
	"encoding/json"
	"os"

	"github.com/zarz/bitly/go_backend/internal/extensions"
)

// dirAlmacenExtensiones devuelve el directorio escribible donde las
// extensiones empaquetadas persisten su estado (almacén KV, sesiones firmadas).
//
// Antes estas extensiones se registraban con ".", así que su Store nacía
// apuntando al directorio de trabajo del proceso: en Android el CWD es "/", no
// escribible, y cada os.WriteFile fallaba en silencio — la extensión logueaba
// "guardado" y el arranque siguiente leía vacío. El host ya publica la ruta
// real en BITLY_DATA_DIR antes de registrar extensiones (SetAppDataDir), así
// que se usa esa y "." queda solo como último recurso (tests, escritorio sin
// data dir configurado).
func dirAlmacenExtensiones() string {
	if dir := os.Getenv("BITLY_DATA_DIR"); dir != "" {
		return dir
	}
	return "."
}

func LoadAllToRegistry(reg *extensions.Registry) []RegisteredExtension {
	dirs, err := List()
	if err != nil {
		return nil
	}

	list := make([]RegisteredExtension, 0, len(dirs))
	cfg := extensions.DefaultConfig()
	cfg.EnableFS = true
	cfg.AllowedDirs = []string{"."}

	for _, dir := range dirs {
		ext, err := Load(dir)
		if err != nil {
			continue
		}

		// Parse manifest for metadata
		var manifest struct {
			Name          string                          `json:"name"`
			DisplayName   string                          `json:"displayName"`
			Version       string                          `json:"version"`
			Type          []string                        `json:"type"`
			SignedSession *extensions.SignedSessionConfig `json:"signedSession,omitempty"`
			RequiredFeats []string                        `json:"requiredRuntimeFeatures,omitempty"`
			Capabilities  struct {
				Replaces []string `json:"replacesBuiltInProviders"`
				HomeFeed bool     `json:"homeFeed"`
			} `json:"capabilities"`
			QualityOptions []struct {
				ID       string `json:"id"`
				Label    string `json:"label"`
				Settings []struct {
					Key     string   `json:"key"`
					Label   string   `json:"label"`
					Hint    string   `json:"hint"`
					Type    string   `json:"type"`
					Default string   `json:"default"`
					Options []string `json:"options"`
				} `json:"settings"`
			} `json:"qualityOptions"`
			SearchBehavior struct {
				Enabled        bool   `json:"enabled"`
				Primary        bool   `json:"primary"`
				Placeholder    string `json:"placeholder"`
				ThumbnailRatio string `json:"thumbnailRatio"`
				Filters        []SearchFilter
			} `json:"searchBehavior"`
			// urlHandler decide qué extensión recibe cada enlace compartido
			// (Spotify/YouTube/Deezer...): la app elige por patrón de host y le
			// pide a esa extensión su handleUrl(url).
			URLHandler struct {
				Enabled  bool     `json:"enabled"`
				Patterns []string `json:"patterns"`
			} `json:"urlHandler"`
		}
		if err := json.Unmarshal(ext.ManifestData, &manifest); err != nil {
			manifest.Name = dir
			manifest.Version = "0.0.0"
		}
		if manifest.Name == "" {
			manifest.Name = dir
		}

		extType := "both"
		if len(manifest.Type) == 1 {
			extType = manifest.Type[0]
		} else if len(manifest.Type) == 0 {
			extType = "metadata"
		}

		// Un proveedor puede descarga solo si su manifest listas un descarga
		// capability (metadata_provider/lyrics_provider alone cannot).
		isDownload := false
		hasLyrics := false
		for _, t := range manifest.Type {
			switch t {
			case "download_provider":
				isDownload = true
			case "lyrics_provider":
				// Declarado en el manifest: la extensión exporta fetchLyrics.
				// Leerlo de acá evita ejecutar su JS solo para preguntárselo.
				hasLyrics = true
			}
		}
		qOpts := make([]string, 0, len(manifest.QualityOptions))
		qTiers := make([]QualityTier, 0, len(manifest.QualityOptions))
		for _, q := range manifest.QualityOptions {
			if q.ID == "" {
				continue
			}
			qOpts = append(qOpts, q.ID)
			tier := QualityTier{ID: q.ID, Label: q.Label}
			for _, s := range q.Settings {
				if s.Key == "" {
					continue
				}
				tier.Settings = append(tier.Settings, QualitySetting{
					Key: s.Key, Label: s.Label, Hint: s.Hint,
					Type: s.Type, Default: s.Default, Options: s.Options,
				})
			}
			qTiers = append(qTiers, tier)
		}

		// Registrar el JS SIN compilarlo.
		//
		// El arranque solo necesita los metadatos de arriba (manifest) para
		// armar la lista de fuentes y sus capacidades; compilar el JS de las
		// nueve extensiones empaquetadas son decenas de MB de asignaciones
		// transitorias de goja, justo mientras el sistema operativo todavía
		// está inflando la app. Cada extensión se compila la primera vez que
		// alguien la usa de verdad (o en el warm-up de fondo).
		//
		// Efecto observable: una extensión empaquetada con JS roto ya no
		// desaparece de la lista en silencio al arrancar — aparece y falla con
		// su error en el primer uso.
		reg.Runtime().RegisterDeferred(
			string(ext.IndexJSData),
			dir,
			manifest.Name,
			cfg,
			dirAlmacenExtensiones(),
		)

		// Attach signed session config from manifest to the sandbox.
		if sb := reg.Runtime().Sandbox(dir); sb != nil && manifest.SignedSession != nil {
			sb.SignedSession = manifest.SignedSession
			sb.Session = &extensions.SignedSessionState{}
		}

		list = append(list, RegisteredExtension{
			ID:                 dir,
			Name:               manifest.DisplayName,
			Version:            manifest.Version,
			Type:               extType,
			Enabled:            true,
			Replaces:           manifest.Capabilities.Replaces,
			HasHomeFeed:        manifest.Capabilities.HomeFeed,
			IsDownloadProvider: isDownload,
			HasLyricsProvider:  hasLyrics,
			QualityOptions:     qOpts,
			QualityTiers:       qTiers,
			Search: Search{
				Enabled:        manifest.SearchBehavior.Enabled,
				Primary:        manifest.SearchBehavior.Primary,
				Placeholder:    manifest.SearchBehavior.Placeholder,
				ThumbnailRatio: manifest.SearchBehavior.ThumbnailRatio,
				Filters:        manifest.SearchBehavior.Filters,
			},
			URLHandler: URLHandler{
				Enabled:  manifest.URLHandler.Enabled,
				Patterns: manifest.URLHandler.Patterns,
			},
		})
	}

	return list
}

// LoadByName loads a specific bundled extension by name into the registry.
