package download

import (
	"encoding/hex"
	"fmt"
	"log"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
)

func descifrarStream(inputPath, key, outDir, outExt, inFormat string) (string, error) {
	if key == "" {
		return "", fmt.Errorf("ERR_NO_KEY: no hay clave de descifrado")
	}
	bin := ffmpegPath()
	if bin == "" {
		return "", fmt.Errorf("ffmpeg no disponible para descifrar")
	}
	if outExt == "" {
		outExt = ".mp4"
	}
	if !strings.HasPrefix(outExt, ".") {
		outExt = "." + outExt
	}
	if inFormat == "" {
		inFormat = "mov"
	}
	base := strings.TrimSuffix(filepath.Base(inputPath), filepath.Ext(inputPath))
	if base == "" {
		base = "track"
	}

	keys := candidatosClaveDescifrado(key)
	for i, k := range keys {
		outFile := filepath.Join(outDir, fmt.Sprintf("%s.decrypted%s", base, outExt))
		if i > 0 {
			outFile = filepath.Join(outDir, fmt.Sprintf("%s.decrypted%d%s", base, i, outExt))
		}
		args := []string{
			"-y",
			"-decryption_key", k,
			"-f", inFormat,
			"-i", inputPath,
			"-map", "0:a",
			"-c", "copy",
			outFile,
		}
		log.Printf("[decrypt] ffmpeg cmd: %s %s", bin, strings.Join(args, " "))
		cmd := exec.Command(bin, args...)
		output, err := cmd.CombinedOutput()
		if err == nil {
			// Validate minimum output file size (10KB) to catch empty/truncated outputs
			if info, serr := os.Stat(outFile); serr == nil && info.Size() < 10240 {
				log.Printf("[decrypt] output too small (%d bytes), treating as failure", info.Size())
				_ = os.Remove(outFile)
				if i == len(keys)-1 {
					return "", fmt.Errorf("descifrado ffmpeg output demasiado pequeño: %d bytes (%s): %s", info.Size(), huellaArchivo(inputPath), string(output))
				}
				continue
			}
			log.Printf("[decrypt] success: %s (%d bytes)", outFile, func() int64 {
				if info, err := os.Stat(outFile); err == nil {
					return info.Size()
				}
				return 0
			}())
			return outFile, nil
		}
		log.Printf("[decrypt] attempt %d failed: %s", i, string(output))
		_ = os.Remove(outFile)
		if i == len(keys)-1 {
			return "", fmt.Errorf("descifrado ffmpeg fallido: %s (%s): %w", string(output), huellaArchivo(inputPath), err)
		}
	}
	return "", fmt.Errorf("sin clave para descifrar")
}

// fileFingerprint summarizes a file for diagnostics: its size plus the first
// 16 bytes as hex, so a failed decrypt shows what was actually downloaded
// (a valid encrypted MP4 starts with "0000001866747970" i.e. an ftyp box;
// Un html error página, un plain flac ("664c6143"), o un truncated archivo son// immediately recognizable).
func huellaArchivo(path string) string {
	f, err := os.Open(path)
	if err != nil {
		return fmt.Sprintf("size? open: %v", err)
	}
	defer f.Close()
	st, err := f.Stat()
	if err != nil {
		return fmt.Sprintf("size? stat: %v", err)
	}
	buf := make([]byte, 16)
	n, _ := f.Read(buf)
	return fmt.Sprintf("size=%d head=%s", st.Size(), hex.EncodeToString(buf[:n]))
}
