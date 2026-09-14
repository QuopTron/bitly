package main

import (
	"fmt"
	"log"
	"os"
	"time"

	"golang.org/x/sys/windows"
)

// vigilarPadre vigila que el proceso padre (bitly.exe) siga vivo y sale solo
// cuando ya no existe. En PC la app y el backend son procesos separados; sin
// esto, al cerrar la ventana el backend queda huérfano ocupando el puerto y RAM.
//
// Estrategia robusta (funciona en Windows 10/11, incluyendo restricciones
// de seguridad en PCs nuevas):
//  1. Al inicio, abre un handle al padre con SYNCHRONIZE+QUERY_LIMITED_INFORMATION.
//  2. Cada 3 s, usa WaitForSingleObject(handle, 0) — retorna instantáneamente
//     con WAIT_OBJECT_0 si el proceso terminó, o timeout si sigue vivo.
//  3. Si el handle no se pudo abrir al inicio, reintenta con backoff: solo
//     sale después de 5 fallos consecutivos (~15 s).
func vigilarPadre(pid int) {
	if pid <= 0 {
		log.Printf("[watchdog] PID inválido (%d) — no se vigila al padre", pid)
		return
	}

	// Abrir handle al padre. SYNCHRONIZE permite WaitForSingleObject;
	// PROCESS_QUERY_LIMITED_INFORMATION es permisivo para query.
	h, err := windows.OpenProcess(
		windows.SYNCHRONIZE|windows.PROCESS_QUERY_LIMITED_INFORMATION,
		false,
		uint32(pid),
	)
	var handle windows.Handle
	if err != nil {
		log.Printf("[watchdog] no se pudo abrir handle PID %d: %v — reintentando", pid, err)
		handle = 0
	} else {
		handle = h
	}

	go func() {
		fallos := 0
		const maxFallos = 5

		for {
			time.Sleep(3 * time.Second)

			if handle == 0 {
				h, err := windows.OpenProcess(
					windows.SYNCHRONIZE|windows.PROCESS_QUERY_LIMITED_INFORMATION,
					false,
					uint32(pid),
				)
				if err != nil {
					fallos++
					if fallos >= maxFallos {
						log.Printf("[watchdog] PID %d inalcanzable tras %d intentos — saliendo", pid, fallos)
						os.Exit(0)
					}
					log.Printf("[watchdog] reintento %d/%d PID %d: %v", fallos, maxFallos, pid, err)
					continue
				}
				handle = h
				fallos = 0
				log.Printf("[watchdog] handle PID %d abierto", pid)
			}

			ret, _, _ := procWaitForSingleObject.Call(uintptr(handle), 0)
			errno := windows.Errno(ret)

			switch errno {
			case windows.WAIT_OBJECT_0:
				windows.CloseHandle(handle)
				log.Println("[watchdog] Padre cerrado — saliendo")
				os.Exit(0)
			case windows.WAIT_FAILED:
				windows.CloseHandle(handle)
				handle = 0
				fallos++
				if fallos >= maxFallos {
					log.Printf("[watchdog] handle inválido tras %d intentos — saliendo", fallos)
					os.Exit(0)
				}
			default:
				// WAIT_TIMEOUT = sigue vivo.
				fallos = 0
			}
		}
	}()
}

var (
	modkernel32             = windows.NewLazySystemDLL("kernel32.dll")
	procWaitForSingleObject = modkernel32.NewProc("WaitForSingleObject")
)

func init() {
	_ = fmt.Sprintf // prevent unused import
}
