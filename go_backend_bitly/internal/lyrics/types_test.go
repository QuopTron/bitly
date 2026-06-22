package lyrics

import (
	"strings"
	"testing"
)

// ---------- LyricsLine ----------

func TestLyricsLine_DefaultZeroValues(t *testing.T) {
	line := LyricsLine{}
	if line.StartTimeMs != 0 {
		t.Errorf("expected StartTimeMs 0, got %d", line.StartTimeMs)
	}
	if line.Words != "" {
		t.Errorf("expected empty Words, got %q", line.Words)
	}
	if line.EndTimeMs != 0 {
		t.Errorf("expected EndTimeMs 0, got %d", line.EndTimeMs)
	}
}

func TestLyricsLine_FullPopulation(t *testing.T) {
	line := LyricsLine{
		StartTimeMs: 5000,
		Words:       "Hello world",
		EndTimeMs:   8000,
	}
	if line.StartTimeMs != 5000 {
		t.Errorf("expected 5000, got %d", line.StartTimeMs)
	}
	if line.Words != "Hello world" {
		t.Errorf("expected 'Hello world', got %q", line.Words)
	}
	if line.EndTimeMs != 8000 {
		t.Errorf("expected 8000, got %d", line.EndTimeMs)
	}
}

// ---------- LyricsResponse ----------

func TestLyricsResponse_DefaultZeroValues(t *testing.T) {
	resp := LyricsResponse{}
	if resp.Lines != nil {
		t.Errorf("expected nil Lines, got %v", resp.Lines)
	}
	if resp.PlainLyrics != "" {
		t.Errorf("expected empty PlainLyrics, got %q", resp.PlainLyrics)
	}
	if resp.Provider != "" {
		t.Errorf("expected empty Provider, got %q", resp.Provider)
	}
	if resp.Instrumental {
		t.Error("expected Instrumental to be false")
	}
}

func TestLyricsResponse_FullPopulation(t *testing.T) {
	resp := LyricsResponse{
		Lines: []LyricsLine{
			{StartTimeMs: 1000, Words: "Line1", EndTimeMs: 2000},
			{StartTimeMs: 2000, Words: "Line2", EndTimeMs: 3000},
		},
		SyncType:     "LINE_SYNCED",
		Instrumental: false,
		PlainLyrics:  "Line1\nLine2",
		Provider:     "test",
		Source:       "test source",
	}
	if len(resp.Lines) != 2 {
		t.Errorf("expected 2 lines, got %d", len(resp.Lines))
	}
	if resp.SyncType != "LINE_SYNCED" {
		t.Errorf("expected LINE_SYNCED, got %q", resp.SyncType)
	}
	if resp.PlainLyrics != "Line1\nLine2" {
		t.Errorf("expected 'Line1\\nLine2', got %q", resp.PlainLyrics)
	}
	if resp.Provider != "test" {
		t.Errorf("expected 'test', got %q", resp.Provider)
	}
}

func TestLyricsResponse_InstrumentalResponse(t *testing.T) {
	resp := &LyricsResponse{
		Instrumental: true,
		Source:       "Heuristic: Instrumental",
	}
	if !resp.Instrumental {
		t.Error("expected Instrumental to be true")
	}
	if resp.Source != "Heuristic: Instrumental" {
		t.Errorf("unexpected source: %q", resp.Source)
	}
}

func TestLyricsResponse_ProviderAndSource(t *testing.T) {
	resp := &LyricsResponse{
		Provider: "Apple Music",
		Source:   "Apple Music",
	}
	if resp.Provider != "Apple Music" {
		t.Errorf("expected 'Apple Music', got %q", resp.Provider)
	}
	if resp.Source != "Apple Music" {
		t.Errorf("expected 'Apple Music', got %q", resp.Source)
	}
}

// ---------- LRCLibResponse ----------

func TestLRCLibResponse_DefaultValues(t *testing.T) {
	resp := LRCLibResponse{}
	if resp.PlainLyrics != "" {
		t.Errorf("expected empty PlainLyrics, got %q", resp.PlainLyrics)
	}
	if resp.SyncedLyrics != "" {
		t.Errorf("expected empty SyncedLyrics, got %q", resp.SyncedLyrics)
	}
	if resp.Instrumental {
		t.Error("expected Instrumental to be false")
	}
}

