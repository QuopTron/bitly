package library

import (
	"encoding/json"
	"fmt"
	"time"
)

func ReadAudioMetadata(filePath string) (string, error) {
	return ReadAudioMetadataWithDisplayName(filePath, "")
}

func ReadAudioMetadataWithDisplayName(filePath, displayNameHint string) (string, error) {
	return ReadAudioMetadataWithDisplayNameAndCoverCacheKey(filePath, displayNameHint, "")
}

func ReadAudioMetadataWithDisplayNameAndCoverCacheKey(filePath, displayNameHint, coverCacheKey string) (string, error) {
	scanTime := time.Now().UTC().Format(time.RFC3339)
	result, err := scanAudioFileWithKnownModTimeAndDisplayNameAndCoverCacheKey(filePath, displayNameHint, coverCacheKey, scanTime, 0)
	if err != nil {
		return "", err
	}
	jsonBytes, err := json.Marshal(result)
	if err != nil {
		return "", fmt.Errorf("failed to marshal result: %w", err)
	}
	return string(jsonBytes), nil
}
