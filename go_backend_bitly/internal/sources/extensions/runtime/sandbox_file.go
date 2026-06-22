package runtime

import (
	"fmt"
	"io"
	"net/http"
	"os"
	"path/filepath"
	"strings"
	"time"

	"github.com/dop251/goja"

	"github.com/zarz/bitly/go_backend_bitly/internal/audio/metadata"
	"github.com/zarz/bitly/go_backend_bitly/internal/download/core"
	"github.com/zarz/bitly/go_backend_bitly/internal/download/progress"
	"github.com/zarz/bitly/go_backend_bitly/internal/lyrics"
)

func (ler *loadedExtensionRuntime) registerFile() {
	fileObj := ler.vm.NewObject()
	fileObj.Set("download", ler.fileDownload)
	fileObj.Set("exists", ler.fileExists)
	fileObj.Set("delete", ler.fileDelete)
	fileObj.Set("read", ler.fileRead)
	fileObj.Set("readBytes", ler.fileReadBytes)
	fileObj.Set("write", ler.fileWrite)
	fileObj.Set("writeBytes", ler.fileWriteBytes)
	fileObj.Set("copy", ler.fileCopy)
	fileObj.Set("move", ler.fileMove)
	fileObj.Set("getSize", ler.fileGetSize)
	ler.vm.Set("file", fileObj)

	gobackendObj := ler.vm.NewObject()
	gobackendObj.Set("sanitizeFilename", ler.sanitizeFilenameWrapper)
	gobackendObj.Set("getAudioQuality", ler.gobackendGetAudioQuality)
	gobackendObj.Set("buildFilename", ler.gobackendBuildFilename)
	gobackendObj.Set("checkISRCExists", ler.gobackendCheckISRCExists)
	gobackendObj.Set("addToISRCIndex", ler.gobackendAddToISRCIndex)
	gobackendObj.Set("getLocalTime", ler.gobackendGetLocalTime)
	gobackendObj.Set("getLyricsLRC", ler.gobackendGetLyricsLRC)
	ler.vm.Set("gobackend", gobackendObj)
}

func (ler *loadedExtensionRuntime) validatePath(path string) (string, error) {
	if ler.manifest == nil || !ler.manifest.Permissions.File {
		return "", fmt.Errorf("file access denied: extension does not have 'file' permission")
	}
	cleanPath := filepath.Clean(path)
	if filepath.IsAbs(cleanPath) {
		return "", fmt.Errorf("file access denied: absolute paths not allowed. Use relative paths within extension sandbox")
	}
	fullPath := filepath.Join(ler.dataDir, cleanPath)
	absPath, err := filepath.Abs(fullPath)
	if err != nil { return "", fmt.Errorf("invalid path: %w", err) }
	absDataDir, _ := filepath.Abs(ler.dataDir)
	rel, err := filepath.Rel(absDataDir, absPath)
	if err != nil { return "", fmt.Errorf("path error: %w", err) }
	if strings.HasPrefix(rel, "..") { return "", fmt.Errorf("file access denied: path is outside sandbox") }
	return absPath, nil
}

func (ler *loadedExtensionRuntime) bindDownloadCancelContext(req *http.Request) *http.Request {
	if req == nil { return nil }
	itemID := ler.getActiveDownloadItemID()
	if itemID == "" {
		requestID := ler.getActiveRequestID()
		if requestID == "" { return req }
		return req.WithContext(core.InitExtensionRequestCancel(requestID))
	}
	return req.WithContext(core.InitDownloadCancel(itemID))
}

