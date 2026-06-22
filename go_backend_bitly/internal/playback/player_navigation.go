package playback

import "time"

func advanceNext(ps *PlaybackState) {
	if len(ps.Queue) == 0 {
		if ps.CurrentTrack != nil {
			addToHistory(ps, *ps.CurrentTrack)
		}
		ps.CurrentTrack = nil
		ps.IsPlaying = false
		return
	}

	if ps.RepeatMode == "one" && ps.CurrentTrack != nil {
		ps.Position = 0
		return
	}

	if ps.CurrentTrack != nil {
		addToHistory(ps, *ps.CurrentTrack)
	}

	if ps.Shuffle {
		if len(ps.Queue) > 1 && ps.CurrentTrack != nil {
			for {
				idx := int(time.Now().UnixNano() % int64(len(ps.Queue)))
				if ps.Queue[idx].ID != ps.CurrentTrack.ID {
					ps.QueueIndex = idx
					break
				}
			}
		} else {
			ps.QueueIndex = int(time.Now().UnixNano() % int64(len(ps.Queue)))
		}
		ps.CurrentTrack = &ps.Queue[ps.QueueIndex]
		ps.Position = 0
		ps.Duration = int64(ps.CurrentTrack.Duration)
		ps.IsPlaying = true
		return
	}

	if ps.QueueIndex < len(ps.Queue)-1 {
		ps.QueueIndex++
		ps.CurrentTrack = &ps.Queue[ps.QueueIndex]
		ps.Position = 0
		ps.Duration = int64(ps.CurrentTrack.Duration)
		ps.IsPlaying = true
	} else if ps.RepeatMode == "all" {
		ps.QueueIndex = 0
		ps.CurrentTrack = &ps.Queue[0]
		ps.Position = 0
		ps.Duration = int64(ps.CurrentTrack.Duration)
		ps.IsPlaying = true
	} else {
		ps.CurrentTrack = nil
		ps.IsPlaying = false
	}
}

func goPrevious(ps *PlaybackState) {
	if len(ps.History) == 0 {
		if ps.QueueIndex > 0 && len(ps.Queue) > 0 {
			ps.QueueIndex--
			ps.CurrentTrack = &ps.Queue[ps.QueueIndex]
			ps.Position = 0
			ps.Duration = int64(ps.CurrentTrack.Duration)
			ps.IsPlaying = true
		}
		return
	}

	prevTrack := ps.History[len(ps.History)-1]
	ps.History = ps.History[:len(ps.History)-1]

	if ps.CurrentTrack != nil {
		found := false
		for _, t := range ps.Queue {
			if t.ID == ps.CurrentTrack.ID {
				found = true
				break
			}
		}
		if !found {
			ps.Queue = append(ps.Queue[:ps.QueueIndex], append([]PlaybackTrack{*ps.CurrentTrack}, ps.Queue[ps.QueueIndex:]...)...)
		}
	}

	for i, t := range ps.Queue {
		if t.ID == prevTrack.ID {
			ps.QueueIndex = i
			break
		}
	}
	ps.CurrentTrack = &prevTrack
	ps.Position = 0
	ps.Duration = int64(prevTrack.Duration)
	ps.IsPlaying = true
}
