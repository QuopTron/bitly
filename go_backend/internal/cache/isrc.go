package cache

import (
	"encoding/binary"
	"io"
	"log"
	"os"
	"path/filepath"
	"strings"
	"sync"
	"time"
)

// TrackRef stores minimal track info keyed by ISRC for dedup.
type TrackRef struct {
	TrackID    string `json:"trackId"`
	Title      string `json:"title"`
	ArtistName string `json:"artistName"`
	AlbumName  string `json:"albumName"`
	Provider   string `json:"provider"`
}

// fileStats tracks file metadata for incremental rebuild.
type fileStats struct {
	size    int64
	modTime time.Time
}

// ISRCIndex is a thread-safe map of ISRC → TrackRef for dedup with
// parallel scanning and incremental rebuild support.
type ISRCIndex struct {
	mu         sync.RWMutex
	isrcs      map[string]*TrackRef
	fileCache  map[string]fileStats // path → size+modTime for incremental
	rebuildMu  sync.Mutex
	rebuilding bool
	lastBuild  time.Time
}

// NewISRCIndex creates an empty ISRC index.
func NewISRCIndex() *ISRCIndex {
	return &ISRCIndex{
		isrcs:     make(map[string]*TrackRef),
		fileCache: make(map[string]fileStats),
	}
}

// Add stores a track reference by its ISRC code.
func (idx *ISRCIndex) Add(isrc string, ref *TrackRef) {
	if isrc == "" {
		return
	}
	idx.mu.Lock()
	idx.isrcs[isrc] = ref
	idx.mu.Unlock()
}

// Lookup returns the track reference for an ISRC, if indexed.
func (idx *ISRCIndex) Lookup(isrc string) (*TrackRef, bool) {
	if isrc == "" {
		return nil, false
	}
	idx.mu.RLock()
	ref, ok := idx.isrcs[isrc]
	idx.mu.RUnlock()
	if !ok {
		return nil, false
	}
	return ref, true
}

// Has returns true if the ISRC is already indexed.
func (idx *ISRCIndex) Has(isrc string) bool {
	if isrc == "" {
		return false
	}
	idx.mu.RLock()
	_, ok := idx.isrcs[isrc]
	idx.mu.RUnlock()
	return ok
}

// Remove deletes an ISRC entry.
func (idx *ISRCIndex) Remove(isrc string) {
	if isrc == "" {
		return
	}
	idx.mu.Lock()
	delete(idx.isrcs, isrc)
	idx.mu.Unlock()
}

// Clear removes all entries.
func (idx *ISRCIndex) Clear() {
	idx.mu.Lock()
	idx.isrcs = make(map[string]*TrackRef)
	idx.fileCache = make(map[string]fileStats)
	idx.mu.Unlock()
}

// Len returns the number of indexed ISRCs.
func (idx *ISRCIndex) Len() int {
	idx.mu.RLock()
	defer idx.mu.RUnlock()
	return len(idx.isrcs)
}

// ═══════════════════════════════════════════════════════════════════════
// Parallel file scanning with incremental rebuild
// ═══════════════════════════════════════════════════════════════════════

const (
	parallelWorkers  = 4
	indexFreshnessTTL = 5 * time.Minute
	maxIndexAge       = 10 * time.Minute
)

