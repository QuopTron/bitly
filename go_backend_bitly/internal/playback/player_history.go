package playback

func addToHistory(ps *PlaybackState, track PlaybackTrack) {
	if len(ps.History) > 0 && ps.History[len(ps.History)-1].ID == track.ID {
		return
	}
	ps.History = append(ps.History, track)
	if len(ps.History) > 50 {
		ps.History = ps.History[len(ps.History)-50:]
	}
}
