package utils

import (
	"fmt"
	"strings"
	"time"
)

func FormatDuration(ms int64) string {
	d := time.Duration(ms) * time.Millisecond
	h := int(d.Hours())
	m := int(d.Minutes()) % 60
	s := int(d.Seconds()) % 60
	if h > 0 {
		return fmt.Sprintf("%d:%02d:%02d", h, m, s)
	}
	return fmt.Sprintf("%d:%02d", m, s)
}

func ParseDuration(s string) (int64, error) {
	var h, m, sec int
	switch strings.Count(s, ":") {
	case 2:
		if _, err := fmt.Sscanf(s, "%d:%02d:%02d", &h, &m, &sec); err != nil {
			return 0, err
		}
	case 1:
		if _, err := fmt.Sscanf(s, "%d:%02d", &m, &sec); err != nil {
			return 0, err
		}
	default:
		return 0, fmt.Errorf("invalid duration format: %s", s)
	}
	return int64(h)*3600000 + int64(m)*60000 + int64(sec)*1000, nil
}
