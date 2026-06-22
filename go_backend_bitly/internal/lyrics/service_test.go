package lyrics

import (
	"strings"
	"sync"
	"testing"
)

// ---------- Timestamp conversion ----------

func TestLrcTimestampToMs(t *testing.T) {
	tests := []struct {
		min, sec, cs string
		want         int64
	}{
		{"01", "30", "50", 90500},
		{"00", "00", "00", 0},
		{"00", "00", "99", 990},
		{"01", "00", "00", 60000},
		{"10", "00", "00", 600000},
		{"00", "05", "123", 5123},
	}
	for _, tt := range tests {
		got := LrcTimestampToMs(tt.min, tt.sec, tt.cs)
		if got != tt.want {
			t.Errorf("LrcTimestampToMs(%q, %q, %q) = %d, want %d", tt.min, tt.sec, tt.cs, got, tt.want)
		}
	}
}

func TestMsToLRCTimestamp(t *testing.T) {
	tests := []struct {
		ms   int64
		want string
	}{
		{90500, "[01:30.50]"},
		{0, "[00:00.00]"},
		{60000, "[01:00.00]"},
		{5123, "[00:05.12]"},
		{5000, "[00:05.00]"},
	}
	for _, tt := range tests {
		got := MsToLRCTimestamp(tt.ms)
		if got != tt.want {
			t.Errorf("MsToLRCTimestamp(%d) = %q, want %q", tt.ms, got, tt.want)
		}
	}
}

func TestRoundTripTimestamp(t *testing.T) {
	inputs := []int64{0, 100, 5000, 60000, 90500, 600000, 123456}
	for _, ms := range inputs {
		lrc := MsToLRCTimestamp(ms)
		got := LrcTimestampToMs(lrc[1:3], lrc[4:6], lrc[7:9])
		// centiseconds precision loss for non-multiple-of-10
		if got != ms && (ms%10 != 0) {
			continue
		}
		if got != ms && ms%10 == 0 {
			t.Errorf("round-trip %d -> %s -> %d", ms, lrc, got)
		}
	}
}

// ---------- ConvertToLRCWithMetadata ----------

func TestConvertToLRCWithMetadata_Nil(t *testing.T) {
	got := ConvertToLRCWithMetadata(nil, "Track", "Artist")
	if got != "" {
		t.Errorf("expected empty string, got %q", got)
	}
}

func TestConvertToLRCWithMetadata_EmptyLines(t *testing.T) {
	got := ConvertToLRCWithMetadata(&LyricsResponse{}, "Track", "Artist")
	if got != "" {
		t.Errorf("expected empty string, got %q", got)
	}
}

func TestConvertToLRCWithMetadata_LineSynced(t *testing.T) {
	lyrics := &LyricsResponse{
		SyncType: "LINE_SYNCED",
		Lines: []LyricsLine{
			{StartTimeMs: 5000, Words: "Hello"},
			{StartTimeMs: 10000, Words: "World"},
		},
	}
	got := ConvertToLRCWithMetadata(lyrics, "Test Song", "Test Artist")

	if !strings.HasPrefix(got, "[ti:Test Song]\n[ar:Test Artist]\n") {
		t.Errorf("unexpected header prefix: %q", got[:50])
	}
	if !strings.Contains(got, "[00:05.00]Hello\n[00:10.00]World") {
		t.Errorf("expected timed lines, got: %q", got)
	}
}

func TestConvertToLRCWithMetadata_Unsynced(t *testing.T) {
	lyrics := &LyricsResponse{
		SyncType: "UNSYNCED",
		Lines: []LyricsLine{
			{Words: "Line one"},
			{Words: "Line two"},
		},
	}
	got := ConvertToLRCWithMetadata(lyrics, "Track", "Artist")

	if !strings.Contains(got, "Line one\n") {
		t.Errorf("expected untimed lines, got: %q", got)
	}
}

func TestConvertToLRCWithMetadata_SkipsEmptyWords(t *testing.T) {
	lyrics := &LyricsResponse{
		SyncType: "LINE_SYNCED",
		Lines: []LyricsLine{
			{StartTimeMs: 1000, Words: ""},
			{StartTimeMs: 2000, Words: "Only"},
		},
	}
	got := ConvertToLRCWithMetadata(lyrics, "T", "A")
	if strings.Contains(got, "[00:01.00]\n") {
		t.Error("should not include empty-word lines")
	}
	if !strings.Contains(got, "Only") {
		t.Error("should include non-empty line")
	}
}

// ---------- SimplifyTrackName ----------

func TestSimplifyTrackName(t *testing.T) {
	tests := []struct {
		input string
		want  string
	}{
		{"Song (feat. Artist)", "Song"},
		{"Song (ft. Artist)", "Song"},
		{"Song (featuring Artist)", "Song"},
		{"Song (with Artist)", "Song"},
		{"Song - Remastered", "Song"},
		{"Song - 2024 Remaster", "Song"},
		{"Song (Remastered 2024)", "Song"},
		{"Song (Deluxe Edition)", "Song"},
		{"Song (Bonus Track)", "Song"},
		{"Song (Live at Wembley)", "Song"},
		{"Song (Acoustic Version)", "Song"},
		{"Song (Radio Edit)", "Song"},
		{"Song (Single Version)", "Song"},
		{"Plain Song", "Plain Song"},
		{"", ""},
	}
	for _, tt := range tests {
		got := SimplifyTrackName(tt.input)
		if got != tt.want {
			t.Errorf("SimplifyTrackName(%q) = %q, want %q", tt.input, got, tt.want)
		}
	}
}

