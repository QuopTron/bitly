package extensions

import (
	"encoding/json"
	"os"
	"strings"
)

func (s *SignedSessionState) loadOrInit(dataDir string, cfg SignedSessionConfig) (*signedSessionRecord, error) {
	s.mu.Lock()
	defer s.mu.Unlock()

	s.dataDir = dataDir
	path, err := rutaArchivoSesionFirmada(dataDir, cfg)
	if err != nil {
		return nil, err
	}
	record := &signedSessionRecord{}
	// Reuse the in-memory record when available so the install_id (and any
	// exchanged session) stays stable between bootstrap and grant exchange.
	// Este matters cuando el datos dir es sin writable (embedded sandboxes son
	// created with dataDir "." on Android before Flutter provides the real
	// path) — otherwise every loadOrInit would generate a NEW install_id and
	// el exchange would ser rejected porque el grant belongs a the
	// bootstrap's install_id.
	if s.Record != nil {
		record = s.Record
	} else if data, err := os.ReadFile(path); err == nil {
		_ = json.Unmarshal(data, record)
	}
	if strings.TrimSpace(record.InstallID) == "" {
		record.InstallID = hexAleatorio(16)
	}
	// If el record belongs a un diferente scope (namespace/baseURL/
	// appVersion/platform), the stored session does not apply — reset it.
	scopeChanged := record.Namespace != sanitizarNamespaceSesionFirmada(cfg.Namespace) ||
		record.BaseURL != strings.TrimSpace(cfg.BaseURL) ||
		record.AppVersion != strings.TrimSpace(cfg.AppVersion) ||
		record.Platform != strings.TrimSpace(cfg.Platform)
	if scopeChanged {
		record.SessionID = ""
		record.SessionSecret = ""
		record.ExpiresAt = ""
	}
	record.Namespace = sanitizarNamespaceSesionFirmada(cfg.Namespace)
	record.BaseURL = strings.TrimSpace(cfg.BaseURL)
	record.AppVersion = strings.TrimSpace(cfg.AppVersion)
	record.Platform = strings.TrimSpace(cfg.Platform)
	s.Record = record
	// Persist when possible; never fail the call on a read-only filesystem
	// (e.g. Android bundled extensions with dataDir ".").
	s.persistRecord(cfg)
	return record, nil
}
