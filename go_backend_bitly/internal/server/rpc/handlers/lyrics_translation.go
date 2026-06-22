package handlers

import (
	"bytes"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"strings"
	"time"

	"github.com/zarz/bitly/go_backend_bitly/internal/server/rpc"
	"github.com/zarz/bitly/go_backend_bitly/internal/storage/database"
)

// lyricsTranslationClient is an HTTP client reused for translation requests.
var lyricsTranslationClient = &http.Client{
	Timeout: 30 * time.Second,
}

// defaultTranslationEndpoint is a sensible default if none is configured.
const defaultTranslationEndpoint = "https://libretranslate.com/translate"

// registerLyricsTranslationHandlers registers lyrics translation RPC methods.
func registerLyricsTranslationHandlers(reg *rpc.Registry) {
	reg.Register("translateLyricsLRC", func(params map[string]interface{}) (interface{}, error) {
		requestJSON := rpc.Sp(params, "request")
		if requestJSON == "" {
			return "", fmt.Errorf("request is required")
		}

		var req struct {
			LRC        string `json:"lrc"`
			TargetLang string `json:"target_lang"`
			SourceLang string `json:"source_lang,omitempty"`
		}
		if err := json.Unmarshal([]byte(requestJSON), &req); err != nil {
			return "", fmt.Errorf("invalid request JSON: %w", err)
		}
		if req.LRC == "" {
			return "", fmt.Errorf("lrc content is required")
		}
		if req.TargetLang == "" {
			return "", fmt.Errorf("target_lang is required")
		}

		// Load translation API config
		config, err := database.LoadTranslationAPIConfig()
		if err != nil {
			return "", fmt.Errorf("failed to load translation config: %w", err)
		}

		endpoint := defaultTranslationEndpoint
		var apiKey string
		if config != nil {
			if config.Endpoint != "" {
				endpoint = config.Endpoint
			}
			apiKey = config.APIKey
		}

		// Translate the LRC content line by line, preserving timestamps
		translatedLRC, err := translateLRCText(req.LRC, req.TargetLang, req.SourceLang, endpoint, apiKey)
		if err != nil {
			return "", fmt.Errorf("translation failed: %w", err)
		}

		result := map[string]interface{}{
			"translated_lrc": translatedLRC,
			"target_lang":    req.TargetLang,
		}
		out, _ := json.Marshal(result)
		return string(out), nil
	})

	reg.Register("setTranslationAPIConfig", func(params map[string]interface{}) (interface{}, error) {
		requestJSON := rpc.Sp(params, "request")
		if requestJSON == "" {
			return "", fmt.Errorf("request is required")
		}

		if err := database.SaveTranslationAPIConfig(requestJSON); err != nil {
			return "", err
		}
		return "ok", nil
	})

	reg.Register("setTranslationLanguageWithDetection", func(params map[string]interface{}) (interface{}, error) {
		lrcContent := rpc.Sp(params, "lrc_content")
		targetLang := rpc.Sp(params, "target_lang")

		if lrcContent == "" {
			return "", fmt.Errorf("lrc_content is required")
		}
		if targetLang == "" {
			return "", fmt.Errorf("target_lang is required")
		}

		// Detect source language
		detectedLang := detectLanguage(lrcContent)

		// Save target language preference
		if err := database.SaveTranslationLanguage(targetLang); err != nil {
			return "", fmt.Errorf("failed to save translation language: %w", err)
		}

		result := map[string]interface{}{
			"detected_lang": detectedLang,
		}
		return result, nil
	})
}

// translateLRCText translates the text portions of an LRC file, keeping timestamp markers intact.
func translateLRCText(lrcContent, targetLang, sourceLang, endpoint, apiKey string) (string, error) {
	lines := strings.Split(lrcContent, "\n")
	var textLines []string
	var lineIndices []int

	// Separate timestamp lines from text-only lines for batched translation
	for i, line := range lines {
		trimmed := strings.TrimSpace(line)
		if trimmed == "" {
			continue
		}
		// Skip metadata tags like [ti:...], [ar:...], [instrumental:...]
		if strings.HasPrefix(trimmed, "[") && strings.Contains(trimmed, ":") && strings.HasSuffix(trimmed, "]") {
			continue
		}
		// Extract text after timestamp(s) like [00:01.23]Some text
		text := extractLRCContent(trimmed)
		if text != "" {
			textLines = append(textLines, text)
			lineIndices = append(lineIndices, i)
		}
	}

	if len(textLines) == 0 {
		// No translatable text found
		return lrcContent, nil
	}

	// Map translated texts back to original lines
	// We use a concurrent approach: translate all texts together in a batch
	translatedTexts, err := callTranslationAPI(textLines, targetLang, sourceLang, endpoint, apiKey)
	if err != nil {
		return "", fmt.Errorf("translation API call failed: %w", err)
	}

	if len(translatedTexts) != len(textLines) {
		return "", fmt.Errorf("translation response count mismatch: got %d, expected %d", len(translatedTexts), len(textLines))
	}

	// Rebuild LRC content with translated text
	resultLines := make([]string, len(lines))
	copy(resultLines, lines)
	for i, translated := range translatedTexts {
		origLine := lines[lineIndices[i]]
		text := extractLRCContent(origLine)
		if text != "" {
			resultLines[lineIndices[i]] = strings.Replace(origLine, text, translated, 1)
		}
	}

	return strings.Join(resultLines, "\n"), nil
}