func (ler *loadedExtensionRuntime) fileDownload(call goja.FunctionCall) goja.Value {
	if len(call.Arguments) < 2 {
		return ler.vm.ToValue(map[string]interface{}{"success": false, "error": "URL and output path required"})
	}
	urlStr := call.Arguments[0].String()
	outputPath := call.Arguments[1].String()

	if err := validateDomain(urlStr, ler.manifest); err != nil {
		return ler.vm.ToValue(map[string]interface{}{"success": false, "error": err.Error()})
	}
	fullPath, err := ler.validatePath(outputPath)
	if err != nil { return ler.vm.ToValue(map[string]interface{}{"success": false, "error": err.Error()}) }

	var onProgress goja.Callable
	var headers map[string]string
	var chunkedDownload bool
	var chunkSize int64
	if len(call.Arguments) > 2 && !goja.IsUndefined(call.Arguments[2]) && !goja.IsNull(call.Arguments[2]) {
		if opts, ok := call.Arguments[2].Export().(map[string]interface{}); ok {
			if h, ok := opts["headers"].(map[string]interface{}); ok {
				headers = make(map[string]string)
				for k, v := range h { headers[k] = fmt.Sprintf("%v", v) }
			}
			if progressVal, ok := opts["onProgress"]; ok {
				if callable, ok := goja.AssertFunction(ler.vm.ToValue(progressVal)); ok {
					onProgress = callable
				}
			}
			if chunked, ok := opts["chunked"]; ok {
				switch v := chunked.(type) {
				case bool: chunkedDownload = v
				case int64:
					if v > 0 { chunkedDownload = true; chunkSize = v }
				case float64:
					if v > 0 { chunkedDownload = true; chunkSize = int64(v) }
				}
			}
		}
	}
	if chunkedDownload && chunkSize <= 0 {
		chunkSize = 1024 * 1024
	}

	dir := filepath.Dir(fullPath)
	if err := os.MkdirAll(dir, 0755); err != nil {
		return ler.vm.ToValue(map[string]interface{}{"success": false, "error": fmt.Sprintf("failed to create directory: %v", err)})
	}

	client := ler.downloadClient
	if client == nil { client = ler.httpClient }

	if chunkedDownload {
		return ler.fileDownloadChunked(client, urlStr, fullPath, headers, chunkSize, onProgress)
	}

	// Simple download
	req, err := http.NewRequest("GET", urlStr, nil)
	if err != nil { return ler.vm.ToValue(map[string]interface{}{"success": false, "error": err.Error()}) }
	req = ler.bindDownloadCancelContext(req)
	for k, v := range headers { req.Header.Set(k, v) }
	if req.Header.Get("User-Agent") == "" { req.Header.Set("User-Agent", "Bitly-Extension/1.0") }

	resp, err := client.Do(req)
	if err != nil { return ler.vm.ToValue(map[string]interface{}{"success": false, "error": err.Error()}) }
	defer resp.Body.Close()
	if resp.StatusCode < 200 || resp.StatusCode >= 300 {
		return ler.vm.ToValue(map[string]interface{}{"success": false, "error": fmt.Sprintf("HTTP error: %d", resp.StatusCode)})
	}

	out, err := os.Create(fullPath)
	if err != nil { return ler.vm.ToValue(map[string]interface{}{"success": false, "error": fmt.Sprintf("failed to create file: %v", err)}) }
	defer out.Close()

	activeItemID := ler.getActiveDownloadItemID()
	if activeItemID != "" { progress.SetItemDownloading(activeItemID) }

	contentLength := resp.ContentLength
	shouldTrackItemBytes := activeItemID != "" && onProgress == nil
	if shouldTrackItemBytes && contentLength > 0 { progress.SetItemBytesTotal(activeItemID, contentLength) }

	var writer interface{ Write([]byte) (int, error) } = out
	if shouldTrackItemBytes { writer = progress.NewItemProgressWriter(out, activeItemID) }

	var written int64
	buf := make([]byte, 32*1024)
	for {
		nr, er := resp.Body.Read(buf)
		if nr > 0 {
			nw, ew := writer.Write(buf[0:nr])
			if nw < 0 || nr < nw { nw = 0; if ew == nil { ew = fmt.Errorf("invalid write result") } }
			written += int64(nw)
			if ew != nil {
				if ew == core.ErrDownloadCancelled || fmt.Sprintf("%v", ew) == core.ErrDownloadCancelled.Error() {
					return ler.vm.ToValue(map[string]interface{}{"success": false, "error": "download cancelled"})
				}
				return ler.vm.ToValue(map[string]interface{}{"success": false, "error": fmt.Sprintf("failed to write file: %v", ew)})
			}
			if nr != nw { return ler.vm.ToValue(map[string]interface{}{"success": false, "error": "short write"}) }
			if onProgress != nil && contentLength > 0 {
				_, _ = onProgress(goja.Undefined(), ler.vm.ToValue(written), ler.vm.ToValue(contentLength))
			}
		}
		if er != nil {
			if er != io.EOF {
				return ler.vm.ToValue(map[string]interface{}{"success": false, "error": fmt.Sprintf("failed to read response: %v", er)})
			}
			break
		}
	}
	return ler.vm.ToValue(map[string]interface{}{"success": true, "path": fullPath, "size": written})
}

