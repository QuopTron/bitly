package download

import (
	"io"
	"log"
	"os"
	"path/filepath"
)

func (sm *StagingManager) WriteStaged(finalPath string, src io.Reader) (string, error) {
	lock := sm.getLock(finalPath)
	lock.Lock()
	defer lock.Unlock()

	dir := filepath.Dir(finalPath)
	if err := os.MkdirAll(dir, 0755); err != nil {
		return "", err
	}

	stagingPath := StagePath(finalPath)

	tmp, err := os.Create(stagingPath)
	if err != nil {
		return "", err
	}
	defer func() {
		// On failure, clean up the staging file
		tmp.Close()
		os.Remove(stagingPath)
	}()

	if _, err := io.Copy(tmp, src); err != nil {
		return "", err
	}

	// fsync before rename for crash safety
	if err := tmp.Sync(); err != nil {
		return "", err
	}
	if err := tmp.Close(); err != nil {
		return "", err
	}

	// Atomic rename
	if err := os.Rename(stagingPath, finalPath); err != nil {
		// Cross-device rename fallback
		if in, inErr := os.Open(stagingPath); inErr == nil {
			out, outErr := os.Create(finalPath)
			if outErr == nil {
				_, _ = io.Copy(out, in)
				out.Sync()
				out.Close()
				in.Close()
				os.Remove(stagingPath)
			} else {
				in.Close()
				return "", outErr
			}
		} else {
			return "", inErr
		}
	}

	log.Printf("[staging] %s -> %s", stagingPath, finalPath)
	return finalPath, nil
}

// WriteStagedBytes writes a byte slice to finalPath through staging.
func (sm *StagingManager) WriteStagedBytes(finalPath string, data []byte) (string, error) {
	lock := sm.getLock(finalPath)
	lock.Lock()
	defer lock.Unlock()

	dir := filepath.Dir(finalPath)
	if err := os.MkdirAll(dir, 0755); err != nil {
		return "", err
	}

	stagingPath := StagePath(finalPath)

	if err := os.WriteFile(stagingPath, data, 0644); err != nil {
		os.Remove(stagingPath)
		return "", err
	}

	if err := os.Rename(stagingPath, finalPath); err != nil {
		os.Remove(stagingPath)
		return "", err
	}

	return finalPath, nil
}

// CleanupStaging removes any leftover .partial files in the given directory.
