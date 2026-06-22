package lyrics

import (
	"fmt"
	"strconv"
	"strings"
)

func LrcTimestampToMs(minutes, seconds, centiseconds string) int64 {
	min, _ := strconv.ParseInt(minutes, 10, 64)
	sec, _ := strconv.ParseInt(seconds, 10, 64)
	cs, _ := strconv.ParseInt(centiseconds, 10, 64)
	if len(centiseconds) == 2 {
		cs *= 10
	}
	return min*60*1000 + sec*1000 + cs
}

func MsToLRCTimestamp(ms int64) string {
	totalSeconds := ms / 1000
	minutes := totalSeconds / 60
	seconds := totalSeconds % 60
	cs := (ms % 1000) / 10
	return fmt.Sprintf("[%02d:%02d.%02d]", minutes, seconds, cs)
}

func ConvertToLRCWithMetadata(lyrics *LyricsResponse, trackName, artistName string) string {
	if lyrics == nil || len(lyrics.Lines) == 0 {
		return ""
	}
	var b strings.Builder
	b.WriteString(fmt.Sprintf("[ti:%s]\n", trackName))
	b.WriteString(fmt.Sprintf("[ar:%s]\n", artistName))
	b.WriteString("[by:Implemented by Bitly using Paxsenix API]\n\n")

	if lyrics.SyncType == "LINE_SYNCED" {
		for _, line := range lyrics.Lines {
			if line.Words == "" {
				continue
			}
			b.WriteString(MsToLRCTimestamp(line.StartTimeMs))
			b.WriteString(line.Words)
			b.WriteString("\n")
		}
	} else {
		for _, line := range lyrics.Lines {
			if line.Words == "" {
				continue
			}
			b.WriteString(line.Words)
			b.WriteString("\n")
		}
	}
	return b.String()
}