// BuildIndex scans a directory tree in parallel and extracts ISRCs from
// audio files. Incremental: only re-parses files that changed since last build.
func (idx *ISRCIndex) BuildIndex(rootDir string) error {
	idx.rebuildMu.Lock()
	if idx.rebuilding {
		idx.rebuildMu.Unlock()
		return nil
	}
	idx.rebuilding = true
	idx.rebuildMu.Unlock()
	defer func() {
		idx.rebuildMu.Lock()
		idx.rebuilding = false
		idx.lastBuild = time.Now()
		idx.rebuildMu.Unlock()
	}()

	start := time.Now()

	// Collect all audio files
	var files []string
	_ = filepath.Walk(rootDir, func(path string, info os.FileInfo, err error) error {
		if err != nil || info.IsDir() {
			return nil
		}
		if isAudioFile(path) {
			files = append(files, path)
		}
		return nil
	})

	if len(files) == 0 {
		return nil
	}

	// Determine which files need re-scanning (incremental)
	var toScan []string
	idx.mu.RLock()
	for _, f := range files {
		info, err := os.Stat(f)
		if err != nil {
			continue
		}
		cached, exists := idx.fileCache[f]
		if !exists || cached.size != info.Size() || !cached.modTime.Equal(info.ModTime()) {
			toScan = append(toScan, f)
		}
	}
	idx.mu.RUnlock()

	if len(toScan) == 0 {
		log.Printf("[isrc-index] incremental: no changes in %d files", len(files))
		return nil
	}

	// Scan in parallel
	type result struct {
		path string
		isrc string
		ref  *TrackRef
	}

	jobs := make(chan string, len(toScan))
	results := make(chan result, len(toScan))
	var wg sync.WaitGroup

	for w := 0; w < parallelWorkers; w++ {
		wg.Add(1)
		go func() {
			defer wg.Done()
			for path := range jobs {
				isrc, ref := extractISRCFromFile(path)
				if isrc != "" && ref != nil {
					results <- result{path, isrc, ref}
				}
			}
		}()
	}

	go func() {
		for _, f := range toScan {
			jobs <- f
		}
		close(jobs)
	}()

	go func() {
		wg.Wait()
		close(results)
	}()

	// Collect results
	newCount := 0
	for r := range results {
		idx.mu.Lock()
		idx.isrcs[r.isrc] = r.ref
		info, err := os.Stat(r.path)
		if err == nil {
			idx.fileCache[r.path] = fileStats{size: info.Size(), modTime: info.ModTime()}
		}
		idx.mu.Unlock()
		newCount++
	}

	log.Printf("[isrc-index] built %d ISRCs from %d files (%d new/changed) in %v",
		idx.Len(), len(files), newCount, time.Since(start).Round(time.Millisecond))
	return nil
}

// PreBuildIndex triggers a proactive index build in the background.
func (idx *ISRCIndex) PreBuildIndex(rootDir string) {
	go func() {
		if err := idx.BuildIndex(rootDir); err != nil {
			log.Printf("[isrc-index] prebuild error: %v", err)
		}
	}()
}

// CheckFilesExistParallel checks which tracks already exist on disk by ISRC.
// Returns a map of ISRC → file path for existing files.
func (idx *ISRCIndex) CheckFilesExistParallel(outputDir string, isrcs []string) map[string]string {
	if len(isrcs) == 0 {
		return nil
	}

	type checkResult struct {
		isrc string
		path string
	}

	results := make(chan checkResult, len(isrcs))
	var wg sync.WaitGroup

	sem := make(chan struct{}, parallelWorkers)
	for _, isrc := range isrcs {
		wg.Add(1)
		sem <- struct{}{}
		go func(isrc string) {
			defer wg.Done()
			defer func() { <-sem }()

			idx.mu.RLock()
			ref, ok := idx.isrcs[isrc]
			idx.mu.RUnlock()

			if ok && ref != nil {
				// Check if the file still exists
				if ref.TrackID != "" {
					// Search for file by track ID pattern
					found := findFileByTrackID(outputDir, ref.TrackID)
					if found != "" {
						results <- checkResult{isrc, found}
						return
					}
				}
			}

			// Fallback: scan directory for ISRC in metadata
			path := scanForISRC(outputDir, isrc)
			if path != "" {
				results <- checkResult{isrc, path}
			}
		}(isrc)
	}

	go func() {
		wg.Wait()
		close(results)
	}()

	existing := make(map[string]string)
	for r := range results {
		existing[r.isrc] = r.path
	}
	return existing
}

// AddToISRCIndex adds a single file to the index.
func (idx *ISRCIndex) AddToISRCIndex(filePath string) {
	isrc, ref := extractISRCFromFile(filePath)
	if isrc != "" && ref != nil {
		idx.Add(isrc, ref)
	}
}

// InvalidateISRCCache removes cached file stats for a directory so next
// BuildIndex re-scans everything.
func (idx *ISRCIndex) InvalidateISRCCache(dir string) {
	idx.mu.Lock()
	defer idx.mu.Unlock()
	prefix := filepath.Clean(dir) + string(filepath.Separator)
	for path := range idx.fileCache {
		if strings.HasPrefix(path, prefix) {
			delete(idx.fileCache, path)
		}
	}
}

