package cue

// CueSheet represents a parsed CUE sheet file.
type CueSheet struct {
	Performer string     `json:"performer"`
	Title     string     `json:"title"`
	FileName  string     `json:"file_name"`
	FileType  string     `json:"file_type"` // WAVE, FLAC, MP3, AIFF, etc.
	Genre     string     `json:"genre,omitempty"`
	Date      string     `json:"date,omitempty"`
	Comment   string     `json:"comment,omitempty"`
	Composer  string     `json:"composer,omitempty"`
	Tracks    []CueTrack `json:"tracks"`
}

// CueTrack represents a single track entry inside a CUE sheet.
type CueTrack struct {
	Number    int     `json:"number"`
	Title     string  `json:"title"`
	Performer string  `json:"performer"`
	ISRC      string  `json:"isrc,omitempty"`
	Composer  string  `json:"composer,omitempty"`
	StartTime float64 `json:"start_time"` // INDEX 01 in seconds
	PreGap    float64 `json:"pre_gap"`    // INDEX 00 in seconds (or -1 if not present)
}

// CueSplitInfo is the resolved split information for a CUE + audio file pair.
type CueSplitInfo struct {
	CuePath   string          `json:"cue_path"`
	AudioPath string          `json:"audio_path"`
	Album     string          `json:"album"`
	Artist    string          `json:"artist"`
	Genre     string          `json:"genre,omitempty"`
	Date      string          `json:"date,omitempty"`
	Tracks    []CueSplitTrack `json:"tracks"`
}

// CueSplitTrack is a single track ready for splitting.
type CueSplitTrack struct {
	Number   int     `json:"number"`
	Title    string  `json:"title"`
	Artist   string  `json:"artist"`
	ISRC     string  `json:"isrc,omitempty"`
	Composer string  `json:"composer,omitempty"`
	StartSec float64 `json:"start_sec"`
	EndSec   float64 `json:"end_sec"` // -1 means until end of file
}