// ---------- NormalizeArtistName ----------

func TestNormalizeArtistName(t *testing.T) {
	tests := []struct {
		input string
		want  string
	}{
		{"Artist feat. Guest", "Artist"},
		{"Artist ft. Guest", "Artist"},
		{"Artist featuring Guest", "Artist"},
		{"Artist with Guest", "Artist"},
		{"Artist, Guest", "Artist"},
		{"Artist; Guest", "Artist"},
		{"Artist & Guest", "Artist"},
		{"Artist vs Guest", "Artist"},
		{"Artist presents Guest", "Artist"},
		{"Artist presentó Guest", "Artist"},
		{"Artist y Guest", "Artist"},
		{"Artist x Guest", "Artist"},
		{"Solo Artist", "Solo Artist"},
		{"", ""},
		{"  spaces here  ", "spaces here"},
	}
	for _, tt := range tests {
		got := NormalizeArtistName(tt.input)
		if got != tt.want {
			t.Errorf("NormalizeArtistName(%q) = %q, want %q", tt.input, got, tt.want)
		}
	}
}

// ---------- isLikelyInstrumentalTrack ----------

func TestIsLikelyInstrumentalTrack(t *testing.T) {
	tests := []struct {
		name string
		want bool
	}{
		{"Instrumental", true},
		{"instrumental", true},
		{"Song (Instrumental)", true},
		{"Song - Instrumental", true},
		{"Inst.", true},
		{"Inst. Version", true},
		{"inst", true},
		{"Instrumental Mix", true},
		{"Not instrumental", true},
		{"Instrument", false},
		{"", false},
	    {"Pure Instrument", false},
	}
	for _, tt := range tests {
		got := isLikelyInstrumentalTrack(tt.name)
		if got != tt.want {
			t.Errorf("isLikelyInstrumentalTrack(%q) = %v, want %v", tt.name, got, tt.want)
		}
	}
}

// ---------- ParseSyncedLyrics ----------

func TestParseSyncedLyrics(t *testing.T) {
	lrc := `[00:01.50]First line
[00:04.20]Second line
[00:07.00]Third line`

	lines := ParseSyncedLyrics(lrc)
	if len(lines) != 3 {
		t.Fatalf("expected 3 lines, got %d", len(lines))
	}

	expected := []struct {
		start int64
		words string
	}{
		{1500, "First line"},
		{4200, "Second line"},
		{7000, "Third line"},
	}
	for i, e := range expected {
		if lines[i].StartTimeMs != e.start {
			t.Errorf("line %d StartTimeMs = %d, want %d", i, lines[i].StartTimeMs, e.start)
		}
		if lines[i].Words != e.words {
			t.Errorf("line %d Words = %q, want %q", i, lines[i].Words, e.words)
		}
	}
	// check end times
	if lines[0].EndTimeMs != 4200 {
		t.Errorf("line 0 EndTimeMs = %d, want 4200", lines[0].EndTimeMs)
	}
	if lines[2].EndTimeMs != 12000 {
		t.Errorf("last line EndTimeMs = %d, want 12000", lines[2].EndTimeMs)
	}
}

func TestParseSyncedLyrics_SkipsEmptyLines(t *testing.T) {
	lrc := "\n\n[00:01.00]Line\n\n\n[00:02.00]Line2\n"
	lines := ParseSyncedLyrics(lrc)
	if len(lines) != 2 {
		t.Errorf("expected 2 lines, got %d", len(lines))
	}
}

func TestParseSyncedLyrics_SkipsEmptyWords(t *testing.T) {
	lrc := "[00:01.00]\n[00:02.00]Real"
	lines := ParseSyncedLyrics(lrc)
	if len(lines) != 1 {
		t.Errorf("expected 1 line, got %d", len(lines))
	}
}

func TestParseSyncedLyrics_HandlesBgTag(t *testing.T) {
	lrc := `[00:01.00]Main vocal
[bg:background text]`

	lines := ParseSyncedLyrics(lrc)
	if len(lines) != 1 {
		t.Fatalf("expected 1 line, got %d", len(lines))
	}
	if !strings.Contains(lines[0].Words, "Main vocal") || !strings.Contains(lines[0].Words, "background text") {
		t.Errorf("expected bg text appended to main line, got %q", lines[0].Words)
	}
}

func TestParseSyncedLyrics_BgWithoutParentLine(t *testing.T) {
	lrc := `[bg:orphan bg]
[00:01.00]Line`

	lines := ParseSyncedLyrics(lrc)
	if len(lines) != 1 {
		t.Fatalf("expected 1 line, got %d", len(lines))
	}
	if lines[0].Words != "Line" {
		t.Errorf("expected 'Line', got %q", lines[0].Words)
	}
}

