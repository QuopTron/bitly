package progress

func StartItemProgress(itemID string) {
	multiMu.Lock()
	defer multiMu.Unlock()
	multiProgress.Items[itemID] = &ItemProgress{
		ItemID:   itemID,
		Status:   itemProgressStatusPreparing,
		revision: nextMultiProgressSeqLocked(),
	}
	delete(removedProgressSeq, itemID)
	markMultiProgressDirtyLocked()
}

func CompleteItemProgress(itemID string) {
	multiMu.Lock()
	defer multiMu.Unlock()
	if item, ok := multiProgress.Items[itemID]; ok {
		before := itemProgressBridgeState(item)
		item.Progress = 1.0
		item.IsDownloading = false
		item.Status = itemProgressStatusCompleted
		markMultiProgressDirtyIfChangedLocked(item, before)
	}
}

func RemoveItemProgress(itemID string) {
	multiMu.Lock()
	defer multiMu.Unlock()
	if _, ok := multiProgress.Items[itemID]; ok {
		delete(multiProgress.Items, itemID)
		removedProgressSeq[itemID] = nextMultiProgressSeqLocked()
	}
	markMultiProgressDirtyLocked()
}

func ClearAllItemProgress() {
	multiMu.Lock()
	defer multiMu.Unlock()
	multiProgress.Items = make(map[string]*ItemProgress)
	removedProgressSeq = make(map[string]int64)
	multiProgressReset = nextMultiProgressSeqLocked()
	markMultiProgressDirtyLocked()
}
