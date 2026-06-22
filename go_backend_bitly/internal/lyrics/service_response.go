package lyrics

func lyricsResponseFromText(text, provider string) *LyricsResponse {
	lines := ParseSyncedLyrics(text)
	if len(lines) > 0 {
		return &LyricsResponse{
			Lines:       lines,
			SyncType:    "LINE_SYNCED",
			PlainLyrics: PlainLyricsFromTimedLines(lines),
			Provider:    provider,
			Source:      provider,
		}
	}

	plainLines := PlainTextLyricsLines(text)
	if len(plainLines) > 0 {
		return &LyricsResponse{
			Lines:       plainLines,
			SyncType:    "UNSYNCED",
			PlainLyrics: text,
			Provider:    provider,
			Source:      provider,
		}
	}
	return &LyricsResponse{Provider: provider, Source: provider}
}