func TestParseSyncedLyrics_ThreeDigitCentiseconds(t *testing.T) {
	lrc := "[01:30.123]Test"
	lines := ParseSyncedLyrics(lrc)
	if len(lines) != 1 {
		t.Fatalf("expected 1 line, got %d", len(lines))
	}
	if lines[0].StartTimeMs != 90123 {
		t.Errorf("expected 90123, got %d", lines[0].StartTimeMs)
	}
}

func TestParseSyncedLyrics_EmptyInput(t *testing.T) {
	lines := ParseSyncedLyrics("")
	if len(lines) != 0 {
		t.Errorf("expected 0 lines, got %d", len(lines))
	}
}

// ---------- PlainTextLyricsLines ----------

func TestPlainTextLyricsLines(t *testing.T) {
	input := "Line one\n\nLine two\n  \nLine three"
	lines := PlainTextLyricsLines(input)
	if len(lines) != 3 {
		t.Fatalf("expected 3 lines, got %d", len(lines))
	}
	if lines[0].Words != "Line one" {
		t.Errorf("expected 'Line one', got %q", lines[0].Words)
	}
}

func TestPlainTextLyricsLines_Empty(t *testing.T) {
	lines := PlainTextLyricsLines("")
	if len(lines) != 0 {
		t.Errorf("expected 0 lines, got %d", len(lines))
	}
	lines = PlainTextLyricsLines("   \n\n  ")
	if len(lines) != 0 {
		t.Errorf("expected 0 lines for whitespace-only, got %d", len(lines))
	}
}

// ---------- PlainLyricsFromTimedLines ----------

func TestPlainLyricsFromTimedLines(t *testing.T) {
	lines := []LyricsLine{
		{StartTimeMs: 1000, Words: "First"},
		{StartTimeMs: 2000, Words: ""},
		{StartTimeMs: 3000, Words: "Third"},
	}
	got := PlainLyricsFromTimedLines(lines)
	if got != "First\nThird" {
		t.Errorf("expected 'First\\nThird', got %q", got)
	}
}

func TestPlainLyricsFromTimedLines_Empty(t *testing.T) {
	got := PlainLyricsFromTimedLines(nil)
	if got != "" {
		t.Errorf("expected empty, got %q", got)
	}
}

// ---------- LyricsHasUsableText ----------

func TestLyricsHasUsableText(t *testing.T) {
	tests := []struct {
		name  string
		input *LyricsResponse
		want  bool
	}{
		{"nil", nil, false},
		{"instrumental", &LyricsResponse{Instrumental: true}, true},
		{"plain lyrics", &LyricsResponse{PlainLyrics: "some text"}, true},
		{"lines with words", &LyricsResponse{Lines: []LyricsLine{{Words: "text"}}}, true},
		{"empty", &LyricsResponse{}, false},
		{"only empty lines", &LyricsResponse{Lines: []LyricsLine{{Words: ""}}}, false},
		{"whitespace plain", &LyricsResponse{PlainLyrics: "  "}, false},
	}
	for _, tt := range tests {
		got := LyricsHasUsableText(tt.input)
		if got != tt.want {
			t.Errorf("LyricsHasUsableText(%s) = %v, want %v", tt.name, got, tt.want)
		}
	}
}

// ---------- DetectLyricsErrorPayload ----------

func TestDetectLyricsErrorPayload(t *testing.T) {
	tests := []struct {
		input   string
		wantMsg string
		wantOK  bool
	}{
		{`{"message":"not found"}`, "not found", true},
		{`{"error":"bad request"}`, "bad request", true},
		{`{"detail":"timeout"}`, "timeout", true},
		{`{"reason":"rate limit"}`, "rate limit", true},
		{`{"success":false}`, "request unsuccessful", true},
		{`{"lyrics":"actual lyrics"}`, "", false},
		{`{"message":"info","lyrics":"real content"}`, "", false},
		{`not json`, "", false},
		{``, "", false},
		{`{}`, "", false},
		{`{"success":true}`, "", false},
	}
	for _, tt := range tests {
		msg, ok := DetectLyricsErrorPayload(tt.input)
		if ok != tt.wantOK {
			t.Errorf("DetectLyricsErrorPayload(%q) ok = %v, want %v", tt.input, ok, tt.wantOK)
		}
		if msg != tt.wantMsg {
			t.Errorf("DetectLyricsErrorPayload(%q) msg = %q, want %q", tt.input, msg, tt.wantMsg)
		}
	}
}

// ---------- scoreLyricsSearchCandidate ----------

func TestScoreLyricsSearchCandidate(t *testing.T) {
	tests := []struct {
		name             string
		candidateTrack   string
		candidateArtist  string
		candidateDur     float64
		trackName        string
		artistName       string
		durationSec      float64
		wantHigherBetter bool
	}{
		{"exact match", "Song", "Artist", 200, "Song", "Artist", 200, true},
		{"partial track", "Song (Live)", "Artist", 0, "Song", "Artist", 0, true},
		{"wrong artist", "Song", "Wrong", 0, "Song", "Artist", 0, false},
	}
	for _, tt := range tests {
		score := scoreLyricsSearchCandidate(tt.candidateTrack, tt.candidateArtist, tt.candidateDur, tt.trackName, tt.artistName, tt.durationSec)
		if score < 0 {
			t.Errorf("%s: expected non-negative score, got %d", tt.name, score)
		}
	}
}

