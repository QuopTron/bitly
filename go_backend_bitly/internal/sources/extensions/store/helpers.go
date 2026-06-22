package store

import (
	"strings"
)

func containsIgnoreCase(s, substr string) bool {
	return len(substr) == 0 || (len(s) >= len(substr) && strings.Contains(strings.ToLower(s), substr))
}


