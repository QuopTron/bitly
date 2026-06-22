package progress

import (
	"math"
	"sync"
)

type DownloadProgress struct {
	CurrentFile   string  `json:"current_file"`
	Progress      float64 `json:"progress"`
	Speed         float64 `json:"speed_mbps"`
	BytesTotal    int64   `json:"bytes_total"`
	BytesReceived int64   `json:"bytes_received"`
	IsDownloading bool    `json:"is_downloading"`
	Status        string  `json:"status"`
}

type ItemProgress struct {
	ItemID        string  `json:"item_id"`
	BytesTotal    int64   `json:"bytes_total"`
	BytesReceived int64   `json:"bytes_received"`
	Progress      float64 `json:"progress"`
	SpeedMBps     float64 `json:"speed_mbps"`
	IsDownloading bool    `json:"is_downloading"`
	Status        string  `json:"status"`
	revision      int64
}

const (
	itemProgressStatusPreparing   = "preparing"
	itemProgressStatusDownloading = "downloading"
	itemProgressStatusCompleted   = "completed"
	itemProgressStatusFinalizing  = "finalizing"
)

type MultiProgress struct {
	Items map[string]*ItemProgress `json:"items"`
}

type MultiProgressDelta struct {
	Seq     int64                    `json:"seq"`
	Reset   bool                     `json:"reset,omitempty"`
	Items   map[string]*ItemProgress `json:"items,omitempty"`
	Removed []string                 `json:"removed,omitempty"`
}

type progressBridgeState struct {
	bytesBucket   int64
	bytesTotal    int64
	progressPct   int64
	speedDeciMBps int64
	downloading   bool
	status        string
}

var (
	multiProgress       = MultiProgress{Items: make(map[string]*ItemProgress)}
	multiMu             sync.RWMutex
	multiProgressDirty  = true
	cachedMultiProgress = `{"items":{}}`
	multiProgressSeq    int64
	multiProgressReset  int64
	removedProgressSeq  = make(map[string]int64)
)

const progressUpdateThreshold = 128 * 1024

func markMultiProgressDirtyLocked() {
	multiProgressDirty = true
}

func nextMultiProgressSeqLocked() int64 {
	multiProgressSeq++
	return multiProgressSeq
}

func itemProgressBridgeState(item *ItemProgress) progressBridgeState {
	progress := item.Progress
	if math.IsNaN(progress) || progress <= 0 {
		progress = 0
	} else if progress >= 1 {
		progress = 1
	}
	speed := item.SpeedMBps
	if math.IsNaN(speed) || speed <= 0 {
		speed = 0
	}
	return progressBridgeState{
		bytesBucket:   item.BytesReceived / progressUpdateThreshold,
		bytesTotal:    item.BytesTotal,
		progressPct:   int64(math.Round(progress * 100)),
		speedDeciMBps: int64(math.Round(speed * 10)),
		downloading:   item.IsDownloading,
		status:        item.Status,
	}
}

func markMultiProgressDirtyIfChangedLocked(item *ItemProgress, before progressBridgeState) {
	if itemProgressBridgeState(item) != before {
		item.revision = nextMultiProgressSeqLocked()
		markMultiProgressDirtyLocked()
	}
}
