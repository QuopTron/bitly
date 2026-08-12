package provider

import (
	"encoding/json"
	"fmt"
)

// getRawMap calls a JS method and converts the result to a map[string]interface{}.
// Raw detail fetches (getAlbum/getArtist/getPlaylist) are scoped to their own
// cooldown bucket so a rate-limited detail endpoint doesn't disable playback
// or search for the provider.
func (p *ExtensionProvider) getRawMap(method string, args ...interface{}) (map[string]interface{}, error) {
	result, err := p.callOp("detail", method, args...)
	if err != nil {
		return nil, fmt.Errorf("ext %s %s: %w", p.extID, method, err)
	}
	if result == nil {
		return nil, nil
	}
	m, ok := result.(map[string]interface{})
	if !ok {
		return nil, fmt.Errorf("ext %s %s: unexpected type %T", p.extID, method, result)
	}
	return m, nil
}

// GetAlbumRaw returns the extension's full getAlbum(id) result as a JSON string.
// Includes the track list so Flutter can render the album detail page.
func (p *ExtensionProvider) GetAlbumRaw(id string) (string, error) {
	m, err := p.getRawMap("getAlbum", id)
	if err != nil || m == nil {
		return "", err
	}
	data, _ := json.Marshal(m)
	return string(data), nil
}

// GetPlaylistRaw returns the extension's full getPlaylist(id) result as JSON.
func (p *ExtensionProvider) GetPlaylistRaw(id string) (string, error) {
	m, err := p.getRawMap("getPlaylist", id)
	if err != nil || m == nil {
		return "", err
	}
	data, _ := json.Marshal(m)
	return string(data), nil
}

// GetArtistRaw returns the extension's full getArtist(id) result as JSON.
// Includes top_tracks and albums so Flutter can render the artist page.
func (p *ExtensionProvider) GetArtistRaw(id string) (string, error) {
	m, err := p.getRawMap("getArtist", id)
	if err != nil || m == nil {
		return "", err
	}
	data, _ := json.Marshal(m)
	return string(data), nil
}