// ═══════════════════════════════════════════════════════════════════════
// Native ISRC extraction (FLAC, MP3, M4A, Ogg)
// ═══════════════════════════════════════════════════════════════════════

// extractISRCFromFile reads an audio file and extracts the ISRC code.
func extractISRCFromFile(path string) (string, *TrackRef) {
	ext := strings.ToLower(filepath.Ext(path))
	switch ext {
	case ".flac":
		return extractISRCFromFLAC(path)
	case ".mp3":
		return extractISRCFromMP3(path)
	case ".m4a", ".mp4", ".m4b":
		return extractISRCFromM4A(path)
	case ".ogg", ".opus":
		return extractISRCFromOGG(path)
	}
	return "", nil
}

// extractISRCFromFLAC reads Vorbis comments from a FLAC file to find ISRC.
func extractISRCFromFLAC(path string) (string, *TrackRef) {
	f, err := os.Open(path)
	if err != nil {
		return "", nil
	}
	defer f.Close()

	// Verify FLAC header
	header := make([]byte, 4)
	if _, err := io.ReadFull(f, header); err != nil || string(header) != "fLaC" {
		return "", nil
	}

	// Walk metadata blocks looking for Vorbis comment (type 4)
	for {
		blockHeader := make([]byte, 4)
		if _, err := io.ReadFull(f, blockHeader); err != nil {
			return "", nil
		}
		isLast := blockHeader[0]&0x80 != 0
		blockType := blockHeader[0] & 0x7F
		blockSize := int(blockHeader[1])<<16 | int(blockHeader[2])<<8 | int(blockHeader[3])

		if blockType == 4 { // Vorbis comment
			return parseVorbisCommentsForISRC(f, blockSize, path)
		}

		if isLast {
			break
		}
		// Skip this block
		if _, err := io.CopyN(io.Discard, f, int64(blockSize)); err != nil {
			return "", nil
		}
	}
	return "", nil
}

// parseVorbisCommentsForISRC parses a Vorbis comment block for ISRC metadata.
func parseVorbisCommentsForISRC(r io.Reader, blockSize int, path string) (string, *TrackRef) {
	data := make([]byte, blockSize)
	if _, err := io.ReadFull(r, data); err != nil {
		return "", nil
	}

	if len(data) < 8 {
		return "", nil
	}

	// Vendor string length (LE uint32)
	vendorLen := int(binary.LittleEndian.Uint32(data[0:4]))
	offset := 4 + vendorLen
	if offset >= len(data) {
		return "", nil
	}

	// Number of comment entries
	numComments := int(binary.LittleEndian.Uint32(data[offset : offset+4]))
	offset += 4

	var isrc, title, artist, album string
	for i := 0; i < numComments && offset < len(data); i++ {
		if offset+4 > len(data) {
			break
		}
		entryLen := int(binary.LittleEndian.Uint32(data[offset : offset+4]))
		offset += 4
		if offset+entryLen > len(data) {
			break
		}
		entry := string(data[offset : offset+entryLen])
		offset += entryLen

		eqIdx := strings.Index(entry, "=")
		if eqIdx < 0 {
			continue
		}
		key := strings.ToUpper(entry[:eqIdx])
		val := entry[eqIdx+1:]

		switch key {
		case "ISRC":
			isrc = strings.TrimSpace(val)
		case "TITLE":
			title = val
		case "ARTIST":
			artist = val
		case "ALBUM":
			album = val
		}
	}

	if isrc == "" {
		return "", nil
	}
	return isrc, &TrackRef{
		Title:      title,
		ArtistName: artist,
		AlbumName:  album,
		TrackID:    filepath.Base(path),
	}
}

