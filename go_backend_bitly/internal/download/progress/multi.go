package progress

import "encoding/json"

func GetProgress() DownloadProgress {
	multiMu.RLock()
	defer multiMu.RUnlock()

	for _, item := range multiProgress.Items {
		return DownloadProgress{
			CurrentFile:   item.ItemID,
			Progress:      item.Progress * 100,
			BytesTotal:    item.BytesTotal,
			BytesReceived: item.BytesReceived,
			IsDownloading: item.IsDownloading,
			Status:        item.Status,
		}
	}
	return DownloadProgress{}
}

func GetMultiProgress() string {
	multiMu.RLock()
	if !multiProgressDirty {
		cached := cachedMultiProgress
		multiMu.RUnlock()
		return cached
	}
	multiMu.RUnlock()

	multiMu.Lock()
	defer multiMu.Unlock()
	if !multiProgressDirty {
		return cachedMultiProgress
	}
	jsonBytes, err := json.Marshal(multiProgress)
	if err != nil {
		return `{"items":{}}`
	}
	cachedMultiProgress = string(jsonBytes)
	multiProgressDirty = false
	return cachedMultiProgress
}

func GetMultiProgressDelta(sinceSeq int64) string {
	multiMu.RLock()
	currentSeq := multiProgressSeq
	if sinceSeq >= currentSeq {
		multiMu.RUnlock()
		return ""
	}

	reset := sinceSeq <= 0 || sinceSeq < multiProgressReset
	delta := MultiProgressDelta{
		Seq:   currentSeq,
		Reset: reset,
	}
	if reset {
		if len(multiProgress.Items) > 0 {
			delta.Items = make(map[string]*ItemProgress, len(multiProgress.Items))
			for id, item := range multiProgress.Items {
				cp := *item
				cp.revision = 0
				delta.Items[id] = &cp
			}
		}
	} else {
		for id, item := range multiProgress.Items {
			if item.revision > sinceSeq {
				if delta.Items == nil {
					delta.Items = make(map[string]*ItemProgress)
				}
				cp := *item
				cp.revision = 0
				delta.Items[id] = &cp
			}
		}
		for id, revision := range removedProgressSeq {
			if revision > sinceSeq {
				delta.Removed = append(delta.Removed, id)
			}
		}
	}
	multiMu.RUnlock()

	jsonBytes, err := json.Marshal(delta)
	if err != nil {
		return ""
	}
	return string(jsonBytes)
}

func GetItemProgress(itemID string) string {
	multiMu.RLock()
	defer multiMu.RUnlock()
	if item, ok := multiProgress.Items[itemID]; ok {
		jsonBytes, _ := json.Marshal(item)
		return string(jsonBytes)
	}
	return "{}"
}
