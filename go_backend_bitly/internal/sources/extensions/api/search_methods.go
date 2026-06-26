package api

import (
	"encoding/json"
	"fmt"
)

func (c *ActionClient) SearchTracks(extensionID, query string, limit int) ([]SearchResult, error) {
	// IMPORTANT: Extensions define searchTracks(query, limit) with SEPARATE arguments,
	// NOT with an object param. Passing {query, limit} would make query="[object Object]".
	callResult, err := c.runtime.CallMethod(extensionID, "searchTracks", query, limit)
	if err != nil {
		return nil, err
	}
	if callResult.Value == nil {
		return nil, nil
	}

	// Try direct array
	if arr, ok := callResult.Value.([]interface{}); ok {
		return ParseSearchResultsFromArray(arr), nil
	}

	// Try wrapper with tracks key
	if wrapper, ok := callResult.Value.(map[string]interface{}); ok {
		if arr, ok := wrapper["tracks"].([]interface{}); ok {
			return ParseSearchResultsFromArray(arr), nil
		}
	}

	return nil, fmt.Errorf("SearchTracks: unexpected response format")
}

func (c *ActionClient) GetTrack(extensionID, trackID string) (*TrackMetadata, error) {
	params := map[string]interface{}{"id": trackID}
	callResult, err := c.runtime.CallMethod(extensionID, "getTrack", params)
	if err != nil {
		return nil, err
	}
	if callResult.Value == nil {
		return nil, nil
	}

	raw, err := json.Marshal(callResult.Value)
	if err != nil {
		return nil, fmt.Errorf("GetTrack marshal: %w", err)
	}

	var track TrackMetadata
	if err := json.Unmarshal(raw, &track); err != nil {
		return nil, fmt.Errorf("GetTrack parse: %w (raw: %s)", err, string(raw))
	}
	return &track, nil
}

func (c *ActionClient) GetAlbum(extensionID, albumID string) (*AlbumMetadata, error) {
	params := map[string]interface{}{"id": albumID}
	callResult, err := c.runtime.CallMethod(extensionID, "getAlbum", params)
	if err != nil {
		return nil, err
	}
	if callResult.Value == nil {
		return nil, nil
	}

	raw, err := json.Marshal(callResult.Value)
	if err != nil {
		return nil, fmt.Errorf("GetAlbum marshal: %w", err)
	}

	var album AlbumMetadata
	if err := json.Unmarshal(raw, &album); err != nil {
		return nil, fmt.Errorf("GetAlbum parse: %w (raw: %s)", err, string(raw))
	}
	return &album, nil
}

func (c *ActionClient) GetArtist(extensionID, artistID string) (*ArtistMetadata, error) {
	params := map[string]interface{}{"id": artistID}
	callResult, err := c.runtime.CallMethod(extensionID, "getArtist", params)
	if err != nil {
		return nil, err
	}
	if callResult.Value == nil {
		return nil, nil
	}

	raw, err := json.Marshal(callResult.Value)
	if err != nil {
		return nil, fmt.Errorf("GetArtist marshal: %w", err)
	}

	var artist ArtistMetadata
	if err := json.Unmarshal(raw, &artist); err != nil {
		return nil, fmt.Errorf("GetArtist parse: %w (raw: %s)", err, string(raw))
	}
	return &artist, nil
}
