package main

import (
	"encoding/json"
	"fmt"
	"time"

	"github.com/zarz/bitly/go_backend/internal/bundled_extensions"
	"github.com/zarz/bitly/go_backend/internal/extensions"
)

func dumpRaw(name string, v interface{}, maxLen int) {
	raw, _ := json.Marshal(v)
	s := string(raw)
	if maxLen > 0 && len(s) > maxLen {
		s = s[:maxLen] + "..."
	}
	fmt.Printf("=== %s ===\n%s\n", name, s)
}

func main() {
	fmt.Println("=== Diag raw getArtist/getAlbum/getPlaylist ===")

	reg, err := extensions.NewRegistry(".")
	if err != nil {
		fmt.Printf("ERROR: %v\n", err)
		return
	}
	list := bundled_extensions.LoadAllToRegistry(reg)
	fmt.Printf("Loaded %d\n", len(list))
	time.Sleep(100 * time.Millisecond)
	rt := reg.Runtime()

	// Amazon getArtist raw
	fmt.Println("\n########## amazon getArtist RAW (queen) ##########")
	start := time.Now()
	res, err := rt.CallMethod("amazon", "getArtist", "B000QK71AG")
	fmt.Printf("err=%v elapsed=%v\n", err, time.Since(start))
	if err == nil {
		dumpRaw("amazon getArtist", res, 2500)
	}

	// Amazon getAlbum raw — buscar un album de queen en search
	fmt.Println("\n########## amazon getAlbum RAW ##########")
	opts := map[string]interface{}{"limit": 3, "filter": "album"}
	albs, errA := rt.CallMethod("amazon", "customSearch", "queen", opts)
	if errA == nil {
		if list, ok := albs.([]interface{}); ok && len(list) > 0 {
			if m, ok := list[0].(map[string]interface{}); ok {
				albID := m["id"]
				fmt.Printf("first album id=%v\n", albID)
				start := time.Now()
				albRes, errAl := rt.CallMethod("amazon", "getAlbum", albID)
				fmt.Printf("getAlbum err=%v elapsed=%v\n", errAl, time.Since(start))
				if errAl == nil {
					dumpRaw("amazon getAlbum", albRes, 2500)
				}
			}
		}
	}

	// Qobuz getArtist raw (necesita sesión, probablemente VERIFY_REQUIRED)
	fmt.Println("\n########## qobuz-web getArtist RAW ##########")
	start = time.Now()
	qres, errQ := rt.CallMethod("qobuz-web", "getArtist", "27206")
	fmt.Printf("err=%v elapsed=%v\n", errQ, time.Since(start))
	if errQ == nil {
		dumpRaw("qobuz getArtist", qres, 2000)
	} else {
		fmt.Printf("  error: %v\n", errQ)
	}
}
