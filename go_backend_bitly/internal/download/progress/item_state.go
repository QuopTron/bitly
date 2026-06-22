package progress

func SetItemPreparing(itemID string) {
	multiMu.Lock()
	defer multiMu.Unlock()
	if item, ok := multiProgress.Items[itemID]; ok {
		before := itemProgressBridgeState(item)
		item.Progress = 0
		item.BytesReceived = 0
		item.BytesTotal = 0
		item.SpeedMBps = 0
		item.IsDownloading = true
		item.Status = itemProgressStatusPreparing
		markMultiProgressDirtyIfChangedLocked(item, before)
	}
}

func SetItemDownloading(itemID string) {
	multiMu.Lock()
	defer multiMu.Unlock()
	if item, ok := multiProgress.Items[itemID]; ok {
		before := itemProgressBridgeState(item)
		item.IsDownloading = true
		item.Status = itemProgressStatusDownloading
		markMultiProgressDirtyIfChangedLocked(item, before)
	}
}

func SetItemBytesTotal(itemID string, total int64) {
	multiMu.Lock()
	defer multiMu.Unlock()
	if item, ok := multiProgress.Items[itemID]; ok {
		before := itemProgressBridgeState(item)
		item.BytesTotal = total
		markMultiProgressDirtyIfChangedLocked(item, before)
	}
}

func SetItemBytesReceived(itemID string, received int64) {
	multiMu.Lock()
	defer multiMu.Unlock()
	if item, ok := multiProgress.Items[itemID]; ok {
		before := itemProgressBridgeState(item)
		item.BytesReceived = received
		if item.BytesTotal > 0 {
			item.Progress = float64(received) / float64(item.BytesTotal)
		}
		if received > 0 {
			item.IsDownloading = true
			item.Status = itemProgressStatusDownloading
		}
		markMultiProgressDirtyIfChangedLocked(item, before)
	}
}

func SetItemBytesReceivedWithSpeed(itemID string, received int64, speedMBps float64) {
	multiMu.Lock()
	defer multiMu.Unlock()
	if item, ok := multiProgress.Items[itemID]; ok {
		before := itemProgressBridgeState(item)
		item.BytesReceived = received
		item.SpeedMBps = speedMBps
		if item.BytesTotal > 0 {
			item.Progress = float64(received) / float64(item.BytesTotal)
		}
		if received > 0 {
			item.IsDownloading = true
			item.Status = itemProgressStatusDownloading
		}
		markMultiProgressDirtyIfChangedLocked(item, before)
	}
}

func SetItemProgress(itemID string, progress float64, bytesReceived, bytesTotal int64) {
	multiMu.Lock()
	defer multiMu.Unlock()
	if item, ok := multiProgress.Items[itemID]; ok {
		before := itemProgressBridgeState(item)
		hasByteProgress := bytesReceived > 0 || bytesTotal > 0
		if item.Status != itemProgressStatusPreparing || hasByteProgress || progress >= 1 {
			item.Progress = progress
		} else {
			item.Progress = 0
		}
		if bytesReceived > 0 {
			item.BytesReceived = bytesReceived
		}
		if bytesTotal > 0 {
			item.BytesTotal = bytesTotal
		}
		if hasByteProgress || progress >= 1 || item.Status == itemProgressStatusDownloading {
			item.IsDownloading = true
			item.Status = itemProgressStatusDownloading
		}
		markMultiProgressDirtyIfChangedLocked(item, before)
	}
}

func SetItemFinalizing(itemID string) {
	multiMu.Lock()
	defer multiMu.Unlock()
	if item, ok := multiProgress.Items[itemID]; ok {
		before := itemProgressBridgeState(item)
		item.Progress = 1.0
		item.Status = itemProgressStatusFinalizing
		markMultiProgressDirtyIfChangedLocked(item, before)
	}
}
