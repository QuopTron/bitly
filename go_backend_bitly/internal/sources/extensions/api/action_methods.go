package api

import (
	"encoding/json"
	"fmt"
)

func (c *ActionClient) CheckAvailability(extensionID, isrc, trackName, artistName string, extraIDs map[string]string) (*AvailabilityResult, error) {
	params := map[string]interface{}{
		"isrc":       isrc,
		"track_name": trackName,
		"artist":     artistName,
	}
	for k, v := range extraIDs {
		params[k] = v
	}
	callResult, err := c.runtime.CallMethod(extensionID, "checkAvailability", params)
	if err != nil {
		return nil, err
	}
	if callResult.Value == nil {
		return &AvailabilityResult{Available: false}, nil
	}

	raw, err := json.Marshal(callResult.Value)
	if err != nil {
		return nil, fmt.Errorf("CheckAvailability marshal: %w", err)
	}

	var result AvailabilityResult
	if err := json.Unmarshal(raw, &result); err != nil {
		return &AvailabilityResult{Available: false}, nil
	}
	return &result, nil
}

func (c *ActionClient) GetDownloadURL(extensionID, trackID, quality string) (string, error) {
	params := map[string]interface{}{
		"track_id": trackID,
		"quality":  quality,
	}
	callResult, err := c.runtime.CallMethod(extensionID, "getDownloadUrl", params)
	if err != nil {
		return "", err
	}
	if callResult.Value == nil {
		return "", fmt.Errorf("getDownloadUrl returned null")
	}

	raw, err := json.Marshal(callResult.Value)
	if err != nil {
		return "", fmt.Errorf("GetDownloadURL marshal: %w", err)
	}

	var result struct {
		URL string `json:"url"`
	}
	if err := json.Unmarshal(raw, &result); err != nil {
		return "", fmt.Errorf("GetDownloadURL parse: %w", err)
	}
	return result.URL, nil
}

func (c *ActionClient) Download(extensionID, trackID, quality, outputPath string) (*DownloadResult, error) {
	params := map[string]interface{}{
		"track_id":    trackID,
		"quality":     quality,
		"output_path": outputPath,
	}
	callResult, err := c.runtime.CallMethod(extensionID, "download", params)
	if err != nil {
		return &DownloadResult{Success: false, Error: err.Error()}, nil
	}
	if callResult.Value == nil {
		return &DownloadResult{Success: false, Error: "download returned null"}, nil
	}

	raw, err := json.Marshal(callResult.Value)
	if err != nil {
		return nil, fmt.Errorf("Download marshal: %w", err)
	}

	var result DownloadResult
	if err := json.Unmarshal(raw, &result); err != nil {
		return nil, fmt.Errorf("Download parse: %w", err)
	}
	return &result, nil
}
