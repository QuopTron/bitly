package handlers

import (
	downloadCore "github.com/zarz/bitly/go_backend_bitly/internal/download/core"
	"github.com/zarz/bitly/go_backend_bitly/internal/quota"
	"github.com/zarz/bitly/go_backend_bitly/internal/server/rpc"
	"github.com/zarz/bitly/go_backend_bitly/internal/sources/availability"
	"github.com/zarz/bitly/go_backend_bitly/internal/sources/core"
	"github.com/zarz/bitly/go_backend_bitly/internal/sources/providers"
	"github.com/zarz/bitly/go_backend_bitly/internal/storage/database"
)

var (
	globalOrchestrator *downloadCore.DownloadOrchestrator
	globalWorkerPool   *downloadCore.WorkerPool
)

func initDownloadServices() {
	if globalOrchestrator != nil {
		return
	}
	registry := core.NewProviderRegistry()
	providers.RegisterAllBuiltin(registry)
	selector := core.NewSourceSelector(registry, []string{"deezer", "tidal", "qobuz"})
	selector.SetAvailabilityChecker(&availCheckerAdapter{})
	selector.SetISRCResolver(&isrcResolverAdapter{})
	fallback := core.NewFallbackManager(registry, []string{"deezer", "tidal", "qobuz"})
	queue := downloadCore.NewDownloadQueue()
	db, err := database.Get()
	if err != nil {
		return
	}
	qStorage := quota.NewQuotaStorage(db)
	qTracker := quota.NewQuotaTracker(qStorage)
	globalOrchestrator = downloadCore.NewDownloadOrchestrator(qTracker, queue, selector, fallback)
	globalWorkerPool = downloadCore.NewWorkerPool(3, queue, "", "")
	globalWorkerPool.Start()
}

type downloadRequestJSON struct {
	UserID     string `json:"user_id"`
	TrackID    string `json:"track_id"`
	TrackTitle string `json:"track_title"`
	ArtistName string `json:"artist_name"`
	AlbumName  string `json:"album_name"`
	ISRC       string `json:"isrc"`
	DurationMs int64  `json:"duration_ms"`
	Quality    string `json:"quality"`
	Type       string `json:"type"`
}

type availCheckerAdapter struct{}

func (a *availCheckerAdapter) CheckTrackAvailability(spotifyID, isrc string) (interface{}, error) {
	client := availability.NewClient()
	result, err := client.CheckTrackAvailability(spotifyID, isrc)
	if err != nil || result == nil {
		return nil, err
	}
	return map[string]interface{}{
		"deezer": result.Deezer, "tidal": result.Tidal, "qobuz": result.Qobuz,
		"deezer_id": result.DeezerID, "tidal_id": result.TidalID, "qobuz_id": result.QobuzID,
	}, nil
}

type isrcResolverAdapter struct{}

func (a *isrcResolverAdapter) ResolveByISRC(isrc string) (interface{}, error) {
	resolver := availability.GetLinkResolver()
	result, err := resolver.ResolveByISRC(isrc)
	if err != nil || result == nil {
		return nil, err
	}
	return map[string]interface{}{
		"deezer_url": result.DeezerURL,
		"tidal_url":  result.TidalURL,
		"qobuz_url":  result.QobuzURL,
	}, nil
}

func RegisterDownloadHandlers(reg *rpc.Registry) {
	registerDownloadStrategy(reg)
	registerDownloadProgress(reg)
	registerDownloadHistory(reg)
	registerDownloadMisc(reg)
}
