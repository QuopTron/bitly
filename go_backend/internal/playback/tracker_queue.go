package playback

// Queue returns the current playback queue.
func (t *Tracker) Queue() []QueueItem {
	t.mu.RLock()
	defer t.mu.RUnlock()
	result := make([]QueueItem, len(t.queue))
	copy(result, t.queue)
	return result
}

// AddToQueue adds a track to the end of the queue.
func (t *Tracker) AddToQueue(track *TrackInfo, addedBy string) {
	t.mu.Lock()
	defer t.mu.Unlock()
	item := QueueItem{
		Track:    *track,
		AddedBy:  addedBy,
		Position: len(t.queue),
	}
	t.queue = append(t.queue, item)
}

// RemoveFromQueue removes a track from queue by position.
func (t *Tracker) RemoveFromQueue(position int) bool {
	t.mu.Lock()
	defer t.mu.Unlock()
	if position < 0 || position >= len(t.queue) {
		return false
	}
	t.queue = append(t.queue[:position], t.queue[position+1:]...)
	for i := range t.queue {
		t.queue[i].Position = i
	}
	return true
}

// ClearQueue empties the queue.
func (t *Tracker) ClearQueue() {
	t.mu.Lock()
	defer t.mu.Unlock()
	t.queue = nil
}

// ReorderQueue moves a track from oldPos to newPos.
func (t *Tracker) ReorderQueue(oldPos, newPos int) bool {
	t.mu.Lock()
	defer t.mu.Unlock()
	if oldPos < 0 || oldPos >= len(t.queue) || newPos < 0 || newPos >= len(t.queue) {
		return false
	}
	item := t.queue[oldPos]
	t.queue = append(t.queue[:oldPos], t.queue[oldPos+1:]...)
	t.queue = append(t.queue[:newPos], append([]QueueItem{item}, t.queue[newPos:]...)...)
	for i := range t.queue {
		t.queue[i].Position = i
	}
	return true
}
