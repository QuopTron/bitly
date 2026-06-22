package utils

import "strings"

func TitlesMatch(expectedTitle, foundTitle string) bool {
	normExpected := strings.ToLower(strings.TrimSpace(expectedTitle))
	normFound := strings.ToLower(strings.TrimSpace(foundTitle))

	if normExpected == normFound {
		return true
	}
	if strings.Contains(normExpected, normFound) || strings.Contains(normFound, normExpected) {
		return true
	}

	cleanExpected := CleanTitle(normExpected)
	cleanFound := CleanTitle(normFound)
	if cleanExpected == cleanFound {
		return true
	}
	if cleanExpected != "" && cleanFound != "" {
		if strings.Contains(cleanExpected, cleanFound) || strings.Contains(cleanFound, cleanExpected) {
			return true
		}
	}

	coreExpected := ExtractCoreTitle(normExpected)
	coreFound := ExtractCoreTitle(normFound)
	if coreExpected != "" && coreFound != "" && coreExpected == coreFound {
		return true
	}

	looseExpected := NormalizeLooseTitle(normExpected)
	looseFound := NormalizeLooseTitle(normFound)
	if looseExpected != "" && looseFound != "" {
		if looseExpected == looseFound || strings.Contains(looseExpected, looseFound) || strings.Contains(looseFound, looseExpected) {
			return true
		}
	}

	// Symbol-only fallback: if one or both titles lack alphanumeric chars (e.g. emoji),
	// compare only the non-text symbols.
	if (!hasAlphaNumericRunes(expectedTitle) || !hasAlphaNumericRunes(foundTitle)) &&
		strings.TrimSpace(expectedTitle) != "" &&
		strings.TrimSpace(foundTitle) != "" {
		expectedSymbols := normalizeSymbolOnlyTitle(expectedTitle)
		foundSymbols := normalizeSymbolOnlyTitle(foundTitle)
		if expectedSymbols != "" &&
			foundSymbols != "" &&
			expectedSymbols == foundSymbols {
			return true
		}
	}

	return false
}

var versionPatterns = []string{
	"remaster", "remastered", "deluxe", "bonus", "single",
	"album version", "radio edit", "original mix", "extended",
	"club mix", "remix", "live", "acoustic", "demo",
}

func CleanTitle(title string) string {
	cleaned := title

	for {
		startParen := strings.LastIndex(cleaned, "(")
		endParen := strings.LastIndex(cleaned, ")")
		if startParen >= 0 && endParen > startParen {
			content := strings.ToLower(cleaned[startParen+1 : endParen])
			isVersionIndicator := false
			for _, pattern := range versionPatterns {
				if strings.Contains(content, pattern) {
					isVersionIndicator = true
					break
				}
			}
			if isVersionIndicator {
				cleaned = strings.TrimSpace(cleaned[:startParen]) + cleaned[endParen+1:]
				continue
			}
		}
		break
	}

	for {
		startBracket := strings.LastIndex(cleaned, "[")
		endBracket := strings.LastIndex(cleaned, "]")
		if startBracket >= 0 && endBracket > startBracket {
			content := strings.ToLower(cleaned[startBracket+1 : endBracket])
			isVersionIndicator := false
			for _, pattern := range versionPatterns {
				if strings.Contains(content, pattern) {
					isVersionIndicator = true
					break
				}
			}
			if isVersionIndicator {
				cleaned = strings.TrimSpace(cleaned[:startBracket]) + cleaned[endBracket+1:]
				continue
			}
		}
		break
	}

	// Remove dash-prefixed version indicators (e.g. " - remaster", " - single version")
	dashPatterns := []string{
		" - remaster", " - remastered", " - single version", " - radio edit",
		" - live", " - acoustic", " - demo", " - remix",
	}
	for _, pattern := range dashPatterns {
		if strings.HasSuffix(strings.ToLower(cleaned), pattern) {
			cleaned = cleaned[:len(cleaned)-len(pattern)]
		}
	}

	for strings.Contains(cleaned, "  ") {
		cleaned = strings.ReplaceAll(cleaned, "  ", " ")
	}

	return strings.TrimSpace(cleaned)
}

func ExtractCoreTitle(title string) string {
	parenIdx := strings.Index(title, "(")
	bracketIdx := strings.Index(title, "[")
	dashIdx := strings.Index(title, " - ")

	cutIdx := len(title)
	if parenIdx > 0 && parenIdx < cutIdx {
		cutIdx = parenIdx
	}
	if bracketIdx > 0 && bracketIdx < cutIdx {
		cutIdx = bracketIdx
	}
	if dashIdx > 0 && dashIdx < cutIdx {
		cutIdx = dashIdx
	}

	return strings.TrimSpace(title[:cutIdx])
}