func (ler *loadedExtensionRuntime) fileDownloadChunked(client *http.Client, urlStr, fullPath string, headers map[string]string, chunkSize int64, onProgress goja.Callable) goja.Value {
	ua := "Bitly-Extension/1.0"

	probeReq, err := http.NewRequest("GET", urlStr, nil)
	if err != nil {
		return ler.vm.ToValue(map[string]interface{}{"success": false, "error": fmt.Sprintf("chunked: probe error: %v", err)})
	}
	probeReq = ler.bindDownloadCancelContext(probeReq)
	probeReq.Header.Set("User-Agent", ua)
	for k, v := range headers {
		if k != "Range" { probeReq.Header.Set(k, v) }
	}
	probeReq.Header.Set("Range", "bytes=0-1")

	probeResp, err := client.Do(probeReq)
	if err != nil {
		return ler.vm.ToValue(map[string]interface{}{"success": false, "error": fmt.Sprintf("chunked: probe error: %v", err)})
	}
	io.Copy(io.Discard, probeResp.Body)
	probeResp.Body.Close()

	if probeResp.StatusCode != 206 && probeResp.StatusCode != 200 {
		return ler.vm.ToValue(map[string]interface{}{"success": false, "error": fmt.Sprintf("chunked: probe HTTP %d", probeResp.StatusCode)})
	}

	var totalSize int64
	contentRange := probeResp.Header.Get("Content-Range")
	if contentRange != "" {
		if idx := strings.LastIndex(contentRange, "/"); idx >= 0 {
			sizeStr := contentRange[idx+1:]
			if sizeStr != "*" { fmt.Sscanf(sizeStr, "%d", &totalSize) }
		}
	}

	out, err := os.Create(fullPath)
	if err != nil {
		return ler.vm.ToValue(map[string]interface{}{"success": false, "error": fmt.Sprintf("failed to create file: %v", err)})
	}
	defer out.Close()

	activeItemID := ler.getActiveDownloadItemID()
	if activeItemID != "" { progress.SetItemDownloading(activeItemID) }

	shouldTrackItemBytes := activeItemID != "" && onProgress == nil
	if shouldTrackItemBytes && totalSize > 0 { progress.SetItemBytesTotal(activeItemID, totalSize) }

	var writer interface{ Write([]byte) (int, error) } = out
	if shouldTrackItemBytes { writer = progress.NewItemProgressWriter(out, activeItemID) }

	var totalWritten int64
	buf := make([]byte, 32*1024)
	maxRetries := 3

	for offset := int64(0); totalSize <= 0 || offset < totalSize; {
		end := offset + chunkSize - 1
		if totalSize > 0 && end >= totalSize { end = totalSize - 1 }

		var chunkResp *http.Response
		var chunkErr error
		for retry := 0; retry < maxRetries; retry++ {
			chunkReq, err := http.NewRequest("GET", urlStr, nil)
			if err != nil {
				return ler.vm.ToValue(map[string]interface{}{"success": false, "error": fmt.Sprintf("chunked: request error at offset %d: %v", offset, err)})
			}
			chunkReq = ler.bindDownloadCancelContext(chunkReq)
			chunkReq.Header.Set("User-Agent", ua)
			for k, v := range headers {
				if k != "Range" { chunkReq.Header.Set(k, v) }
			}
			chunkReq.Header.Set("Range", fmt.Sprintf("bytes=%d-%d", offset, end))

			chunkResp, chunkErr = client.Do(chunkReq)
			if chunkErr != nil {
				if retry < maxRetries-1 { time.Sleep(time.Duration(retry+1) * time.Second); continue }
				return ler.vm.ToValue(map[string]interface{}{"success": false, "error": fmt.Sprintf("chunked: error at offset %d after %d retries: %v", offset, maxRetries, chunkErr)})
			}
			if chunkResp.StatusCode == 206 || chunkResp.StatusCode == 200 { break }

			io.Copy(io.Discard, chunkResp.Body)
			chunkResp.Body.Close()

			if chunkResp.StatusCode == 403 || chunkResp.StatusCode == 429 {
				if retry < maxRetries-1 { time.Sleep(time.Duration(retry+1) * 2 * time.Second); continue }
			}
			return ler.vm.ToValue(map[string]interface{}{"success": false, "error": fmt.Sprintf("chunked: HTTP %d at offset %d", chunkResp.StatusCode, offset)})
		}

		chunkWritten := int64(0)
		for {
			nr, er := chunkResp.Body.Read(buf)
			if nr > 0 {
				nw, ew := writer.Write(buf[0:nr])
				if nw < 0 || nr < nw { nw = 0; if ew == nil { ew = fmt.Errorf("invalid write result") } }
				chunkWritten += int64(nw)
				totalWritten += int64(nw)
				if ew != nil {
					chunkResp.Body.Close()
					if ew == core.ErrDownloadCancelled || fmt.Sprintf("%v", ew) == core.ErrDownloadCancelled.Error() {
						return ler.vm.ToValue(map[string]interface{}{"success": false, "error": "download cancelled"})
					}
					return ler.vm.ToValue(map[string]interface{}{"success": false, "error": fmt.Sprintf("failed to write file: %v", ew)})
				}
				if nr != nw { chunkResp.Body.Close(); return ler.vm.ToValue(map[string]interface{}{"success": false, "error": "short write"}) }
				if onProgress != nil && totalSize > 0 {
					_, _ = onProgress(goja.Undefined(), ler.vm.ToValue(totalWritten), ler.vm.ToValue(totalSize))
				}
			}
			if er != nil {
				if er != io.EOF { chunkResp.Body.Close(); return ler.vm.ToValue(map[string]interface{}{"success": false, "error": fmt.Sprintf("chunked: read error at offset %d: %v", offset, er)}) }
				break
			}
		}
		chunkResp.Body.Close()
		offset += chunkWritten
		if chunkResp.StatusCode == 200 { break }
		if totalSize > 0 && offset >= totalSize { break }
		if totalSize <= 0 && chunkWritten < chunkSize { break }
	}

	return ler.vm.ToValue(map[string]interface{}{"success": true, "path": fullPath, "size": totalWritten})
}

