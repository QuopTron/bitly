//go:build tool

// Package tool pins golang.org/x/mobile in the module graph so gomobile bind
// can resolve gobind. Never compiled into the app binary.
package gobackend

import (
	_ "golang.org/x/mobile/cmd/gobind"
)