// extractISRCFromMP3 reads ID3v2 tags from an MP3 file.
func extractISRCFromMP3(path string) (string, *TrackRef) {
	f, err := os.Open(path)
	if err != nil {
		return "", nil
	}
	defer f.Close()

	header := make([]byte, 10)
	if _, err := io.ReadFull(f, header); err != nil {
		return "", nil
	}

	if string(header[:3]) != "ID3" {
		return "", nil
	}

	tagSize := int(header[6])<<21 | int(header[7])<<14 | int(header[8])<<7 | int(header[9])
	if tagSize == 0 || tagSize > 10*1024*1024 { // 10MB sanity limit
		return "", nil
	}

	tagData := make([]byte, tagSize)
	if _, err := io.ReadFull(f, tagData); err != nil {
		return "", nil
	}

	return parseID3v2ForISRC(tagData, path)
}

// parseID3v2ForISRC parses ID3v2 frames looking for TSRC (ISRC) and text frames.
func parseID3v2ForISRC(data []byte, path string) (string, *TrackRef) {
	var isrc, title, artist, album string
	offset := 0

	for offset+10 <= len(data) {
		frameID := string(data[offset : offset+4])
		// ID3v2.4 uses syncsafe sizes; ID3v2.3 uses regular.
		size := int(data[offset+4])<<24 | int(data[offset+5])<<16 | int(data[offset+6])<<8 | int(data[offset+7])

		if frameID == "\x00\x00\x00\x00" || size <= 0 || offset+10+size > len(data) {
			break
		}

		frameData := data[offset+10 : offset+10+size]
		switch frameID {
		case "TSRC": // ISRC
			isrc = cleanString(frameData)
		case "TIT2": // Title
			title = cleanString(frameData)
		case "TPE1": // Artist
			artist = cleanString(frameData)
		case "TALB": // Album
			album = cleanString(frameData)
		}

		offset += 10 + size
	}

	if isrc == "" {
		return "", nil
	}
	return isrc, &TrackRef{
		Title:      title,
		ArtistName: artist,
		AlbumName:  album,
		TrackID:    filepath.Base(path),
	}
}

// extractISRCFromM4A reads MP4/iTunes metadata for ISRC.
func extractISRCFromM4A(path string) (string, *TrackRef) {
	data, err := os.ReadFile(path)
	if err != nil {
		return "", nil
	}
	return parseMP4AtomsForISRC(data, path)
}

// parseMP4AtomsForISRC walks MP4 atoms to find ©ISRC or trkn metadata.
func parseMP4AtomsForISRC(data []byte, path string) (string, *TrackRef) {
	if len(data) < 8 {
		return "", nil
	}

	var isrc, title, artist, album string

	var walk func(offset, end int)
	walk = func(offset, end int) {
		for offset+8 <= end {
			size := int(data[offset])<<24 | int(data[offset+1])<<16 | int(data[offset+2])<<8 | int(data[offset+3])
			atomType := string(data[offset+4 : offset+8])
			if size < 8 || offset+size > end {
				break
			}

			switch atomType {
			case "©ISRC", "isrc":
				isrc = cleanString(data[offset+8 : offset+size])
			case "©nam", "name":
				title = cleanString(data[offset+8 : offset+size])
			case "©ART", "ART":
				artist = cleanString(data[offset+8 : offset+size])
			case "©alb", "alb":
				album = cleanString(data[offset+8 : offset+size])
			case "moov", "udta", "meta", "ilst":
				walk(offset+8, offset+size)
			}

			offset += size
		}
	}

	walk(0, len(data))
	if isrc == "" {
		return "", nil
	}
	return isrc, &TrackRef{
		Title:      title,
		ArtistName: artist,
		AlbumName:  album,
		TrackID:    filepath.Base(path),
	}
}