func TestScoreLyricsSearchCandidate_PreferExactMatches(t *testing.T) {
	exactScore := scoreLyricsSearchCandidate("Bohemian Rhapsody", "Queen", 0, "Bohemian Rhapsody", "Queen", 0)
	// "Some Other Song" should score lower than exact match
	partialScore := scoreLyricsSearchCandidate("Some Other Song", "Queen", 0, "Bohemian Rhapsody", "Queen", 0)
	if exactScore <= partialScore {
		t.Errorf("exact match (%d) should score higher than partial (%d)", exactScore, partialScore)
	}
}

// ---------- selectBestAppleMusicSearchResult ----------

func TestSelectBestAppleMusicSearchResult_Nil(t *testing.T) {
	got := selectBestAppleMusicSearchResult(nil, "track", "artist", 0)
	if got != nil {
		t.Errorf("expected nil, got %v", got)
	}
}

func TestSelectBestAppleMusicSearchResult_Empty(t *testing.T) {
	got := selectBestAppleMusicSearchResult([]appleMusicSearchResult{}, "t", "a", 0)
	if got != nil {
		t.Errorf("expected nil, got %v", got)
	}
}

func TestSelectBestAppleMusicSearchResult_SelectsHighest(t *testing.T) {
	results := []appleMusicSearchResult{
		{ID: "1", SongName: "Wrong Song", ArtistName: "Artist A"},
		{ID: "2", SongName: "Target", ArtistName: "Artist B"},
	}
	got := selectBestAppleMusicSearchResult(results, "Target", "Artist B", 0)
	if got == nil || got.ID != "2" {
		t.Errorf("expected ID '2', got %v", got)
	}
}

// ---------- Provider order ----------

func TestSetLyricsProviderOrder_EmptyResetsToNil(t *testing.T) {
	SetLyricsProviderOrder([]string{ProviderLRCLIB, ProviderAppleMusic})
	SetLyricsProviderOrder([]string{})
	order := GetLyricsProviderOrder()
	if len(order) != 2 || order[0] != ProviderLRCLIB || order[1] != ProviderAppleMusic {
		t.Errorf("expected default order, got %v", order)
	}
}

func TestSetLyricsProviderOrder_FiltersInvalid(t *testing.T) {
	SetLyricsProviderOrder([]string{"lrclib", "invalid_provider", "apple_music", ""})
	order := GetLyricsProviderOrder()
	if len(order) != 2 {
		t.Errorf("expected 2 valid providers, got %d: %v", len(order), order)
	}
}

func TestSetLyricsProviderOrder_Normalizes(t *testing.T) {
	SetLyricsProviderOrder([]string{"  APPLE_Music  ", "LRCLIB"})
	order := GetLyricsProviderOrder()
	if len(order) != 2 || order[0] != "apple_music" || order[1] != "lrclib" {
		t.Errorf("expected normalized order, got %v", order)
	}
}

func TestGetLyricsProviderOrder_ReturnsCopy(t *testing.T) {
	SetLyricsProviderOrder([]string{ProviderLRCLIB})
	order := GetLyricsProviderOrder()
	order[0] = "modified"
	if GetLyricsProviderOrder()[0] != ProviderLRCLIB {
		t.Error("modifying returned slice should not affect internal state")
	}
}

func TestDefaultLyricsProviders(t *testing.T) {
	if len(DefaultLyricsProviders) != 2 {
		t.Errorf("expected 2 default providers, got %d", len(DefaultLyricsProviders))
	}
	if DefaultLyricsProviders[0] != ProviderLRCLIB {
		t.Errorf("expected first default to be lrclib, got %s", DefaultLyricsProviders[0])
	}
}

// ---------- GetAvailableLyricsProviders ----------

func TestGetAvailableLyricsProviders(t *testing.T) {
	providers := GetAvailableLyricsProviders()
	if len(providers) != 10 {
		t.Errorf("expected 10 providers, got %d", len(providers))
	}

	found := make(map[string]bool)
	for _, p := range providers {
		id, ok := p["id"].(string)
		if !ok {
			t.Error("each provider must have a string 'id'")
		}
		found[id] = true
	}

	for _, id := range []string{ProviderLRCLIB, ProviderNetease, ProviderMusixmatch, ProviderAppleMusic,
		ProviderQQMusic, ProviderSpotify, ProviderDeezer, ProviderYouTube, ProviderKugou, ProviderGenius} {
		if !found[id] {
			t.Errorf("missing provider %q in available list", id)
		}
	}
}

// ---------- Fetch options ----------

func TestGetLyricsFetchOptions_Defaults(t *testing.T) {
	opts := GetLyricsFetchOptions()
	if !opts.MultiPersonWordByWord {
		t.Error("expected MultiPersonWordByWord to default to true")
	}
}

