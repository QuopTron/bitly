package handlers

import (
	"encoding/json"
	"fmt"
	"hash/fnv"
	"os"
	"path/filepath"
	"strings"
	"time"

	"github.com/zarz/bitly/go_backend_bitly/internal/audio/cue"
	"github.com/zarz/bitly/go_backend_bitly/internal/audio/metadata"
	"github.com/zarz/bitly/go_backend_bitly/internal/server/rpc"
	"github.com/zarz/bitly/go_backend_bitly/internal/storage/database"
)

// cueID generates a stable library-scan ID for a cue track.
func cueID(base string, trackNum int) string {
	h := fnv.New64a()
	h.Write([]byte(base))
	h.Write([]byte(fmt.Sprintf(":%d", trackNum)))
	return fmt.Sprintf("cue_%016x", h.Sum64())
}

// RegisterCueSheetHandlers registers CUE sheet parsing RPC methods.
func RegisterCueSheetHandlers(reg *rpc.Registry) {
	reg.Register("parseCueSheet", func(params map[string]interface{}) (interface{}, error) {
		cuePath := rpc.Sp(params, "cue_path")
		audioDir := rpc.Sp(params, "audio_dir")
		if cuePath == "" {
			return "", fmt.Errorf("cue_path is required")
		}
		return cue.ParseCueFileJSON(cuePath, audioDir)
	})

	reg.Register("scanCueSheetForLibrary", func(params map[string]interface{}) (interface{}, error) {
		cuePath := rpc.Sp(params, "cue_path")
		audioDir := rpc.Sp(params, "audio_dir")
		virtualPathPrefix := rpc.Sp(params, "virtual_path_prefix")
		fileModTime := int64(rpc.Sn(params, "file_mod_time"))

		if cuePath == "" {
			return "[]", fmt.Errorf("cue_path is required")
		}

		// 1. Parse the CUE file
		sheet, err := cue.ParseCueFile(cuePath)
		if err != nil {
			return "[]", fmt.Errorf("failed to parse cue file: %w", err)
		}

		// 2. Resolve audio file path
		resolveDir := cuePath
		if audioDir != "" {
			resolveDir = filepath.Join(audioDir, filepath.Base(cuePath))
		}
		audioPath := cue.ResolveCueAudioPath(resolveDir, sheet.FileName)
		if audioPath == "" {
			return "[]", fmt.Errorf("audio file not found for cue sheet: %s (referenced: %s)", cuePath, sheet.FileName)
		}

		// 3. Get audio quality
		audioQuality, qualityErr := metadata.GetAudioQualityFromFile(audioPath)
		bitDepth := 0
		sampleRate := 0
		totalDuration := 0
		if qualityErr == nil {
			bitDepth = audioQuality.BitDepth
			sampleRate = audioQuality.SampleRate
			totalDuration = audioQuality.Duration
		}

		// 4. Handle cover art cache (if library cover cache dir is set)
		libraryCoverCacheDir := getLibraryCoverCacheDir()
		coverPath := ""
		if libraryCoverCacheDir != "" {
			cacheKey := cuePath
			if stat, err := os.Stat(cuePath); err == nil {
				cacheKey = fmt.Sprintf("%s|%d|%d", cuePath, stat.Size(), stat.ModTime().UnixNano())
			}
			cachedCover, coverErr := metadata.SaveCoverToCacheWithHintAndKey(audioPath, sheet.Title, libraryCoverCacheDir, cacheKey)
			if coverErr == nil {
				coverPath = cachedCover
			}
		}

		// 5. Determine file mod time
		modTime := fileModTime
		if modTime <= 0 {
			if stat, err := os.Stat(cuePath); err == nil {
				modTime = stat.ModTime().Unix()
			}
		}

		scanTime := time.Now().UTC().Format(time.RFC3339)

		// 6. Build result base path
		resultPathBase := cuePath
		if virtualPathPrefix != "" {
			resultPathBase = virtualPathPrefix
		}

		// 7. Generate LibraryScanResult entries for each track
		var results []database.LibraryScanResult

		for i, track := range sheet.Tracks {
			performer := track.Performer
			if performer == "" {
				performer = sheet.Performer
			}

			composer := track.Composer
			if composer == "" {
				composer = sheet.Composer
			}

			// Calculate track duration from next track index or end of file
			trackDuration := 0
			if i+1 < len(sheet.Tracks) {
				nextStart := sheet.Tracks[i+1].StartTime
				trackDuration = int(nextStart - track.StartTime)
			} else if totalDuration > 0 {
				trackDuration = totalDuration - int(track.StartTime)
			}

			// Generate a stable ID
			id := cueID(resultPathBase, track.Number)

			results = append(results, database.LibraryScanResult{
				ID:          id,
				TrackName:   track.Title,
				ArtistName:  performer,
				AlbumName:   sheet.Title,
				AlbumArtist: sheet.Performer,
				FilePath:    audioPath,
				CoverPath:   coverPath,
				ScannedAt:   scanTime,
				FileModTime: modTime,
				ISRC:        track.ISRC,
				TrackNumber: track.Number,
				TotalTracks: len(sheet.Tracks),
				DiscNumber:  1,
				TotalDiscs:  1,
				Duration:    trackDuration,
				ReleaseDate: sheet.Date,
				BitDepth:    bitDepth,
				SampleRate:  sampleRate,
				Genre:       sheet.Genre,
				Composer:    composer,
				Format:      strings.TrimPrefix(filepath.Ext(audioPath), "."),
			})
		}

		if results == nil {
			results = []database.LibraryScanResult{}
		}

		out, err := json.Marshal(results)
		if err != nil {
			return "[]", fmt.Errorf("failed to marshal cue scan results: %w", err)
		}
		return string(out), nil
	})
}

// getLibraryCoverCacheDir retrieves the global library cover cache directory.
// This must be set via SetLibraryCoverCacheDir or the scanLibrary handler.
var cachedCoverCacheDir string

// SetLibraryCoverCacheDir stores the cover cache directory path.
// Called by RegisterLibraryHandlers when the setLibraryCoverCacheDir method is invoked.
func SetLibraryCoverCacheDir(dir string) {
	cachedCoverCacheDir = dir
}

func getLibraryCoverCacheDir() string {
	return cachedCoverCacheDir
}