func (ler *loadedExtensionRuntime) fileExists(call goja.FunctionCall) goja.Value {
	if len(call.Arguments) < 1 { return ler.vm.ToValue(false) }
	fullPath, err := ler.validatePath(call.Arguments[0].String())
	if err != nil { return ler.vm.ToValue(false) }
	_, err = os.Stat(fullPath)
	return ler.vm.ToValue(err == nil)
}

func (ler *loadedExtensionRuntime) fileDelete(call goja.FunctionCall) goja.Value {
	if len(call.Arguments) < 1 { return ler.vm.ToValue(map[string]interface{}{"success": false, "error": "path required"}) }
	fullPath, err := ler.validatePath(call.Arguments[0].String())
	if err != nil { return ler.vm.ToValue(map[string]interface{}{"success": false, "error": err.Error()}) }
	if err := os.Remove(fullPath); err != nil { return ler.vm.ToValue(map[string]interface{}{"success": false, "error": err.Error()}) }
	return ler.vm.ToValue(map[string]interface{}{"success": true})
}

func (ler *loadedExtensionRuntime) fileRead(call goja.FunctionCall) goja.Value {
	if len(call.Arguments) < 1 { return ler.vm.ToValue(map[string]interface{}{"success": false, "error": "path required"}) }
	fullPath, err := ler.validatePath(call.Arguments[0].String())
	if err != nil { return ler.vm.ToValue(map[string]interface{}{"success": false, "error": err.Error()}) }
	data, err := os.ReadFile(fullPath)
	if err != nil { return ler.vm.ToValue(map[string]interface{}{"success": false, "error": err.Error()}) }
	return ler.vm.ToValue(map[string]interface{}{"success": true, "data": string(data)})
}

