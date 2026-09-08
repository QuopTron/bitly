package extensions

import (
	"bytes"
	"encoding/json"
	"fmt"
	"net/http"
)

func (s *SignedSessionState) exchangeSignedSessionGrant(client *http.Client, cfg SignedSessionConfig, record *signedSessionRecord, grant string) error {
	endpoint, err := signedSessionURL(cfg, cfg.Endpoints.Exchange)
	if err != nil {
		return err
	}
	payload := map[string]any{
		"grant":       grant,
		"install_id":  record.InstallID,
		"app_version": cfg.AppVersion,
		"platform":    cfg.Platform,
	}
	body, _ := json.Marshal(payload)
	req, err := http.NewRequest(http.MethodPost, endpoint, bytes.NewReader(body))
	if err != nil {
		return err
	}
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("Accept", "application/json")
	req.Header.Set("User-Agent", "SpotiFLAC-Mobile/"+cfg.AppVersion)

	resp, err := client.Do(req)
	if err != nil {
		return err
	}
	respBody, err := readSignedBody(resp)
	if err != nil {
		return err
	}
	if resp.StatusCode < 200 || resp.StatusCode >= 300 {
		// Include the gateway body so a failing exchange is diagnosable from
		// El go/flutter logs en su lugar de un bare estado código.		return fmt.Errorf("ERR_SESION: fallo el intercambio de sesion: HTTP %d (%s)", resp.StatusCode, strings.TrimSpace(string(respBody)))
	}
	var exchanged signedSessionExchangeResponse
	if err := jsonUnmarshal(respBody, &exchanged); err != nil {
		return fmt.Errorf("ERR_SESION: respuesta de intercambio de sesion invalida: %w", err)
	}
	if exchanged.SessionID == "" || exchanged.SessionSecret == "" || exchanged.ExpiresAt == "" {
		return fmt.Errorf("ERR_SESION: la respuesta del intercambio no tiene campos de sesion")
	}
	record.SessionID = exchanged.SessionID
	record.SessionSecret = exchanged.SessionSecret
	record.ExpiresAt = exchanged.ExpiresAt
	s.Record = record
	s.Grant = ""
	s.AuthURL = ""
	s.persistRecord(cfg)
	return nil
}

// keepAliveRefresh silently refreshes the session when it is still usable and
// within [signedSessionKeepAliveLead] of expiry. Paced per source and backed
// off after failures so a periodic tick never hammers the gateway. Never
// bootstraps and never returns a challenge URL — a session that needs human
// verification is reported as-is and left to the explicit-action flows.
