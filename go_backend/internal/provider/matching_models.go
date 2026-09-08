package provider

var noiseWords = map[string]bool{
	"official": true, "video": true, "audio": true, "lyrics": true, "lyric": true,
	"hd": true, "4k": true, "remaster": true, "remastered": true, "version": true,
	"feat": true, "featuring": true, "ft": true, "with": true, "album": true,
	"single": true, "ep": true,
}

// nonOriginalMarkers are substrings that indicate a version that is NOT the
// original studio cut (remix/live/cover/acoustic/etc). Checked against the raw
// (case-folded) title so they still catch variants that noise stripping would
// otherwise hide ("Song (Live)" -> "song").
var nonOriginalMarkers = []string{
	"remix", "live", "cover", "acoustic", "karaoke", "instrumental",
	"sped up", "spedup", "slowed", "acapella", "orchestral", "tribute",
	"orchestra", "piano", "string quartet", "choir",
	"extended", "rework", "remake", "nightcore", "dance edit", "radio edit",
	"club mix", "dub mix", "disco edit", "reprise",
}