func (ler *loadedExtensionRuntime) fileReadBytes(call goja.FunctionCall) goja.Value {
	if len(call.Arguments) < 1 {
		return ler.vm.ToValue(map[string]interface{}{"success": false, "error": "path is required"})
	}
	path := call.Arguments[0].String()
	fullPath, err := ler.validatePath(path)
	if err != nil {
		return ler.vm.ToValue(map[string]interface{}{"success": false, "error": err.Error()})
	}
	options := parseRuntimeOptionsArgument(call, 1)
	offset := runtimeOptionInt64(options, "offset", 0)
	length := runtimeOptionInt64(options, "length", -1)
	encoding := runtimeOptionString(options, "encoding", "base64")
	if offset < 0 {
		return ler.vm.ToValue(map[string]interface{}{"success": false, "error": "offset must be >= 0"})
	}

	file, err := os.Open(fullPath)
	if err != nil { return ler.vm.ToValue(map[string]interface{}{"success": false, "error": err.Error()}) }
	defer file.Close()

	info, err := file.Stat()
	if err != nil { return ler.vm.ToValue(map[string]interface{}{"success": false, "error": err.Error()}) }

	size := info.Size()
	if offset > size { offset = size }
	if _, err := file.Seek(offset, io.SeekStart); err != nil {
		return ler.vm.ToValue(map[string]interface{}{"success": false, "error": fmt.Sprintf("failed to seek: %v", err)})
	}

	var data []byte
	switch {
	case length == 0: data = []byte{}
	case length > 0:
		buf := make([]byte, int(length))
		n, readErr := file.Read(buf)
		if readErr != nil && readErr != io.EOF {
			return ler.vm.ToValue(map[string]interface{}{"success": false, "error": fmt.Sprintf("failed to read: %v", readErr)})
		}
		data = buf[:n]
	default:
		data, err = io.ReadAll(file)
		if err != nil {
			return ler.vm.ToValue(map[string]interface{}{"success": false, "error": fmt.Sprintf("failed to read: %v", err)})
		}
	}

	encoded, err := encodeRuntimeBytes(data, encoding)
	if err != nil { return ler.vm.ToValue(map[string]interface{}{"success": false, "error": err.Error()}) }

	return ler.vm.ToValue(map[string]interface{}{
		"success": true, "data": encoded,
		"bytes_read": len(data), "offset": offset, "size": size,
		"eof": offset+int64(len(data)) >= size,
	})
}

func (ler *loadedExtensionRuntime) fileWrite(call goja.FunctionCall) goja.Value {
	if len(call.Arguments) < 2 { return ler.vm.ToValue(map[string]interface{}{"success": false, "error": "path and data required"}) }
	fullPath, err := ler.validatePath(call.Arguments[0].String())
	if err != nil { return ler.vm.ToValue(map[string]interface{}{"success": false, "error": err.Error()}) }
	dir := filepath.Dir(fullPath)
	if err := os.MkdirAll(dir, 0755); err != nil {
		return ler.vm.ToValue(map[string]interface{}{"success": false, "error": fmt.Sprintf("failed to create directory: %v", err)})
	}
	if err := os.WriteFile(fullPath, []byte(call.Arguments[1].String()), 0644); err != nil {
		return ler.vm.ToValue(map[string]interface{}{"success": false, "error": err.Error()})
	}
	return ler.vm.ToValue(map[string]interface{}{"success": true, "path": fullPath})
}

