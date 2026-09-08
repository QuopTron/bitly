package provider

import (
	"fmt"
	"strings"
)

func (p *ExtensionProvider) GetTrack(id string) (*TrackResult, error) {
	result, err := p.call("getTrack", id)
	if err != nil {
		return nil, fmt.Errorf("ext %s getTrack: %w", p.extID, err)
	}
	if result == nil {
		return nil, nil
	}
	return convertirATrackResult(result, p.name)
}

// GetTrackByISRC resolves an ISRC via the extension.
func (p *ExtensionProvider) GetTrackByISRC(isrc string) (*TrackResult, error) {
	trackID, _ := p.llamarMetodoString("resolveTrackIDFromISRC", isrc)
	if trackID != "" {
		return p.GetTrack(trackID)
	}
	return p.buscarPorISRC(isrc)
}

// GetAlbum calls the extension's getAlbum(id).
func (p *ExtensionProvider) GetAlbum(id string) (*AlbumResult, error) {
	result, err := p.call("getAlbum", id)
	if err != nil {
		return nil, fmt.Errorf("ext %s getAlbum: %w", p.extID, err)
	}
	if result == nil {
		return nil, nil
	}
	return convertirAAlbumResult(result, p.name)
}

// GetArtist calls the extension's getArtist(id).
func (p *ExtensionProvider) GetArtist(id string) (*ArtistResult, error) {
	result, err := p.call("getArtist", id)
	if err != nil {
		return nil, fmt.Errorf("ext %s getArtist: %w", p.extID, err)
	}
	if result == nil {
		return nil, nil
	}
	return convertirAArtistResult(result, p.name)
}

// GetStreamURL calls the extension's getDownloadUrl(id, quality) for stream URL.
func (p *ExtensionProvider) GetStreamURL(id, quality string) (string, error) {
	result, err := p.call("getDownloadUrl", id, quality)
	if err != nil {
		return "", fmt.Errorf("ext %s getDownloadUrl: %w", p.extID, err)
	}
	if result == nil {
		return "", fmt.Errorf("ext %s: stream not available", p.extID)
	}
	if s, ok := result.(string); ok && s != "" {
		return s, nil
	}
	return "", fmt.Errorf("ext %s: getDownloadUrl returned no URL", p.extID)
}

// GetVisualizerURL resolves a VIDEO-capable stream URL (itag=18, video+audio)
// for [id] via the extension's getDownloadUrl(id, quality, forceVideo=true).
// This powers el visualizer layer (muted frames over el cover), which necesita// actual video frames — the audio-only formats getDownloadUrl normally picks
// would render nothing. Returns an error when the extension cannot serve a
// video format so the caller can fall back to the native youtube provider.
func (p *ExtensionProvider) GetVisualizerURL(id, quality string) (string, error) {
	result, err := p.call("getDownloadUrl", id, quality, true)
	if err != nil {
		return "", fmt.Errorf("ext %s getVisualizerUrl: %w", p.extID, err)
	}
	if result == nil {
		return "", fmt.Errorf("ext %s: visualizer not available", p.extID)
	}
	if s, ok := result.(string); ok && s != "" {
		return s, nil
	}
	return "", fmt.Errorf("ext %s: getDownloadUrl returned no video URL", p.extID)
}

// ResolveVisualizerVideoID encuentra el id de un video musical de YouTube para
// una cancion via el helper resolveVisualizerVideoID(query, artist) de la
// extension. Devuelve "" si la extension no tiene ese helper o no hubo match.
func (p *ExtensionProvider) ResolveVisualizerVideoID(query, artist string) string {
	result, err := p.call("resolveVisualizerVideoID", query, artist)
	if err != nil || result == nil {
		return ""
	}
	if s, ok := result.(string); ok {
		return strings.TrimSpace(s)
	}
	return ""
}

// HomeFeedSection represents a section from a JS extension's getHomeFeed().
