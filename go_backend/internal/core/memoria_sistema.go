package core

import (
	"os"
	"strconv"
	"strings"
)

// memoriaDelSistemaMB lee la RAM TOTAL y DISPONIBLE del aparato en MiB.
//
// Fuente: /proc/meminfo, que en Android y Linux es legible desde el sandbox de
// la app y no necesita permisos (es la misma información que usa el sistema
// para decidir a quién mata). En plataformas donde el archivo no existe
// (escritorio Windows/macOS) devuelve ok=false y el llamador usa el valor por
// defecto: por eso esto no lleva build tags y funciona en todas.
//
// MemAvailable (no MemFree) es el dato correcto para decidir: MemFree ignora lo
// que el kernel puede recuperar de caché, y en Android casi toda la RAM libre
// está en caché, así que MemFree daría un número alarmantemente bajo siempre.
func memoriaDelSistemaMB() (totalMB, disponibleMB int, ok bool) {
	datos, err := os.ReadFile("/proc/meminfo")
	if err != nil {
		return 0, 0, false
	}
	for _, linea := range strings.Split(string(datos), "\n") {
		campos := strings.Fields(linea)
		if len(campos) < 2 {
			continue
		}
		// Formato: "MemTotal:       1923456 kB"
		valor, err := strconv.Atoi(campos[1])
		if err != nil {
			continue
		}
		switch campos[0] {
		case "MemTotal:":
			totalMB = valor / 1024
		case "MemAvailable:":
			disponibleMB = valor / 1024
		}
	}
	if totalMB <= 0 {
		return 0, 0, false
	}
	return totalMB, disponibleMB, true
}
