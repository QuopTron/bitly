package download

func (t *Tracker) Get(itemID string) *Progress {
	t.mu.Lock()
	defer t.mu.Unlock()
	if p, ok := t.items[itemID]; ok {
		cp := *p
		return &cp
	}
	return nil
}

// GetAll returns progress for all items.
func (t *Tracker) GetAll() []Progress {
	t.mu.Lock()
	defer t.mu.Unlock()
	result := make([]Progress, 0, len(t.items))
	for _, p := range t.items {
		result = append(result, *p)
	}
	return result
}

// Remove deletes a progress entry.
func (t *Tracker) Remove(itemID string) {
	t.mu.Lock()
	delete(t.items, itemID)
	t.mu.Unlock()
}
