package bin

import (
	"os"
	"path/filepath"
	"runtime"
)

// Platform devuelve el string SO/ARQUITECTURA usado en las URLs de descarga.
func Platform() string {
	return runtime.GOOS + "_" + runtime.GOARCH
}

// ResolvedYTDLPPath devuelve la ruta donde se instalará (o está) yt-dlp, aunque aún no se haya descargado.
func (m *Manager) ResolvedYTDLPPath() string {
	return filepath.Join(m.dirBin, "yt-dlp"+sufijoExe())
}

// YTDLPPath devuelve la ruta solo si el binario existe y es válido, si no "".
func (m *Manager) YTDLPPath() string {
	p := m.ResolvedYTDLPPath()
	if !esBinarioValido(p) {
		return ""
	}
	return p
}

// esBinarioValido verifica que un archivo sea un binario real (no una página HTML 404 ni algo diminuto).
func esBinarioValido(ruta string) bool {
	fi, err := os.Stat(ruta)
	if err != nil {
		return false
	}
	if fi.Size() < 100_000 {
		return false // demasiado pequeño para ser un binario real
	}
	f, err := os.Open(ruta)
	if err != nil {
		return true // no se puede leer — asumimos válido
	}
	defer f.Close()
	buf := make([]byte, 16)
	if _, err := f.ReadAt(buf, 0); err != nil {
		return true
	}
	switch runtime.GOOS {
	case "android", "linux":
		// Magic ELF: 0x7f 'E' 'L' 'F'
		return buf[0] == 0x7f && buf[1] == 'E' && buf[2] == 'L' && buf[3] == 'F'
	case "darwin":
		// Magic Mach-O: 0xFE 0xED 0xFA (32-bit) o 0xFE 0xED 0xFA 0xCE/0xCF (64-bit)
		if buf[0] == 0xFE && buf[1] == 0xED && buf[2] == 0xFA {
			return true
		}
		// Binario universal: 0xCA 0xFE 0xBA 0xBE
		return buf[0] == 0xCA && buf[1] == 0xFE && buf[2] == 0xBA && buf[3] == 0xBE
	case "windows":
		// Cabecera PE: 'M' 'Z' (MZ)
		return buf[0] == 'M' && buf[1] == 'Z'
	default:
		return true
	}
}
