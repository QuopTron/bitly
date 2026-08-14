package extensions

import (
	"fmt"
	"io"
	"net/http"
	"os"
	"path/filepath"
	"strings"
	"time"

	"github.com/dop251/goja"
	"github.com/zarz/bitly/go_backend/internal/httpclient"
)

func registerFileDownload(s *Sandbox, fileObj *goja.Object) {
	vm := s.VM

	fileObj.Set("download", func(call goja.FunctionCall) goja.Value {
		url := call.Argument(0).String()
		destPath := call.Argument(1).String()
		fullPath, resErr := resolvePath(s, destPath)
		if resErr != nil {
			return vm.ToValue(map[string]interface{}{"success": false, "error": resErr.Error()})
		}
		opts := map[string]interface{}{}
		if o := call.Argument(2).Export(); o != nil {
			if m, ok := o.(map[string]interface{}); ok {
				opts = m
			}
		}

		headers := map[string]string{}
		if h, ok := opts["headers"].(map[string]interface{}); ok {
			for k, v := range h {
				headers[k] = fmt.Sprint(v)
			}
		}

		req, err := http.NewRequest("GET", url, nil)
		if err != nil {
			return vm.ToValue(map[string]interface{}{"success": false, "error": fmt.Sprintf("request: %v", err)})
		}
		for k, v := range headers {
			req.Header.Set(k, v)
		}

		client := &http.Client{Timeout: 120 * time.Second, Transport: &http.Transport{DialContext: httpclient.NewDoHDialContext()}}
		resp, err := client.Do(req)
		if err != nil {
			return vm.ToValue(map[string]interface{}{"success": false, "error": fmt.Sprintf("http: %v", err)})
		}
		defer resp.Body.Close()

		if resp.StatusCode < 200 || resp.StatusCode >= 300 {
			return vm.ToValue(map[string]interface{}{"success": false, "error": fmt.Sprintf("HTTP %d", resp.StatusCode)})
		}

		dir := filepath.Dir(fullPath)
		if err := os.MkdirAll(dir, 0755); err != nil {
			return vm.ToValue(map[string]interface{}{"success": false, "error": fmt.Sprintf("mkdir: %v", err)})
		}

		f, err := os.Create(fullPath)
		if err != nil {
			return vm.ToValue(map[string]interface{}{"success": false, "error": fmt.Sprintf("create: %v", err)})
		}
		defer f.Close()

		if _, err := io.Copy(f, resp.Body); err != nil {
			return vm.ToValue(map[string]interface{}{"success": false, "error": fmt.Sprintf("copy: %v", err)})
		}

		return vm.ToValue(map[string]interface{}{"success": true, "path": fullPath})
	})
}

// resolvePath checks that the path is within allowed directories.
func resolvePath(s *Sandbox, path string) (string, error) {
	abs, err := filepath.Abs(path)
	if err != nil {
		return "", err
	}
	if len(s.Config.AllowedDirs) == 0 {
		return "", fmt.Errorf("file operations not allowed (no allowed dirs)")
	}
	for _, dir := range s.Config.AllowedDirs {
		allowed, _ := filepath.Abs(dir)
		if strings.HasPrefix(abs, allowed) {
			return abs, nil
		}
	}
	return "", fmt.Errorf("path %s is not in allowed directories", path)
}