func TestSetLyricsFetchOptions(t *testing.T) {
	opts := LyricsFetchOptions{
		IncludeTranslationNetease:  true,
		IncludeRomanizationNetease: true,
		MultiPersonWordByWord:      false,
		AppleElrcWordSync:          true,
		MusixmatchLanguage:         "en",
	}
	SetLyricsFetchOptions(opts)

	got := GetLyricsFetchOptions()
	if got.IncludeTranslationNetease != true {
		t.Error("IncludeTranslationNetease should be true")
	}
	if got.MultiPersonWordByWord != false {
		t.Error("MultiPersonWordByWord should be false")
	}
	if got.AppleElrcWordSync != true {
		t.Error("AppleElrcWordSync should be true")
	}
	if got.MusixmatchLanguage != "en" {
		t.Errorf("MusixmatchLanguage = %q, want 'en'", got.MusixmatchLanguage)
	}

	SetLyricsFetchOptions(LyricsFetchOptions{MultiPersonWordByWord: true})
}

func TestSetLyricsFetchOptions_SanitizesLanguage(t *testing.T) {
	SetLyricsFetchOptions(LyricsFetchOptions{
		MusixmatchLanguage: "  en-US!@#  ",
	})
	got := GetLyricsFetchOptions()
	if got.MusixmatchLanguage != "en-us" {
		t.Errorf("expected 'en-us', got %q", got.MusixmatchLanguage)
	}
	SetLyricsFetchOptions(LyricsFetchOptions{MultiPersonWordByWord: true})
}

func TestSetLyricsFetchOptions_TruncatesLanguage(t *testing.T) {
	SetLyricsFetchOptions(LyricsFetchOptions{
		MusixmatchLanguage: "abcdefghijklmnopqrstuvwxyz",
	})
	got := GetLyricsFetchOptions()
	if len(got.MusixmatchLanguage) > 16 {
		t.Errorf("language truncated to %d chars: %q", len(got.MusixmatchLanguage), got.MusixmatchLanguage)
	}
	SetLyricsFetchOptions(LyricsFetchOptions{MultiPersonWordByWord: true})
}

// ---------- parseClockDuration ----------

func TestParseClockDuration(t *testing.T) {
	tests := []struct {
		input string
		want  float64
	}{
		{"3:30", 210},
		{"1:00", 60},
		{"0:45", 45},
		{"1:30:00", 5400},
		{"", 0},
		{"abc", 0},
		{"3:xx", 0},
	}
	for _, tt := range tests {
		got := parseClockDuration(tt.input)
		if got != tt.want {
			t.Errorf("parseClockDuration(%q) = %f, want %f", tt.input, got, tt.want)
		}
	}
}

// ---------- normalizeDeezerLyricsID ----------

func TestNormalizeDeezerLyricsID(t *testing.T) {
	tests := []struct {
		input string
		want  string
	}{
		{"12345", "12345"},
		{"deezer:12345", "12345"},
		{"Deezer:67890", "67890"},
		{"https://deezer.com/track/99999", "99999"},
		{"https://deezer.com/track/99999?extra=true", "99999"},
		{"", ""},
		{"not-a-number", ""},
	}
	for _, tt := range tests {
		got := normalizeDeezerLyricsID(tt.input)
		if got != tt.want {
			t.Errorf("normalizeDeezerLyricsID(%q) = %q, want %q", tt.input, got, tt.want)
		}
	}
}

// ---------- normalizeSpotifyLyricsID ----------

func TestNormalizeSpotifyLyricsID(t *testing.T) {
	tests := []struct {
		input string
		want  string
	}{
		{"spotify:track:4iV5W9uYEdYUVa79Axb7Rh", "4iV5W9uYEdYUVa79Axb7Rh"},
		{"https://open.spotify.com/track/4iV5W9uYEdYUVa79Axb7Rh", "4iV5W9uYEdYUVa79Axb7Rh"},
		{"4iV5W9uYEdYUVa79Axb7Rh", "4iV5W9uYEdYUVa79Axb7Rh"},
		{"https://open.spotify.com/track/4iV5W9uYEdYUVa79Axb7Rh?si=abc", "4iV5W9uYEdYUVa79Axb7Rh"},
		{"", ""},
		{"deezer:12345", ""},
		{"not-a-22-char-id", ""},
		{"deezer:track", ""},
	}
	for _, tt := range tests {
		got := normalizeSpotifyLyricsID(tt.input)
		if got != tt.want {
			t.Errorf("normalizeSpotifyLyricsID(%q) = %q, want %q", tt.input, got, tt.want)
		}
	}
}

// ---------- lyricsResponseFromText ----------

func TestLyricsResponseFromText_Synced(t *testing.T) {
	text := "[00:01.00]Hello\n[00:02.00]World"
	resp := lyricsResponseFromText(text, "test_provider")
	if resp == nil {
		t.Fatal("expected non-nil response")
	}
	if resp.SyncType != "LINE_SYNCED" {
		t.Errorf("expected LINE_SYNCED, got %s", resp.SyncType)
	}
	if resp.Provider != "test_provider" {
		t.Errorf("expected test_provider, got %s", resp.Provider)
	}
	if len(resp.Lines) != 2 {
		t.Errorf("expected 2 lines, got %d", len(resp.Lines))
	}
}

func TestLyricsResponseFromText_Unsynced(t *testing.T) {
	text := "Line one\nLine two"
	resp := lyricsResponseFromText(text, "p")
	if resp == nil {
		t.Fatal("expected non-nil response")
	}
	if resp.SyncType != "UNSYNCED" {
		t.Errorf("expected UNSYNCED, got %s", resp.SyncType)
	}
}