func (ler *loadedExtensionRuntime) fileWriteBytes(call goja.FunctionCall) goja.Value {
	if len(call.Arguments) < 2 {
		return ler.vm.ToValue(map[string]interface{}{"success": false, "error": "path and data required"})
	}
	path := call.Arguments[0].String()
	fullPath, err := ler.validatePath(path)
	if err != nil { return ler.vm.ToValue(map[string]interface{}{"success": false, "error": err.Error()}) }

	options := parseRuntimeOptionsArgument(call, 2)
	appendMode := runtimeOptionBool(options, "append", false)
	truncate := runtimeOptionBool(options, "truncate", false)
	hasOffset := runtimeOptionHasKey(options, "offset")
	offset := runtimeOptionInt64(options, "offset", 0)
	encoding := runtimeOptionString(options, "encoding", "base64")

	if appendMode && hasOffset {
		return ler.vm.ToValue(map[string]interface{}{"success": false, "error": "append and offset cannot be used together"})
	}
	if offset < 0 { return ler.vm.ToValue(map[string]interface{}{"success": false, "error": "offset must be >= 0"}) }

	data, err := decodeRuntimeBytesValue(call.Arguments[1].Export(), encoding)
	if err != nil { return ler.vm.ToValue(map[string]interface{}{"success": false, "error": err.Error()}) }

	dir := filepath.Dir(fullPath)
	if err := os.MkdirAll(dir, 0755); err != nil {
		return ler.vm.ToValue(map[string]interface{}{"success": false, "error": fmt.Sprintf("failed to create directory: %v", err)})
	}

	flags := os.O_CREATE | os.O_WRONLY
	if appendMode { flags |= os.O_APPEND }
	if truncate { flags |= os.O_TRUNC }

	file, err := os.OpenFile(fullPath, flags, 0644)
	if err != nil { return ler.vm.ToValue(map[string]interface{}{"success": false, "error": err.Error()}) }
	defer file.Close()

	if hasOffset && !appendMode {
		if _, err := file.Seek(offset, io.SeekStart); err != nil {
			return ler.vm.ToValue(map[string]interface{}{"success": false, "error": fmt.Sprintf("failed to seek: %v", err)})
		}
	}

	written, err := file.Write(data)
	if err != nil { return ler.vm.ToValue(map[string]interface{}{"success": false, "error": err.Error()}) }

	info, statErr := file.Stat()
	size := int64(0)
	if statErr == nil { size = info.Size() }

	return ler.vm.ToValue(map[string]interface{}{
		"success": true, "path": fullPath, "bytes_written": written, "size": size,
	})
}

func (ler *loadedExtensionRuntime) fileCopy(call goja.FunctionCall) goja.Value {
	if len(call.Arguments) < 2 { return ler.vm.ToValue(map[string]interface{}{"success": false, "error": "source and dest required"}) }
	fullSrc, err := ler.validatePath(call.Arguments[0].String())
	if err != nil { return ler.vm.ToValue(map[string]interface{}{"success": false, "error": err.Error()}) }
	fullDst, err := ler.validatePath(call.Arguments[1].String())
	if err != nil { return ler.vm.ToValue(map[string]interface{}{"success": false, "error": err.Error()}) }
	srcFile, err := os.Open(fullSrc)
	if err != nil { return ler.vm.ToValue(map[string]interface{}{"success": false, "error": fmt.Sprintf("failed to read source: %v", err)}) }
	defer srcFile.Close()
	dir := filepath.Dir(fullDst)
	if err := os.MkdirAll(dir, 0755); err != nil {
		return ler.vm.ToValue(map[string]interface{}{"success": false, "error": fmt.Sprintf("failed to create directory: %v", err)})
	}
	dstFile, err := os.OpenFile(fullDst, os.O_CREATE|os.O_WRONLY|os.O_TRUNC, 0644)
	if err != nil { return ler.vm.ToValue(map[string]interface{}{"success": false, "error": fmt.Sprintf("failed to open destination: %v", err)}) }
	defer dstFile.Close()
	if _, err := io.Copy(dstFile, srcFile); err != nil {
		return ler.vm.ToValue(map[string]interface{}{"success": false, "error": fmt.Sprintf("copy error: %v", err)})
	}
	return ler.vm.ToValue(map[string]interface{}{"success": true, "path": fullDst})
}