// extractISRCFromOGG reads Vorbis comments from OGG/Opus files.
func extractISRCFromOGG(path string) (string, *TrackRef) {
	f, err := os.Open(path)
	if err != nil {
		return "", nil
	}
	defer f.Close()

	// OGG page header
	header := make([]byte, 28)
	if _, err := io.ReadFull(f, header); err != nil {
		return "", nil
	}
	if string(header[:4]) != "OggS" {
		return "", nil
	}

	// For OGG, the first page contains the Vorbis/Opus header.
	// The comment page follows. We read the first page's segment table
	// to skip it, then parse the next page's comments.
	numSegments := int(header[26])
	if numSegments == 0 {
		return "", nil
	}
	segTable := make([]byte, numSegments)
	if _, err := io.ReadFull(f, segTable); err != nil {
		return "", nil
	}
	pageSize := 0
	for _, s := range segTable {
		pageSize += int(s)
	}
	// Skip first page data
	if _, err := io.CopyN(io.Discard, f, int64(pageSize)); err != nil {
		return "", nil
	}

	// Read second page header
	if _, err := io.ReadFull(f, header); err != nil {
		return "", nil
	}
	numSegments = int(header[26])
	segTable = make([]byte, numSegments)
	if _, err := io.ReadFull(f, segTable); err != nil {
		return "", nil
	}
	pageSize = 0
	for _, s := range segTable {
		pageSize += int(s)
	}
	pageData := make([]byte, pageSize)
	if _, err := io.ReadFull(f, pageData); err != nil {
		return "", nil
	}

	// Skip Vorbis/Opus header bytes in comment block
	// Vorbis: 7 bytes header + vendor string
	if len(pageData) < 7 {
		return "", nil
	}
	offset := 7
	if offset+4 > len(pageData) {
		return "", nil
	}
	vendorLen := int(binary.LittleEndian.Uint32(pageData[offset : offset+4]))
	offset += 4 + vendorLen
	if offset+4 > len(pageData) {
		return "", nil
	}
	numComments := int(binary.LittleEndian.Uint32(pageData[offset : offset+4]))
	offset += 4

	for i := 0; i < numComments && offset < len(pageData); i++ {
		if offset+4 > len(pageData) {
			break
		}
		entryLen := int(binary.LittleEndian.Uint32(pageData[offset : offset+4]))
		offset += 4
		if offset+entryLen > len(pageData) {
			break
		}
		entry := string(pageData[offset : offset+entryLen])
		offset += entryLen

		eqIdx := strings.Index(entry, "=")
		if eqIdx < 0 {
			continue
		}
		key := strings.ToUpper(entry[:eqIdx])
		val := entry[eqIdx+1:]

		if key == "ISRC" {
			isrc := strings.TrimSpace(val)
			if isrc != "" {
				return isrc, &TrackRef{TrackID: filepath.Base(path)}
			}
		}
	}
	return "", nil
}

// ═══════════════════════════════════════════════════════════════════════
// Helpers
// ═══════════════════════════════════════════════════════════════════════

func isAudioFile(path string) bool {
	ext := strings.ToLower(filepath.Ext(path))
	switch ext {
	case ".flac", ".mp3", ".m4a", ".mp4", ".m4b", ".ogg", ".opus", ".wav", ".aiff", ".aif":
		return true
	}
	return false
}

func cleanString(data []byte) string {
	if len(data) == 0 {
		return ""
	}
	// Skip encoding byte for ID3v2 text frames
	if data[0] == 0 || data[0] == 3 { // ISO-8859-1 or UTF-8
		return strings.TrimSpace(string(data[1:]))
	}
	if data[0] == 1 && len(data) >= 3 { // UTF-16 with BOM
		if data[1] == 0xFE && data[2] == 0xFF {
			// UTF-16 BE
			return strings.TrimSpace(string(data[3:]))
		}
		if data[1] == 0xFF && data[2] == 0xFE {
			// UTF-16 LE
			return strings.TrimSpace(string(data[3:]))
		}
	}
	return strings.TrimSpace(string(data[1:]))
}

func findFileByTrackID(dir, trackID string) string {
	base := strings.TrimSuffix(trackID, filepath.Ext(trackID))
	entries, err := os.ReadDir(dir)
	if err != nil {
		return ""
	}
	for _, e := range entries {
		if e.IsDir() {
			continue
		}
		name := strings.TrimSuffix(e.Name(), filepath.Ext(e.Name()))
		if strings.EqualFold(name, base) || strings.Contains(e.Name(), trackID) {
			return filepath.Join(dir, e.Name())
		}
	}
	return ""
}

func scanForISRC(dir, isrc string) string {
	// Quick check: if the file exists with ISRC as name
	candidate := filepath.Join(dir, isrc+".flac")
	if _, err := os.Stat(candidate); err == nil {
		return candidate
	}
	candidate = filepath.Join(dir, isrc+".mp3")
	if _, err := os.Stat(candidate); err == nil {
		return candidate
	}
	return ""
}
