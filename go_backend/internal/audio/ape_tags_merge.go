package audio

func MergeAPEItems(existing, newItems []APETagItem) []APETagItem {
	merged := make([]APETagItem, len(existing))
	copy(merged, existing)

	for _, ni := range newItems {
		found := false
		for i, ei := range merged {
			if ei.Key == ni.Key {
				merged[i] = ni
				found = true
				break
			}
		}
		if !found {
			merged = append(merged, ni)
		}
	}
	return merged
}