func (ler *loadedExtensionRuntime) fileMove(call goja.FunctionCall) goja.Value {
	if len(call.Arguments) < 2 { return ler.vm.ToValue(map[string]interface{}{"success": false, "error": "source and dest required"}) }
	fullSrc, err := ler.validatePath(call.Arguments[0].String())
	if err != nil { return ler.vm.ToValue(map[string]interface{}{"success": false, "error": err.Error()}) }
	fullDst, err := ler.validatePath(call.Arguments[1].String())
	if err != nil { return ler.vm.ToValue(map[string]interface{}{"success": false, "error": err.Error()}) }
	dir := filepath.Dir(fullDst)
	if err := os.MkdirAll(dir, 0755); err != nil {
		return ler.vm.ToValue(map[string]interface{}{"success": false, "error": fmt.Sprintf("failed to create directory: %v", err)})
	}
	if err := os.Rename(fullSrc, fullDst); err != nil {
		return ler.vm.ToValue(map[string]interface{}{"success": false, "error": fmt.Sprintf("move error: %v", err)})
	}
	return ler.vm.ToValue(map[string]interface{}{"success": true, "path": fullDst})
}

func (ler *loadedExtensionRuntime) fileGetSize(call goja.FunctionCall) goja.Value {
	if len(call.Arguments) < 1 { return ler.vm.ToValue(map[string]interface{}{"success": false, "error": "path required"}) }
	fullPath, err := ler.validatePath(call.Arguments[0].String())
	if err != nil { return ler.vm.ToValue(map[string]interface{}{"success": false, "error": err.Error()}) }
	info, err := os.Stat(fullPath)
	if err != nil { return ler.vm.ToValue(map[string]interface{}{"success": false, "error": err.Error()}) }
	return ler.vm.ToValue(map[string]interface{}{"success": true, "size": info.Size()})
}

// --- gobackend ---

func sanitizeFilename(name string) string {
	name = strings.TrimSpace(name)
	replacer := strings.NewReplacer("/", "_", "\\", "_", ":", "_", "*", "_", "?", "_", "\"", "_", "<", "_", ">", "_", "|", "_", "\x00", "_")
	return strings.TrimSpace(replacer.Replace(name))
}

func (ler *loadedExtensionRuntime) sanitizeFilenameWrapper(call goja.FunctionCall) goja.Value {
	if len(call.Arguments) < 1 { return ler.vm.ToValue("") }
	return ler.vm.ToValue(sanitizeFilename(call.Arguments[0].String()))
}

func (ler *loadedExtensionRuntime) gobackendGetAudioQuality(call goja.FunctionCall) goja.Value {
	if len(call.Arguments) < 1 {
		return ler.vm.ToValue(map[string]interface{}{"error": "file path is required"})
	}
	filePath := call.Arguments[0].String()
	fullPath, err := ler.validatePath(filePath)
	if err != nil {
		return ler.vm.ToValue(map[string]interface{}{"error": err.Error()})
	}
	q, err := metadata.GetAudioQualityFromFile(fullPath)
	if err != nil {
		return ler.vm.ToValue(map[string]interface{}{"error": err.Error()})
	}
	return ler.vm.ToValue(map[string]interface{}{
		"bitDepth":     q.BitDepth,
		"sampleRate":   q.SampleRate,
		"totalSamples": q.TotalSamples,
		"duration":     q.Duration,
	})
}

func (ler *loadedExtensionRuntime) gobackendBuildFilename(call goja.FunctionCall) goja.Value {
	if len(call.Arguments) < 2 { return ler.vm.ToValue("") }
	template := call.Arguments[0].String()
	metadata := call.Arguments[1].Export()
	meta, ok := metadata.(map[string]interface{})
	if !ok { return ler.vm.ToValue("") }

	replacements := map[string]string{
		"{title}":       strVal(meta, "title"),
		"{artist}":      strVal(meta, "artist"),
		"{album}":       strVal(meta, "album"),
		"{track}":       fmt.Sprintf("%02d", intVal(meta, "track_number")),
		"{tracknumber}": fmt.Sprintf("%02d", intVal(meta, "track_number")),
		"{disc}":        fmt.Sprintf("%d", intVal(meta, "disc_number")),
		"{isrc}":        strVal(meta, "isrc"),
		"{year}":        strVal(meta, "year"),
		"{date}":        strVal(meta, "date"),
	}
	result := template
	for placeholder, value := range replacements {
		result = strings.ReplaceAll(result, placeholder, value)
	}
	return ler.vm.ToValue(sanitizeFilename(result))
}

