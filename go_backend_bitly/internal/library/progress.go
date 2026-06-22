package library

import "encoding/json"

func GetLibraryScanProgress() string {
	libraryScanProgressMu.RLock()
	defer libraryScanProgressMu.RUnlock()
	jsonBytes, _ := json.Marshal(libraryScanProgress)
	return string(jsonBytes)
}

func CancelLibraryScan() {
	libraryScanCancelMu.Lock()
	defer libraryScanCancelMu.Unlock()
	if libraryScanCancel != nil {
		close(libraryScanCancel)
		libraryScanCancel = nil
	}
}
