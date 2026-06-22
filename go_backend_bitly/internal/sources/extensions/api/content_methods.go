package api

import (
	"encoding/json"
	"fmt"
)

func (c *ActionClient) HandleURL(extensionID, url string) (*URLHandleResult, error) {
	params := map[string]interface{}{"url": url}
	callResult, err := c.runtime.CallMethod(extensionID, "handleUrl", params)
	if err != nil {
		return nil, err
	}
	if callResult.Value == nil {
		return nil, fmt.Errorf("handleUrl returned null")
	}

	raw, err := json.Marshal(callResult.Value)
	if err != nil {
		return nil, fmt.Errorf("HandleURL marshal: %w", err)
	}

	var result URLHandleResult
	if err := json.Unmarshal(raw, &result); err != nil {
		return nil, fmt.Errorf("HandleURL parse: %w", err)
	}
	return &result, nil
}

func (c *ActionClient) GetLyrics(extensionID, trackName, artistName string, durationMs int64) (*LyricsResult, error) {
	params := map[string]interface{}{
		"track_name":  trackName,
		"artist_name": artistName,
		"duration_ms": durationMs,
	}
	callResult, err := c.runtime.CallMethod(extensionID, "getLyrics", params)
	if err != nil {
		return nil, err
	}
	if callResult.Value == nil {
		return nil, nil
	}

	raw, err := json.Marshal(callResult.Value)
	if err != nil {
		return nil, fmt.Errorf("GetLyrics marshal: %w", err)
	}

	var result LyricsResult
	if err := json.Unmarshal(raw, &result); err != nil {
		return nil, fmt.Errorf("GetLyrics parse: %w", err)
	}
	return &result, nil
}

func (c *ActionClient) EnrichTrack(extensionID string, track *TrackMetadata) (*TrackMetadata, error) {
	callResult, err := c.runtime.CallMethod(extensionID, "enrichTrack", track)
	if err != nil {
		return track, nil
	}
	if callResult.Value == nil {
		return track, nil
	}

	raw, err := json.Marshal(callResult.Value)
	if err != nil {
		return track, nil
	}

	var enriched TrackMetadata
	if err := json.Unmarshal(raw, &enriched); err != nil {
		return track, nil
	}

	if enriched.ID == "" {
		enriched.ID = track.ID
	}
	return &enriched, nil
}