func TestLRCLibResponse_Populated(t *testing.T) {
	resp := LRCLibResponse{
		ID:           123,
		Name:         "Test Song",
		TrackName:    "Test Song",
		ArtistName:   "Test Artist",
		AlbumName:    "Test Album",
		Duration:     200.5,
		Instrumental: false,
		PlainLyrics:  "Lyrics here",
		SyncedLyrics: "[00:01.00]Lyrics here",
	}
	if resp.ID != 123 {
		t.Errorf("expected 123, got %d", resp.ID)
	}
	if resp.TrackName != "Test Song" {
		t.Errorf("expected 'Test Song', got %q", resp.TrackName)
	}
	if resp.ArtistName != "Test Artist" {
		t.Errorf("expected 'Test Artist', got %q", resp.ArtistName)
	}
	if resp.Duration != 200.5 {
		t.Errorf("expected 200.5, got %f", resp.Duration)
	}
}

// ---------- LyricsFetchOptions ----------

func TestLyricsFetchOptions_Defaults(t *testing.T) {
	opts := LyricsFetchOptions{}
	if opts.IncludeTranslationNetease {
		t.Error("expected IncludeTranslationNetease to be false")
	}
	if opts.MultiPersonWordByWord {
		t.Error("expected MultiPersonWordByWord to be false in zero value")
	}
	if opts.AppleElrcWordSync {
		t.Error("expected AppleElrcWordSync to be false")
	}
	if opts.MusixmatchLanguage != "" {
		t.Errorf("expected empty MusixmatchLanguage, got %q", opts.MusixmatchLanguage)
	}
}

func TestLyricsFetchOptions_FullConfig(t *testing.T) {
	opts := LyricsFetchOptions{
		IncludeTranslationNetease:  true,
		IncludeRomanizationNetease: true,
		MultiPersonWordByWord:      true,
		AppleElrcWordSync:          true,
		MusixmatchLanguage:         "en",
	}
	if !opts.IncludeTranslationNetease {
		t.Error("expected IncludeTranslationNetease to be true")
	}
	if !opts.IncludeRomanizationNetease {
		t.Error("expected IncludeRomanizationNetease to be true")
	}
	if !opts.MultiPersonWordByWord {
		t.Error("expected MultiPersonWordByWord to be true")
	}
	if !opts.AppleElrcWordSync {
		t.Error("expected AppleElrcWordSync to be true")
	}
	if opts.MusixmatchLanguage != "en" {
		t.Errorf("expected 'en', got %q", opts.MusixmatchLanguage)
	}
}

// ---------- Provider constants ----------

func TestProviderConstants_Unique(t *testing.T) {
	providers := []string{
		ProviderLRCLIB,
		ProviderNetease,
		ProviderMusixmatch,
		ProviderAppleMusic,
		ProviderQQMusic,
		ProviderSpotify,
		ProviderDeezer,
		ProviderYouTube,
		ProviderKugou,
		ProviderGenius,
	}
	seen := make(map[string]bool)
	for _, p := range providers {
		if p == "" {
			t.Error("provider constant should not be empty")
		}
		if seen[p] {
			t.Errorf("duplicate provider constant: %q", p)
		}
		seen[p] = true
	}
}

func TestProviderConstants_Values(t *testing.T) {
	tests := []struct {
		got  string
		want string
	}{
		{ProviderLRCLIB, "lrclib"},
		{ProviderNetease, "netease"},
		{ProviderMusixmatch, "musixmatch"},
		{ProviderAppleMusic, "apple_music"},
		{ProviderQQMusic, "qqmusic"},
		{ProviderSpotify, "spotify"},
		{ProviderDeezer, "deezer"},
		{ProviderYouTube, "youtube"},
		{ProviderKugou, "kugou"},
		{ProviderGenius, "genius"},
	}
	for _, tt := range tests {
		if tt.got != tt.want {
			t.Errorf("expected %q, got %q", tt.want, tt.got)
		}
	}
}

// ---------- LyricsClient ----------

func TestNewLyricsClient(t *testing.T) {
	client := NewLyricsClient()
	if client == nil {
		t.Fatal("expected non-nil client")
	}
	if client.httpClient == nil {
		t.Error("expected non-nil httpClient")
	}
}

// ---------- Error payload detection helpers ----------

func TestDetectLyricsErrorPayload_LyricsKeyPreventsError(t *testing.T) {
	payload := `{"lyrics":"actual content","message":"some warning"}`
	_, ok := DetectLyricsErrorPayload(payload)
	if ok {
		t.Error("expected false when lyrics key is present alongside error key")
	}
}

