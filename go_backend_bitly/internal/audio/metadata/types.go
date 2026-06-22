package metadata

import (
	"strconv"
	"strings"
)

// AudioMetadata holds metadata read from any audio file format.
type AudioMetadata struct {
	Title       string
	Artist      string
	Album       string
	AlbumArtist string
	Genre       string
	Year        string
	Date        string
	TrackNumber int
	TotalTracks int
	DiscNumber  int
	TotalDiscs  int
	ISRC        string
	Lyrics      string
	Label       string
	Copyright   string
	Composer    string
	Comment     string
	// ReplayGain fields (text values, e.g. "-6.50 dB", "0.988831")
	ReplayGainTrackGain string
	ReplayGainTrackPeak string
	ReplayGainAlbumGain string
	ReplayGainAlbumPeak string
}

// AudioQuality represents detected audio quality from a file.
type AudioQuality struct {
	BitDepth     int    `json:"bit_depth"`
	SampleRate   int    `json:"sample_rate"`
	TotalSamples int64  `json:"total_samples"`
	Duration     int    `json:"duration"`
	Codec        string `json:"codec"`
	Bitrate      int    `json:"bitrate,omitempty"`
}

// MP3Quality represents quality detected from an MP3 file.
type MP3Quality struct {
	SampleRate int
	BitDepth   int
	Duration   int
	Bitrate    int
}

// OggQuality represents quality detected from an Ogg/Opus file.
type OggQuality struct {
	SampleRate int
	BitDepth   int
	Duration   int
	Bitrate    int
}

// ParseIndexPair parses a "number/total" string like "3/12" or just "3".
func ParseIndexPair(s string) (int, int) {
	s = strings.TrimSpace(s)
	if s == "" {
		return 0, 0
	}
	first := s
	second := ""
	if idx := strings.Index(s, "/"); idx > 0 {
		first = s[:idx]
		second = s[idx+1:]
	}
	num, _ := strconv.Atoi(strings.TrimSpace(first))
	total, _ := strconv.Atoi(strings.TrimSpace(second))
	return num, total
}

// ParsePositiveInt parses a positive integer from string, returning 0 on failure.
func ParsePositiveInt(value string) int {
	value = strings.TrimSpace(value)
	if value == "" {
		return 0
	}
	n, _ := strconv.Atoi(value)
	return n
}

// FormatIndexValue formats a number and total into "number/total" or just "number".
func FormatIndexValue(number, total int) string {
	if number <= 0 {
		return ""
	}
	if total > 0 {
		return strconv.Itoa(number) + "/" + strconv.Itoa(total)
	}
	return strconv.Itoa(number)
}

// CleanGenre removes parenthesized ID3v1 genre numbers from genre strings.
func CleanGenre(genre string) string {
	if len(genre) == 0 {
		return ""
	}
	if genre[0] == '(' {
		end := strings.Index(genre, ")")
		if end > 0 {
			numStr := genre[1:end]
			if num, err := strconv.Atoi(numStr); err == nil && num >= 0 && num < len(ID3v1Genres) {
				if end+1 < len(genre) {
					return genre[end+1:]
				}
				return ID3v1Genres[num]
			}
		}
	}
	return genre
}

// FirstTextValue returns the text before the first null byte.
func FirstTextValue(s string) string {
	if idx := strings.IndexByte(s, 0); idx >= 0 {
		return s[:idx]
	}
	return s
}