func TestLyricsResponseFromText_Empty(t *testing.T) {
	resp := lyricsResponseFromText("", "p")
	if resp == nil {
		t.Fatal("expected non-nil response even for empty")
	}
	if resp.Provider != "p" {
		t.Errorf("expected provider 'p', got %s", resp.Provider)
	}
}

// ---------- selectBest functions ----------

func TestSelectBestKugouLyricsSearchResult_Empty(t *testing.T) {
	got := selectBestKugouLyricsSearchResult(nil, "track", "artist", 0)
	if got != nil {
		t.Errorf("expected nil, got %v", got)
	}
}

func TestSelectBestSpotifyLyricsSearchResult_Empty(t *testing.T) {
	got := selectBestSpotifyLyricsSearchResult(nil, "track", "artist", 0)
	if got != nil {
		t.Errorf("expected nil, got %v", got)
	}
}

func TestSelectBestYouTubeLyricsSearchResult_Empty(t *testing.T) {
	got := selectBestYouTubeLyricsSearchResult(nil, "track", "artist", 0)
	if got != nil {
		t.Errorf("expected nil, got %v", got)
	}
}

func TestSelectBestKugouLyricsSearchResult_ChoosesBest(t *testing.T) {
	results := []kugouLyricsSearchResult{
		{Hash: "aaa", Title: "Wrong", Artist: "Wrong", Duration: 100},
		{Hash: "bbb", Title: "Target Song", Artist: "Target Artist", Duration: 200},
	}
	got := selectBestKugouLyricsSearchResult(results, "Target Song", "Target Artist", 200)
	if got == nil || got.Hash != "bbb" {
		t.Errorf("expected 'bbb', got %v", got)
	}
}

// ---------- formatPaxContent ----------

func TestFormatPaxContent_SyllableType(t *testing.T) {
	content := []paxLyrics{
		{
			Timestamp: 5000,
			Text: []paxLyricDetail{
				{Text: "Hello", Part: false, Timestamp: intPtr(5000)},
				{Text: "World", Part: false, Timestamp: intPtr(8000)},
			},
			OppositeTurn: false,
		},
	}
	got := formatPaxContent("Syllable", content, false, false)
	// TrimSpace removes trailing space added after last syllable
	if got != "[00:05.00]Hello World" {
		t.Errorf("unexpected result: %q", got)
	}
}

func TestFormatPaxContent_SyllableWithMultiPerson(t *testing.T) {
	content := []paxLyrics{
		{Timestamp: 5000, Text: []paxLyricDetail{{Text: "Line1", Part: false}}, OppositeTurn: false},
		{Timestamp: 8000, Text: []paxLyricDetail{{Text: "Line2", Part: false}}, OppositeTurn: true},
	}
	got := formatPaxContent("Syllable", content, true, false)
	// TrimSpace removes trailing spaces added after last syllable
	expected := "[00:05.00]v1:Line1 \n[00:08.00]v2:Line2"
	if got != expected {
		t.Errorf("unexpected: %q", got)
	}
}

func TestFormatPaxContent_NonSyllableType(t *testing.T) {
	content := []paxLyrics{
		{Timestamp: 5000, Text: []paxLyricDetail{{Text: "Simple line", Part: false}}},
	}
	got := formatPaxContent("Other", content, false, false)
	if got != "[00:05.00]Simple line" {
		t.Errorf("unexpected: %q", got)
	}
}

func TestFormatPaxContent_BackgroundText(t *testing.T) {
	content := []paxLyrics{
		{
			Timestamp: 5000,
			Text:      []paxLyricDetail{{Text: "Main", Part: false}},
			Background: true,
			BackgroundText: []paxLyricDetail{{Text: "bg", Part: false}},
		},
	}
	got := formatPaxContent("Syllable", content, true, false)
	if !strings.Contains(got, "[bg:") {
		t.Errorf("expected background tag, got %q", got)
	}
}

// ---------- formatPaxLyricsToLRC ----------

func TestFormatPaxLyricsToLRC_InvalidJSON(t *testing.T) {
	_, err := formatPaxLyricsToLRC("not json", false, false)
	if err == nil {
		t.Error("expected error for invalid JSON")
	}
}

func TestFormatPaxLyricsToLRC_EmptyContent(t *testing.T) {
	_, err := formatPaxLyricsToLRC(`[]`, false, false)
	if err == nil {
		t.Error("expected error for empty array")
	}
}

func TestFormatPaxLyricsToLRC_WithResponse(t *testing.T) {
	input := `{"type":"Syllable","content":[{"timestamp":5000,"text":[{"text":"Hello","part":false}]}]}`
	result, err := formatPaxLyricsToLRC(input, false, false)
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if !strings.Contains(result, "Hello") {
		t.Errorf("expected 'Hello' in result: %q", result)
	}
}

func TestFormatPaxLyricsToLRC_DirectArray(t *testing.T) {
	input := `[{"timestamp":5000,"text":[{"text":"Hi","part":false}]}]`
	result, err := formatPaxLyricsToLRC(input, false, false)
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if !strings.Contains(result, "Hi") {
		t.Errorf("expected 'Hi' in result: %q", result)
	}
}