func TestDetectLyricsErrorPayload_NonStringErrorMessage(t *testing.T) {
	payload := `{"message":123}`
	_, ok := DetectLyricsErrorPayload(payload)
	if ok {
		t.Error("expected false for non-string error message")
	}
}

func TestDetectLyricsErrorPayload_EmptyErrorMessage(t *testing.T) {
	payload := `{"message":""}`
	_, ok := DetectLyricsErrorPayload(payload)
	if ok {
		t.Error("expected false for empty error message")
	}
}

// ---------- PlainLyricsFromTimedLines Edge Cases ----------

func TestPlainLyricsFromTimedLines_WhitespaceOnly(t *testing.T) {
	lines := []LyricsLine{
		{Words: "  "},
		{Words: "valid"},
	}
	got := PlainLyricsFromTimedLines(lines)
	if got != "valid" {
		t.Errorf("expected 'valid', got %q", got)
	}
}

// ---------- Synced LRC Edge Cases ----------

func TestParseSyncedLyrics_OnlyBgLines(t *testing.T) {
	lrc := "[bg:background only]"
	lines := ParseSyncedLyrics(lrc)
	if len(lines) != 0 {
		t.Errorf("expected 0 lines for orphan bg only, got %d", len(lines))
	}
}

func TestParseSyncedLyrics_MultipleBgLines(t *testing.T) {
	lrc := `[00:01.00]Main
[bg:bg1]
[bg:bg2]`
	lines := ParseSyncedLyrics(lrc)
	if len(lines) != 1 {
		t.Fatalf("expected 1 main line, got %d", len(lines))
	}
	if !strings.Contains(lines[0].Words, "Main") {
		t.Errorf("expected 'Main' in words")
	}
	if !strings.Contains(lines[0].Words, "bg1") {
		t.Errorf("expected 'bg1' in words")
	}
	if !strings.Contains(lines[0].Words, "bg2") {
		t.Errorf("expected 'bg2' in words")
	}
}

// ---------- Struct composition ----------

func TestAppleMusicSearchResult_Fields(t *testing.T) {
	r := appleMusicSearchResult{
		ID:         "123",
		SongName:   "Song",
		ArtistName: "Artist",
		AlbumName:  "Album",
		Duration:   200000,
	}
	if r.ID != "123" || r.SongName != "Song" || r.ArtistName != "Artist" || r.AlbumName != "Album" || r.Duration != 200000 {
		t.Error("appleMusicSearchResult fields not set correctly")
	}
}

func TestNeteaseSearchResponse_Structure(t *testing.T) {
	sr := neteaseSearchResponse{Code: 200}
	if sr.Code != 200 {
		t.Errorf("expected 200, got %d", sr.Code)
	}
	if len(sr.Result.Songs) != 0 {
		t.Errorf("expected empty songs, got %d", len(sr.Result.Songs))
	}
}

func TestNeteaseLyricsResponse_Fields(t *testing.T) {
	lrc := &neteaseLyricField{Lyric: "[00:01.00]test"}
	resp := neteaseLyricsResponse{
		LRC:     lrc,
		TLyric:  nil,
		RomaLRC: nil,
		Code:    200,
	}
	if resp.LRC.Lyric != "[00:01.00]test" {
		t.Errorf("unexpected lyric: %q", resp.LRC.Lyric)
	}
	if resp.Code != 200 {
		t.Errorf("expected 200, got %d", resp.Code)
	}
}

func TestGeniusSearchResponse_Structure(t *testing.T) {
	gs := geniusSearchResponse{}
	if len(gs.Response.Sections) != 0 {
		t.Errorf("expected empty sections, got %d", len(gs.Response.Sections))
	}
}

// ---------- pax types ----------

func TestPaxsenixLyricsObject_Fields(t *testing.T) {
	obj := paxsenixLyricsObject{
		Type:        "Syllable",
		LyricsText:  "plain text",
		PlainLyrics: "also plain",
	}
	if obj.LyricsText != "plain text" {
		t.Errorf("unexpected LyricsText: %q", obj.LyricsText)
	}
}



// ---------- Conversion round trips ----------

func TestLrcTimestampToMs_LargeValues(t *testing.T) {
	got := LrcTimestampToMs("10", "30", "50")
	if got != 630500 {
		t.Errorf("expected 630500, got %d", got)
	}
}