func (ler *loadedExtensionRuntime) gobackendCheckISRCExists(call goja.FunctionCall) goja.Value {
	if len(call.Arguments) < 2 {
		return ler.vm.ToValue(map[string]interface{}{"error": "outputDir and isrc required"})
	}
	outputDir := strings.TrimSpace(call.Arguments[0].String())
	isrc := strings.TrimSpace(call.Arguments[1].String())
	if outputDir == "" || isrc == "" {
		return ler.vm.ToValue(map[string]interface{}{"error": "outputDir and isrc required"})
	}
	filePath, err := core.CheckISRCExists(outputDir, isrc)
	if err != nil {
		return ler.vm.ToValue(map[string]interface{}{"exists": false, "filePath": "", "error": err.Error()})
	}
	return ler.vm.ToValue(map[string]interface{}{"exists": filePath != "", "filePath": filePath})
}

func (ler *loadedExtensionRuntime) gobackendAddToISRCIndex(call goja.FunctionCall) goja.Value {
	if len(call.Arguments) < 3 {
		return ler.vm.ToValue(map[string]interface{}{"error": "outputDir, isrc, and filePath required"})
	}
	outputDir := strings.TrimSpace(call.Arguments[0].String())
	isrc := strings.TrimSpace(call.Arguments[1].String())
	filePath := strings.TrimSpace(call.Arguments[2].String())
	if outputDir == "" || isrc == "" || filePath == "" {
		return ler.vm.ToValue(map[string]interface{}{"error": "outputDir, isrc, and filePath required"})
	}
	core.AddToISRCIndex(outputDir, isrc, filePath)
	return ler.vm.ToValue(map[string]interface{}{"success": true})
}

func (ler *loadedExtensionRuntime) gobackendGetLocalTime(call goja.FunctionCall) goja.Value {
	now := time.Now()
	_, offsetSeconds := now.Zone()
	offsetMinutes := offsetSeconds / 60
	return ler.vm.ToValue(map[string]interface{}{
		"year": now.Year(), "month": int(now.Month()), "day": now.Day(),
		"hour": now.Hour(), "minute": now.Minute(), "second": now.Second(),
		"weekday": int(now.Weekday()), "offsetMinutes": -offsetMinutes,
		"timezone": now.Location().String(), "timestamp": now.Unix(),
	})
}

func strVal(m map[string]interface{}, key string) string {
	if v, ok := m[key]; ok {
		if s, ok := v.(string); ok { return s }
		return fmt.Sprintf("%v", v)
	}
	return ""
}

func intVal(m map[string]interface{}, key string) int {
	switch v := m[key].(type) {
	case float64: return int(v)
	case int: return v
	case int64: return int(v)
	case string:
		var n int
		fmt.Sscanf(v, "%d", &n)
		return n
	default: return 0
	}
}

func (ler *loadedExtensionRuntime) gobackendGetLyricsLRC(call goja.FunctionCall) goja.Value {
	if len(call.Arguments) < 3 {
		return ler.vm.ToValue(map[string]interface{}{"error": "spotifyID, trackName, and artistName are required"})
	}
	spotifyID := strings.TrimSpace(call.Arguments[0].String())
	trackName := strings.TrimSpace(call.Arguments[1].String())
	artistName := strings.TrimSpace(call.Arguments[2].String())
	var durationMs int64
	if len(call.Arguments) > 4 && !goja.IsUndefined(call.Arguments[4]) && !goja.IsNull(call.Arguments[4]) {
		durationMs = call.Arguments[4].ToInteger()
	}

	client := lyrics.NewLyricsClient()
	durationSec := float64(durationMs) / 1000.0
	result, err := client.FetchLyricsAllSources(spotifyID, trackName, artistName, durationSec)
	if err != nil {
		return ler.vm.ToValue(map[string]interface{}{"error": err.Error()})
	}

	if result.Instrumental {
		return ler.vm.ToValue(map[string]interface{}{"lyrics": "[instrumental:true]"})
	}

	lrcContent := lyrics.ConvertToLRCWithMetadata(result, trackName, artistName)
	return ler.vm.ToValue(map[string]interface{}{"lyrics": lrcContent})
}