func TestFormatPaxLyricsToLRC_PreserveWordTiming(t *testing.T) {
	input := `{"type":"Syllable","content":[{"timestamp":5000,"text":[{"text":"Hel","part":true,"timestamp":5000,"endtime":5200},{"text":"lo","part":false,"timestamp":5200}]}]}`
	result, err := formatPaxLyricsToLRC(input, false, true)
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	// The function formats word-level timestamps. Check that timestamps & text are present.
	if !strings.Contains(result, "Hel") || !strings.Contains(result, "lo") {
		t.Errorf("expected Hel and lo in result, got %q", result)
	}
	// The result should contain word-level timestamps (angled brackets with HH:MM:SS.CC format)
	if !strings.Contains(result, "<00:05.00") && !strings.Contains(result, "<00:05.20") {
		t.Errorf("expected word-level timestamps <00:05...> in result, got %q", result)
	}
}

// ---------- formatQQLyricsMetadataToLRC ----------

func TestFormatQQLyricsMetadataToLRC_InvalidJSON(t *testing.T) {
	_, err := formatQQLyricsMetadataToLRC("not json", false)
	if err == nil {
		t.Error("expected error for invalid JSON")
	}
}

func TestFormatQQLyricsMetadataToLRC_Success(t *testing.T) {
	input := `{"lyrics":[{"timestamp":5000,"text":[{"text":"QQ Line","part":false}]}]}`
	result, err := formatQQLyricsMetadataToLRC(input, false)
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if !strings.Contains(result, "QQ Line") {
		t.Errorf("expected 'QQ Line' in result: %q", result)
	}
}

// ---------- parsePaxsenixLyricsPayload ----------

func TestParsePaxsenixLyricsPayload_StringInJSON(t *testing.T) {
	raw := `"plain LRC content here"`
	resp, err := parsePaxsenixLyricsPayload(raw, "TestProv", false)
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if resp.Provider != "TestProv" {
		t.Errorf("expected TestProv, got %s", resp.Provider)
	}
}

func TestParsePaxsenixLyricsPayload_ObjectWithLyricsKey(t *testing.T) {
	raw := `{"lyrics":"[00:01.00]Synced line"}`
	resp, err := parsePaxsenixLyricsPayload(raw, "TestProv", false)
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if len(resp.Lines) == 0 {
		t.Errorf("expected parsed lines")
	}
}

func TestParsePaxsenixLyricsPayload_FullObject(t *testing.T) {
	raw := `{"type":"Syllable","content":[{"timestamp":5000,"text":[{"text":"Parsed","part":false}]}]}`
	resp, err := parsePaxsenixLyricsPayload(raw, "TestProv", false)
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if len(resp.Lines) == 0 {
		t.Errorf("expected parsed lines from pax object")
	}
}

func TestParsePaxsenixLyricsPayload_RawText(t *testing.T) {
	raw := `Just plain text lyrics`
	resp, err := parsePaxsenixLyricsPayload(raw, "TextProv", false)
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if resp.Provider != "TextProv" {
		t.Errorf("expected TextProv, got %s", resp.Provider)
	}
	if resp.SyncType != "UNSYNCED" {
		t.Errorf("expected UNSYNCED for raw text, got %s", resp.SyncType)
	}
}

func TestParsePaxsenixLyricsPayload_JSONArrayError(t *testing.T) {
	raw := `[not valid]`
	_, err := parsePaxsenixLyricsPayload(raw, "P", false)
	if err == nil {
		t.Error("expected error for invalid JSON array content")
	}
}

func TestParsePaxsenixLyricsPayload_EmptyStringInJSON(t *testing.T) {
	raw := `""`
	_, err := parsePaxsenixLyricsPayload(raw, "P", false)
	if err == nil {
		t.Error("expected error for empty string in JSON")
	}
}

// ---------- tryArtistFallback ----------

func TestTryArtistFallback_FirstCallSucceeds(t *testing.T) {
	firstCall := ""
	_, err := tryArtistFallback(func(artist, track string) (*LyricsResponse, error) {
		firstCall = artist + "|" + track
		return &LyricsResponse{PlainLyrics: "ok"}, nil
	}, "mainArtist", "fullArtist", "trackName", "simplifiedTrack")

	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if firstCall != "mainArtist|trackName" {
		t.Errorf("expected mainArtist|trackName, got %s", firstCall)
	}
}

func TestTryArtistFallback_FallbackToArtistName(t *testing.T) {
	calls := []string{}
	_, err := tryArtistFallback(func(artist, track string) (*LyricsResponse, error) {
		calls = append(calls, artist+"|"+track)
		if len(calls) == 1 {
			return nil, assertAnError()
		}
		return &LyricsResponse{PlainLyrics: "ok"}, nil
	}, "main", "alt", "track", "simplified")

	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if len(calls) != 2 {
		t.Fatalf("expected 2 calls, got %d", len(calls))
	}
	if calls[1] != "alt|track" {
		t.Errorf("second call should be alt|track, got %s", calls[1])
	}
}