// extractLRCContent strips timestamp markers from an LRC line and returns the text part.
// e.g. "[00:01.23]Hello world" -> "Hello world"
func extractLRCContent(line string) string {
	// Handle multiple timestamps like [00:01.23][00:05.67]Text
	for strings.HasPrefix(line, "[") {
		closeIdx := strings.Index(line, "]")
		if closeIdx < 0 {
			break
		}
		line = line[closeIdx+1:]
	}
	return strings.TrimSpace(line)
}

// callTranslationAPI sends an HTTP POST to the translation API endpoint.
// It expects a LibreTranslate-compatible API.
func callTranslationAPI(texts []string, targetLang, sourceLang, endpoint, apiKey string) ([]string, error) {
	results := make([]string, len(texts))
	for i, text := range texts {
		if strings.TrimSpace(text) == "" {
			results[i] = text
			continue
		}
		translated, err := translateSingle(text, targetLang, sourceLang, endpoint, apiKey)
		if err != nil {
			return nil, fmt.Errorf("failed to translate text %d: %w", i, err)
		}
		results[i] = translated
	}
	return results, nil
}

// translateSingle sends a single text to the translation API and returns the translated text.
func translateSingle(text, targetLang, sourceLang, endpoint, apiKey string) (string, error) {
	payload := map[string]interface{}{
		"q":      text,
		"target": targetLang,
	}
	if sourceLang != "" {
		payload["source"] = sourceLang
	}
	if apiKey != "" {
		payload["api_key"] = apiKey
	}

	body, err := json.Marshal(payload)
	if err != nil {
		return "", fmt.Errorf("failed to marshal request: %w", err)
	}

	req, err := http.NewRequest("POST", endpoint, bytes.NewReader(body))
	if err != nil {
		return "", fmt.Errorf("failed to create request: %w", err)
	}
	req.Header.Set("Content-Type", "application/json")

	resp, err := lyricsTranslationClient.Do(req)
	if err != nil {
		return "", fmt.Errorf("HTTP request failed: %w", err)
	}
	defer resp.Body.Close()

	respBody, err := io.ReadAll(resp.Body)
	if err != nil {
		return "", fmt.Errorf("failed to read response: %w", err)
	}

	if resp.StatusCode != http.StatusOK {
		return "", fmt.Errorf("translation API returned status %d: %s", resp.StatusCode, string(respBody))
	}

	var result struct {
		TranslatedText string `json:"translatedText"`
	}
	if err := json.Unmarshal(respBody, &result); err != nil {
		return "", fmt.Errorf("failed to parse response: %w", err)
	}

	return result.TranslatedText, nil
}

// detectLanguage performs basic language detection on text.
// It uses a simple heuristic based on character ranges, which is sufficient for
// distinguishing between common languages like English, Spanish, French, etc.
func detectLanguage(text string) string {
	// Strip LRC timestamps to analyze only the text content
	cleanText := ""
	for _, line := range strings.Split(text, "\n") {
		content := extractLRCContent(line)
		if content != "" {
			cleanText += content + " "
		}
	}
	cleanText = strings.TrimSpace(cleanText)
	if cleanText == "" {
		return "en"
	}

	// Count character categories
	var latin, cjk, cyrillic, accents int
	totalChars := 0
	for _, r := range cleanText {
		if r > 127 {
			totalChars++
			switch {
			case r >= 0x4E00 && r <= 0x9FFF, r >= 0x3400 && r <= 0x4DBF:
				cjk++
			case r >= 0x0400 && r <= 0x04FF:
				cyrillic++
			case r >= 0x00C0 && r <= 0x024F:
				accents++
			case r >= 0x0600 && r <= 0x06FF:
				return "ar"
			case r >= 0x0E00 && r <= 0x0E7F:
				return "th"
			case r >= 0x3040 && r <= 0x309F, r >= 0x30A0 && r <= 0x30FF:
				return "ja"
			case r >= 0xAC00 && r <= 0xD7AF:
				return "ko"
			case r >= 0x0590 && r <= 0x05FF:
				return "he"
			default:
				latin++
			}
		} else if (r >= 'a' && r <= 'z') || (r >= 'A' && r <= 'Z') {
			latin++
		}
	}

	if totalChars == 0 {
		return "en"
	}

	// Determine language based on character distribution
	if cjk > 0 {
		return "zh"
	}
	if cyrillic > totalChars/2 {
		return "ru"
	}
	if accents > totalChars/3 {
		// Heavy accent usage suggests romance languages
		// Check for common Spanish/Portuguese patterns
		for _, r := range cleanText {
			if r == 'ñ' || r == 'Ñ' {
				return "es"
			}
			if r == 'ç' || r == 'ã' || r == 'õ' {
				return "pt"
			}
			if r == 'à' || r == 'é' || r == 'è' || r == 'ê' || r == 'ë' {
				return "fr"
			}
		}
		return "es" // Default for accented latin
	}

	// Default to English for plain ASCII
	return "en"
}
