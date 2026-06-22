package progress

import "time"

type ItemProgressWriter struct {
	writer       interface{ Write([]byte) (int, error) }
	itemID       string
	current      int64
	lastReported int64
	startTime    time.Time
	lastTime     time.Time
	lastBytes    int64
	isCancelled  func(string) bool
}

func NewItemProgressWriter(w interface{ Write([]byte) (int, error) }, itemID string) *ItemProgressWriter {
	now := time.Now()
	return &ItemProgressWriter{
		writer:       w,
		itemID:       itemID,
		current:      0,
		lastReported: 0,
		startTime:    now,
		lastTime:     now,
		lastBytes:    0,
	}
}

func NewItemProgressWriterWithCancel(w interface{ Write([]byte) (int, error) }, itemID string, isCancelled func(string) bool) *ItemProgressWriter {
	now := time.Now()
	return &ItemProgressWriter{
		writer:       w,
		itemID:       itemID,
		current:      0,
		lastReported: 0,
		startTime:    now,
		lastTime:     now,
		lastBytes:    0,
		isCancelled:  isCancelled,
	}
}

func (pw *ItemProgressWriter) Write(p []byte) (int, error) {
	if pw.itemID != "" && pw.isCancelled != nil && pw.isCancelled(pw.itemID) {
		return 0, ErrDownloadCancelled
	}
	n, err := pw.writer.Write(p)
	if err != nil {
		return n, err
	}
	pw.current += int64(n)

	if pw.lastReported == 0 || pw.current-pw.lastReported >= progressUpdateThreshold {
		now := time.Now()
		elapsed := now.Sub(pw.lastTime).Seconds()
		var speedMBps float64
		if elapsed > 0 {
			bytesInInterval := pw.current - pw.lastBytes
			speedMBps = float64(bytesInInterval) / (1024 * 1024) / elapsed
		}
		SetItemBytesReceivedWithSpeed(pw.itemID, pw.current, speedMBps)
		pw.lastReported = pw.current
		pw.lastTime = now
		pw.lastBytes = pw.current
	}
	return n, nil
}

var ErrDownloadCancelled = &ProgressError{Message: "download cancelled"}

type ProgressError struct {
	Message string
}

func (e *ProgressError) Error() string { return e.Message }
