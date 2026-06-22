package handlers

import (
	"testing"

	"github.com/zarz/bitly/go_backend_bitly/internal/server/rpc"
)

func TestExtractLRCContent(t *testing.T) {
	tests := []struct {
		name  string
		line  string
		want  string
	}{
		{"single timestamp", "[00:01.23]Hello world", "Hello world"},
		{"multiple timestamps", "[00:01.23][00:05.67]Hello world", "Hello world"},
		{"no timestamp", "Hello world", "Hello world"},
		{"empty", "", ""},
		{"timestamp only", "[00:01.23]", ""},
		{"multiple timestamps with spaces", "[00:01.23][00:05.67]  Hello world  ", "Hello world"},
		{"unicode text", "[00:01.23]Héllö wörld", "Héllö wörld"},
		{"timestamp with ms", "[00:01.234]Short text", "Short text"},
		{"nested brackets", "[00:01.23]Text [with] brackets", "Text [with] brackets"},
		{"whitespace only after timestamp", "[00:01.23]   ", ""},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			got := extractLRCContent(tt.line)
			if got != tt.want {
				t.Errorf("extractLRCContent(%q) = %q, want %q", tt.line, got, tt.want)
			}
		})
	}
}

func TestDetectLanguage(t *testing.T) {
	tests := []struct {
		name string
		text string
		want string
	}{
		{"english", "[00:01.23]Hello world, this is a test", "en"},
		{"english no timestamps", "Hello world", "en"},
		{"spanish with ñ", "[00:01.23]Año nuevo, vida nueva", "es"},
		{"portuguese with ç", "[00:01.23]Ação e reação", "pt"},
		{"french with accents", "[00:01.23]C'est la vie, déjà vu", "fr"},
		{"chinese", "[00:01.23]你好世界", "zh"},
		{"russian cyrillic", "[00:01.23]Привет мир", "ru"},
		{"japanese", "[00:01.23]こんにちは世界", "ja"},
		{"korean", "[00:01.23]안녕하세요 세계", "ko"},
		{"arabic", "[00:01.23]مرحبا بالعالم", "ar"},
		{"hebrew", "[00:01.23]שלום עולם", "he"},
		{"thai", "[00:01.23]สวัสดีชาวโลก", "th"},
		{"empty lrc", "", "en"},
		{"empty after stripping timestamps", "[00:01.23]", "en"},
		{"mixed latin and accented with é detected as fr", "[00:01.23]José and María went to São Paulo", "fr"},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			got := detectLanguage(tt.text)
			if got != tt.want {
				t.Errorf("detectLanguage(%q) = %q, want %q", tt.text, got, tt.want)
			}
		})
	}
}

func TestRegisterLyricsTranslationHandlers(t *testing.T) {
	reg := rpc.NewRegistry()
	registerLyricsTranslationHandlers(reg)

	t.Run("translateLyricsLRC missing request", func(t *testing.T) {
		_, err := dispatch(reg, "translateLyricsLRC", nil)
		if err == nil {
			t.Error("expected error for missing request")
		}
	})

	t.Run("translateLyricsLRC empty request", func(t *testing.T) {
		_, err := dispatch(reg, "translateLyricsLRC", map[string]interface{}{
			"request": "",
		})
		if err == nil {
			t.Error("expected error for empty request")
		}
	})

	t.Run("translateLyricsLRC missing lrc field", func(t *testing.T) {
		_, err := dispatch(reg, "translateLyricsLRC", map[string]interface{}{
			"request": `{"target_lang":"es"}`,
		})
		if err == nil {
			t.Error("expected error for missing lrc field")
		}
	})

	t.Run("translateLyricsLRC missing target_lang", func(t *testing.T) {
		_, err := dispatch(reg, "translateLyricsLRC", map[string]interface{}{
			"request": `{"lrc":"[00:01.00]Hello"}`,
		})
		if err == nil {
			t.Error("expected error for missing target_lang")
		}
	})

	t.Run("translateLyricsLRC invalid JSON request", func(t *testing.T) {
		_, err := dispatch(reg, "translateLyricsLRC", map[string]interface{}{
			"request": "not valid json",
		})
		if err == nil {
			t.Error("expected error for invalid JSON")
		}
	})

	t.Run("translateLyricsLRC empty lrc content", func(t *testing.T) {
		_, err := dispatch(reg, "translateLyricsLRC", map[string]interface{}{
			"request": `{"lrc":"","target_lang":"es"}`,
		})
		if err == nil {
			t.Error("expected error for empty lrc content")
		}
	})

	t.Run("setTranslationAPIConfig missing request", func(t *testing.T) {
		_, err := dispatch(reg, "setTranslationAPIConfig", nil)
		if err == nil {
			t.Error("expected error for missing request")
		}
	})

	t.Run("setTranslationAPIConfig empty request", func(t *testing.T) {
		_, err := dispatch(reg, "setTranslationAPIConfig", map[string]interface{}{
			"request": "",
		})
		if err == nil {
			t.Error("expected error for empty request")
		}
	})

	t.Run("setTranslationLanguageWithDetection missing lrc_content", func(t *testing.T) {
		_, err := dispatch(reg, "setTranslationLanguageWithDetection", nil)
		if err == nil {
			t.Error("expected error for missing lrc_content")
		}
	})

	t.Run("setTranslationLanguageWithDetection missing target_lang", func(t *testing.T) {
		_, err := dispatch(reg, "setTranslationLanguageWithDetection", map[string]interface{}{
			"lrc_content": "[00:01.00]Hello",
		})
		if err == nil {
			t.Error("expected error for missing target_lang")
		}
	})

	t.Run("setTranslationLanguageWithDetection empty target_lang", func(t *testing.T) {
		_, err := dispatch(reg, "setTranslationLanguageWithDetection", map[string]interface{}{
			"lrc_content": "[00:01.00]Hello",
			"target_lang": "",
		})
		if err == nil {
			t.Error("expected error for empty target_lang")
		}
	})
}
