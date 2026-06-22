package utils

import "strconv"

func getDateValue(metadata map[string]interface{}) string {
	date := getString(metadata, "date")
	if date != "" {
		return date
	}
	releaseDate := getString(metadata, "release_date")
	if releaseDate != "" {
		return releaseDate
	}
	return getString(metadata, "year")
}

func getString(m map[string]interface{}, key string) string {
	if v, ok := m[key]; ok {
		switch value := v.(type) {
		case string:
			return value
		case int:
			return strconv.Itoa(value)
		case int64:
			return strconv.FormatInt(value, 10)
		case float64:
			return strconv.Itoa(int(value))
		}
	}
	return ""
}

func getInt(m map[string]interface{}, key string) int {
	candidateKeys := []string{key}
	switch key {
	case "track":
		candidateKeys = append(candidateKeys, "track_number")
	case "disc":
		candidateKeys = append(candidateKeys, "disc_number")
	}

	for _, candidate := range candidateKeys {
		if v, ok := m[candidate]; ok {
			switch n := v.(type) {
			case int:
				return n
			case int64:
				return int(n)
			case float64:
				return int(n)
			case string:
				parsed, err := strconv.Atoi(n)
				if err == nil {
					return parsed
				}
			}
		}
	}

	return 0
}
