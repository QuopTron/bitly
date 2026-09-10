package main

import (
	"log"
	"os"
	"time"

	"golang.org/x/sys/windows"
)

// Watchdog solo para Windows: vigila que el proceso padre (bitly.exe) siga
// vivo y sale solo cuando ya no existe. En PC la app y el backend son procesos
// separados; sin esto, al cerrar la ventana el backend queda huérfano ocupando
// el puerto y RAM. (En móvil no se usa este binario — gomobile embebido.)
//
// NOTA: no usar os.Process.Signal(0) para el chequeo — en Windows esa señal
// POSIX no existe y SIEMPRE falla, haciendo que el backend se cierre solo a
// los 2 segundos de arrancar (feed vacío en PC). OpenProcess con
// PROCESS_QUERY_LIMITED_INFORMATION es la forma correcta de consultar si un
// PID sigue vivo en Windows.
func vigilarPadre(pid int) {
	go func() {
		for {
			time.Sleep(2 * time.Second)
			if !procesoVivoWindows(pid) {
				log.Println("[server] Proceso padre cerrado — saliendo")
				os.Exit(0)
			}
		}
	}()
}

// procesoVivoWindows devuelve true si el PID sigue existiendo. Abre el proceso
// con consulta limitada (sin permisos de kill) — si falla con "no existe", el
// padre ya no está.
func procesoVivoWindows(pid int) bool {
	manejo, err := windows.OpenProcess(
		windows.PROCESS_QUERY_LIMITED_INFORMATION,
		false,
		uint32(pid),
	)
	if err != nil {
		return false
	}
	_ = windows.CloseHandle(manejo)
	return true
}
