//go:build !windows

package main

import (
	"log"
	"os"
	"syscall"
	"time"
)

// Watchdog para Linux/macOS: vigila que el proceso padre siga vivo y sale
// solo cuando ya no existe. En Unix, Signal(0) consulta la existencia del
// proceso sin enviar ninguna señal real.
func vigilarPadre(pid int) {
	go func() {
		for {
			time.Sleep(2 * time.Second)
			proceso, err := os.FindProcess(pid)
			if err != nil {
				log.Println("[server] Proceso padre cerrado — saliendo")
				os.Exit(0)
			}
			if err := proceso.Signal(syscall.Signal(0)); err != nil {
				log.Println("[server] Proceso padre cerrado — saliendo")
				os.Exit(0)
			}
		}
	}()
}
