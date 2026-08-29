package audio

import (
	"io"
	"log"
	"os"
	"path/filepath"
)

// ═══════════════════════════════════════════════════════════════════════
// Crash-Safe FLAC Save — writes to temp file, fsyncs, then atomic rename
// ═══════════════════════════════════════════════════════════════════════

// SafeSaveFLAC writes FLAC tag data to a temp file and atomically renames
// it over the original, preventing corruption from crashes/power loss.
func SafeSaveFLAC(originalPath string, data []byte) error {
	dir := filepath.Dir(originalPath)
	tmp, err := os.CreateTemp(dir, "*.tag.partial")
	if err != nil {
		return err
	}
	tmpPath := tmp.Name()
	defer func() {
		if _, statErr := os.Stat(tmpPath); statErr == nil {
			os.Remove(tmpPath)
		}
	}()

	if _, err := tmp.Write(data); err != nil {
		tmp.Close()
		return err
	}
	if err := tmp.Sync(); err != nil {
		tmp.Close()
		return err
	}
	if err := tmp.Close(); err != nil {
		return err
	}

	if err := os.Rename(tmpPath, originalPath); err != nil {
		// Cross-device fallback
		if in, inErr := os.Open(tmpPath); inErr == nil {
			out, outErr := os.Create(originalPath)
			if outErr == nil {
				_, _ = io.Copy(out, in)
				out.Sync()
				out.Close()
				in.Close()
				os.Remove(tmpPath)
			} else {
				in.Close()
				return outErr
			}
		} else {
			return inErr
		}
	}

	// Dir fsync for power-loss safety
	if dirFile, err := os.Open(dir); err == nil {
		dirFile.Sync()
		dirFile.Close()
	}

	log.Printf("[flac-save] safely saved %s", originalPath)
	return nil
}

// SafeSaveFLACStream writes FLAC data from a reader to a temp file and
// atomically renames it over the original.
func SafeSaveFLACStream(originalPath string, src io.Reader) error {
	dir := filepath.Dir(originalPath)
	tmp, err := os.CreateTemp(dir, "*.tag.partial")
	if err != nil {
		return err
	}
	tmpPath := tmp.Name()
	defer func() {
		if _, statErr := os.Stat(tmpPath); statErr == nil {
			os.Remove(tmpPath)
		}
	}()

	if _, err := io.Copy(tmp, src); err != nil {
		tmp.Close()
		return err
	}
	if err := tmp.Sync(); err != nil {
		tmp.Close()
		return err
	}
	if err := tmp.Close(); err != nil {
		return err
	}

	if err := os.Rename(tmpPath, originalPath); err != nil {
		return err
	}

	if dirFile, err := os.Open(dir); err == nil {
		dirFile.Sync()
		dirFile.Close()
	}

	return nil
}