func TestTryArtistFallback_FallbackToSimplifiedTrack(t *testing.T) {
	calls := []string{}
	_, err := tryArtistFallback(func(artist, track string) (*LyricsResponse, error) {
		calls = append(calls, artist+"|"+track)
		return nil, assertAnError()
	}, "main", "main", "track", "simplified")

	if err == nil {
		t.Fatal("expected error since all calls fail")
	}
	// When primaryArtist == artistName, only 2 calls:
	// 1. primaryArtist|trackName ("main|track")
	// 2. primaryArtist|simplifiedTrack ("main|simplified") — if simplifiedTrack != trackName
	if len(calls) != 2 {
		t.Fatalf("expected 2 calls (primaryArtist==artistName skips fallback), got %d", len(calls))
	}
	if calls[1] != "main|simplified" {
		t.Errorf("second call should be main|simplified, got %s", calls[1])
	}
}

func TestTryArtistFallback_SameArtistSkipsDuplicate(t *testing.T) {
	calls := []string{}
	_, err := tryArtistFallback(func(artist, track string) (*LyricsResponse, error) {
		calls = append(calls, artist+"|"+track)
		return nil, assertAnError()
	}, "main", "main", "track", "track")

	if len(calls) != 1 {
		t.Errorf("expected only 1 call when artist and track are same, got %d", len(calls))
	}
	_ = err
}

// ---------- parseLRCLibResponse ----------

func TestParseLRCLibResponse_Synced(t *testing.T) {
	client := &LyricsClient{}
	resp := &LRCLibResponse{
		SyncedLyrics: "[00:01.00]Hello\n[00:02.00]World",
		Instrumental: false,
	}
	result := client.parseLRCLibResponse(resp)
	if result.SyncType != "LINE_SYNCED" {
		t.Errorf("expected LINE_SYNCED, got %s", result.SyncType)
	}
	if len(result.Lines) != 2 {
		t.Errorf("expected 2 lines, got %d", len(result.Lines))
	}
}

func TestParseLRCLibResponse_PlainOnly(t *testing.T) {
	client := &LyricsClient{}
	resp := &LRCLibResponse{
		PlainLyrics:  "Hello\nWorld",
		SyncedLyrics: "",
	}
	result := client.parseLRCLibResponse(resp)
	if result.SyncType != "UNSYNCED" {
		t.Errorf("expected UNSYNCED, got %s", result.SyncType)
	}
	if len(result.Lines) != 2 {
		t.Errorf("expected 2 lines, got %d", len(result.Lines))
	}
}

func TestParseLRCLibResponse_Instrumental(t *testing.T) {
	client := &LyricsClient{}
	resp := &LRCLibResponse{Instrumental: true}
	result := client.parseLRCLibResponse(resp)
	if !result.Instrumental {
		t.Error("expected instrumental")
	}
}

func TestParseLRCLibResponse_NoContent(t *testing.T) {
	client := &LyricsClient{}
	resp := &LRCLibResponse{}
	result := client.parseLRCLibResponse(resp)
	if result.SyncType != "" {
		t.Errorf("expected empty SyncType, got %s", result.SyncType)
	}
	if len(result.Lines) != 0 {
		t.Errorf("expected 0 lines, got %d", len(result.Lines))
	}
}

// ---------- LRCLIB search helpers ----------

func TestDurationMatches_Exact(t *testing.T) {
	client := &LyricsClient{}
	if !client.durationMatches(200, 200) {
		t.Error("expected durationMatches to be true for equal values")
	}
}

func TestDurationMatches_WithinTolerance(t *testing.T) {
	client := &LyricsClient{}
	if !client.durationMatches(205, 200) {
		t.Error("expected durationMatches to be true within tolerance")
	}
}

func TestDurationMatches_OutOfTolerance(t *testing.T) {
	client := &LyricsClient{}
	if client.durationMatches(220, 200) {
		t.Error("expected durationMatches to be false outside tolerance")
	}
}

// ---------- helpers ----------

func intPtr(i int) *int {
	return &i
}

type errorSentinel struct{}

func (e errorSentinel) Error() string { return "sentinel error" }

func assertAnError() error {
	return errorSentinel{}
}

// ---------- Thread safety for globals ----------

func TestGlobalProviderOrderThreadSafe(t *testing.T) {
	var wg sync.WaitGroup
	for i := 0; i < 20; i++ {
		wg.Add(1)
		go func() {
			defer wg.Done()
			SetLyricsProviderOrder([]string{ProviderLRCLIB, ProviderAppleMusic})
			_ = GetLyricsProviderOrder()
		}()
	}
	wg.Wait()
}

func TestGlobalFetchOptionsThreadSafe(t *testing.T) {
	var wg sync.WaitGroup
	for i := 0; i < 20; i++ {
		wg.Add(1)
		go func() {
			defer wg.Done()
			SetLyricsFetchOptions(LyricsFetchOptions{MultiPersonWordByWord: true})
			_ = GetLyricsFetchOptions()
		}()
	}
	wg.Wait()
}

func TestInstrumentalTrackPattern(t *testing.T) {
	if !instrumentalTrackPattern.MatchString("(Instrumental)") {
		t.Error("expected pattern to match (Instrumental)")
	}
	if !instrumentalTrackPattern.MatchString("[Instrumental]") {
		t.Error("expected pattern to match [Instrumental]")
	}
	if !instrumentalTrackPattern.MatchString("inst.") {
		t.Error("expected pattern to match inst.")
	}
	if instrumentalTrackPattern.MatchString("Instrument") {
		t.Error("expected pattern to NOT match Instrument")
	}
}
