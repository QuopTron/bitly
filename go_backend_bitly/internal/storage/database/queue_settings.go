package database

import (
	"database/sql"
	"encoding/json"
	"fmt"
	"strings"
)

func SaveAppSettings(jsonStr string) error {
	if strings.TrimSpace(jsonStr) == "" {
		return fmt.Errorf("empty JSON string")
	}
	var js json.RawMessage
	if err := json.Unmarshal([]byte(jsonStr), &js); err != nil {
		return fmt.Errorf("invalid JSON: %w", err)
	}

	db, err := Get()
	if err != nil {
		return err
	}
	_, err = db.Exec(`INSERT INTO application_state (key, value, updated_at) VALUES ('app_settings', ?, datetime('now')) ON CONFLICT(key) DO UPDATE SET value=excluded.value, updated_at=excluded.updated_at`, jsonStr)
	return err
}

func LoadAppSettings() (string, error) {
	db, err := Get()
	if err != nil {
		return "", err
	}
	var value string
	err = db.QueryRow("SELECT value FROM application_state WHERE key = 'app_settings'").Scan(&value)
	if err == sql.ErrNoRows {
		return "", nil
	}
	if err != nil {
		return "", err
	}
	return value, nil
}

func SaveTranslationLanguage(language string) error {
	if strings.TrimSpace(language) == "" {
		return fmt.Errorf("empty language string")
	}
	db, err := Get()
	if err != nil {
		return err
	}
	_, err = db.Exec(`INSERT INTO application_state (key, value, updated_at) VALUES ('translation_language', ?, datetime('now')) ON CONFLICT(key) DO UPDATE SET value=excluded.value, updated_at=excluded.updated_at`, language)
	return err
}

func LoadTranslationLanguage() (string, error) {
	db, err := Get()
	if err != nil {
		return "", err
	}
	var value string
	err = db.QueryRow("SELECT value FROM application_state WHERE key = 'translation_language'").Scan(&value)
	if err == sql.ErrNoRows {
		return "", nil
	}
	if err != nil {
		return "", err
	}
	return value, nil
}

// TranslationAPIConfig holds the configuration for the lyrics translation API.
type TranslationAPIConfig struct {
	Endpoint string `json:"endpoint"`
	APIKey   string `json:"api_key,omitempty"`
}

func SaveTranslationAPIConfig(configJSON string) error {
	if strings.TrimSpace(configJSON) == "" {
		return fmt.Errorf("empty config JSON")
	}
	var cfg TranslationAPIConfig
	if err := json.Unmarshal([]byte(configJSON), &cfg); err != nil {
		return fmt.Errorf("invalid config JSON: %w", err)
	}
	if cfg.Endpoint == "" {
		return fmt.Errorf("translation API endpoint is required")
	}

	db, err := Get()
	if err != nil {
		return err
	}
	_, err = db.Exec(`INSERT INTO application_state (key, value, updated_at) VALUES ('translation_api_config', ?, datetime('now')) ON CONFLICT(key) DO UPDATE SET value=excluded.value, updated_at=excluded.updated_at`, configJSON)
	return err
}

func LoadTranslationAPIConfig() (*TranslationAPIConfig, error) {
	db, err := Get()
	if err != nil {
		return nil, err
	}
	var value string
	err = db.QueryRow("SELECT value FROM application_state WHERE key = 'translation_api_config'").Scan(&value)
	if err == sql.ErrNoRows {
		return nil, nil
	}
	if err != nil {
		return nil, err
	}
	var cfg TranslationAPIConfig
	if err := json.Unmarshal([]byte(value), &cfg); err != nil {
		return nil, fmt.Errorf("invalid stored config: %w", err)
	}
	return &cfg, nil
}
