package metadata

import (
	"fmt"
	"strings"
)

// GetAudioQualityFromFile detects audio quality from any supported file.
func GetAudioQualityFromFile(filePath string) (AudioQuality, error) {
	lower := strings.ToLower(filePath)
	switch {
	case strings.HasSuffix(lower, ".flac"):
		return GetFlacQuality(filePath)
	case strings.HasSuffix(lower, ".m4a"), strings.HasSuffix(lower, ".aac"):
		return GetM4AQuality(filePath)
	case strings.HasSuffix(lower, ".mp3"):
		q, err := GetMP3Quality(filePath)
		if err != nil {
			return AudioQuality{}, err
		}
		return AudioQuality{
			SampleRate: q.SampleRate,
			Duration:   q.Duration,
			Codec:      "MP3",
			Bitrate:    q.Bitrate,
		}, nil
	case strings.HasSuffix(lower, ".opus"), strings.HasSuffix(lower, ".ogg"):
		q, err := GetOggQuality(filePath)
		if err != nil {
			return AudioQuality{}, err
		}
		return AudioQuality{
			SampleRate: q.SampleRate,
			Duration:   q.Duration,
			Codec:      "Opus",
			Bitrate:    q.Bitrate,
		}, nil
	default:
		return AudioQuality{}, fmt.Errorf("unsupported format: %s", filePath)
	}
}
