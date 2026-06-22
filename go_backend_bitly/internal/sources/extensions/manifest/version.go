package manifest

import (
	"encoding/json"
	"fmt"
	"strings"
)

func CompareVersions(v1, v2 string) int {
	v1Parts := strings.Split(strings.TrimPrefix(v1, "v"), ".")
	v2Parts := strings.Split(strings.TrimPrefix(v2, "v"), ".")

	maxLen := len(v1Parts)
	if len(v2Parts) > maxLen {
		maxLen = len(v2Parts)
	}

	var n1, n2 int
	for i := 0; i < maxLen; i++ {
		n1, n2 = 0, 0
		if i < len(v1Parts) {
			fmt.Sscanf(v1Parts[i], "%d", &n1)
		}
		if i < len(v2Parts) {
			fmt.Sscanf(v2Parts[i], "%d", &n2)
		}
		if n1 < n2 {
			return -1
		}
		if n1 > n2 {
			return 1
		}
	}
	return 0
}

func (m *ExtensionManifest) ToJSON() ([]byte, error) {
	return json.Marshal(m)
}
