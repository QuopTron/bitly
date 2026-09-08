package main

import (
	"encoding/json"
	"io"
	"net/http"

	backend "github.com/zarz/bitly/go_backend/internal/gobackend"
)

// registerPremiumRoutes registra los endpoints HTTP de premium (estado,
// validación de códigos, set manual y gate de descargas). Todos delegan en
// las exports del backend Go (internal/gobackend/exports_premium.go).
func registerPremiumRoutes(mux *http.ServeMux) {
	mux.HandleFunc("/premium/status", func(w http.ResponseWriter, r *http.Request) {
		jsonStr(w, backend.GetPremiumStatus())
	})
	mux.HandleFunc("/premium/validate", func(w http.ResponseWriter, r *http.Request) {
		body, _ := io.ReadAll(r.Body)
		var req struct {
			Code string `json:"code"`
		}
		if err := json.Unmarshal(body, &req); err != nil || req.Code == "" {
			http.Error(w, `{"error":"falta el código"}`, 400)
			return
		}
		payload, _ := json.Marshal(map[string]interface{}{"code": req.Code})
		jsonStr(w, backend.ValidatePremiumCode(string(payload)))
	})
	mux.HandleFunc("/premium/set", func(w http.ResponseWriter, r *http.Request) {
		body, _ := io.ReadAll(r.Body)
		var req struct {
			IsPremium bool   `json:"isPremium"`
			Tier      string `json:"tier"`
		}
		if err := json.Unmarshal(body, &req); err != nil {
			http.Error(w, `{"error":"cuerpo inválido"}`, 400)
			return
		}
		payload, _ := json.Marshal(map[string]interface{}{"isPremium": req.IsPremium, "tier": req.Tier})
		jsonStr(w, backend.SetPremiumStatus(string(payload)))
	})
	mux.HandleFunc("/premium/check-download", func(w http.ResponseWriter, r *http.Request) {
		jsonStr(w, backend.CheckDownloadAllowed())
	})
}
