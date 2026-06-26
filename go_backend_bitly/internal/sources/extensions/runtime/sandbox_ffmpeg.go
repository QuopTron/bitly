package runtime

import (
	"fmt"
	"os/exec"
	"strings"
	"sync"
	"time"

	"github.com/dop251/goja"
	"github.com/zarz/bitly/go_backend_bitly/internal/audio/metadata"
)

type FFmpegCommand struct {
	ExtensionID string
	Command     string
	InputPath   string
	OutputPath  string
	Completed   bool
	Success     bool
	Error       string
	Output      string
}

var (
	ffmpegCommands   = make(map[string]*FFmpegCommand)
	ffmpegCommandsMu sync.RWMutex
	ffmpegCommandID  int64
)

func GetPendingFFmpegCommand(commandID string) *FFmpegCommand {
	ffmpegCommandsMu.RLock()
	defer ffmpegCommandsMu.RUnlock()
	return ffmpegCommands[commandID]
}

func SetFFmpegCommandResult(commandID string, success bool, output, errorMsg string) {
	ffmpegCommandsMu.Lock()
	defer ffmpegCommandsMu.Unlock()
	if cmd, exists := ffmpegCommands[commandID]; exists {
		cmd.Completed = true
		cmd.Success = success
		cmd.Output = output
		cmd.Error = errorMsg
	}
}

func ClearFFmpegCommand(commandID string) {
	ffmpegCommandsMu.Lock()
	defer ffmpegCommandsMu.Unlock()
	delete(ffmpegCommands, commandID)
}

func (ler *loadedExtensionRuntime) registerFFmpeg() {
	ffmpegObj := ler.vm.NewObject()
	ffmpegObj.Set("execute", ler.ffmpegExecute)
	ffmpegObj.Set("getInfo", ler.ffmpegGetInfo)
	ffmpegObj.Set("convert", ler.ffmpegConvert)
	ler.vm.Set("ffmpeg", ffmpegObj)
}

func (ler *loadedExtensionRuntime) ffmpegExecute(call goja.FunctionCall) goja.Value {
	if len(call.Arguments) < 1 {
		return ler.vm.ToValue(map[string]interface{}{
			"success": false,
			"error":   "command is required",
		})
	}

	command := call.Arguments[0].String()

	cmdID := fmt.Sprintf("%s_%d", ler.extensionID, ffmpegCommandID)
	ffmpegCommandsMu.Lock()
	ffmpegCommandID++
	ffmpegCommands[cmdID] = &FFmpegCommand{
		ExtensionID: ler.extensionID,
		Command:     command,
		Completed:   false,
	}
	ffmpegCommandsMu.Unlock()

	// Try executing ffmpeg directly via os/exec (works on desktop/server)
	// This also serves as a synchronous fast path.
	cmd := exec.Command("ffmpeg", strings.Fields(command)...)
	output, err := cmd.CombinedOutput()
	if err == nil {
		ClearFFmpegCommand(cmdID)
		return ler.vm.ToValue(map[string]interface{}{
			"success": true,
			"output":  string(output),
		})
	}

	// ffmpeg binary not found or execution failed — switch to pending command
	// pattern (used on mobile where Flutter executes ffmpeg natively).
	// Check if the error is "executable file not found" vs a real ffmpeg error.
	if isFFmpegNotFound(err) {
		// Wait for Flutter to pick up and execute via SetFFmpegCommandResult
		timeout := 5 * time.Minute
		start := time.Now()
		for {
			ffmpegCommandsMu.RLock()
			cmd := ffmpegCommands[cmdID]
			completed := cmd != nil && cmd.Completed
			ffmpegCommandsMu.RUnlock()

			if completed {
				ffmpegCommandsMu.RLock()
				result := map[string]interface{}{
					"success": cmd.Success,
					"output":  cmd.Output,
				}
				if cmd.Error != "" {
					result["error"] = cmd.Error
				}
				ffmpegCommandsMu.RUnlock()

				ClearFFmpegCommand(cmdID)
				return ler.vm.ToValue(result)
			}

			if time.Since(start) > timeout {
				ClearFFmpegCommand(cmdID)
				return ler.vm.ToValue(map[string]interface{}{
					"success": false,
					"error":   "FFmpeg command timed out",
				})
			}

			time.Sleep(100 * time.Millisecond)
		}
	}

	// ffmpeg ran but returned non-zero exit code
	ClearFFmpegCommand(cmdID)
	return ler.vm.ToValue(map[string]interface{}{
		"success": false,
		"error":   string(output),
	})
}

func isFFmpegNotFound(err error) bool {
	if err == nil {
		return false
	}
	errStr := err.Error()
	return strings.Contains(errStr, "executable file not found") ||
		strings.Contains(errStr, "not found") ||
		strings.Contains(errStr, "cannot find") ||
		strings.Contains(errStr, "no such file")
}

func (ler *loadedExtensionRuntime) ffmpegGetInfo(call goja.FunctionCall) goja.Value {
	if len(call.Arguments) < 1 {
		return ler.vm.ToValue(map[string]interface{}{
			"success": false,
			"error":   "file path is required",
		})
	}

	filePath := call.Arguments[0].String()
	fullPath, err := ler.validatePath(filePath)
	if err != nil {
		return ler.vm.ToValue(map[string]interface{}{
			"success": false,
			"error":   err.Error(),
		})
	}

	q, err := metadata.GetAudioQualityFromFile(fullPath)
	if err != nil {
		return ler.vm.ToValue(map[string]interface{}{
			"success": false,
			"error":   err.Error(),
		})
	}

	return ler.vm.ToValue(map[string]interface{}{
		"success":       true,
		"bit_depth":     q.BitDepth,
		"sample_rate":   q.SampleRate,
		"total_samples": q.TotalSamples,
		"duration":      float64(q.TotalSamples) / float64(q.SampleRate),
		"codec":         q.Codec,
	})
}

func (ler *loadedExtensionRuntime) ffmpegConvert(call goja.FunctionCall) goja.Value {
	if len(call.Arguments) < 2 {
		return ler.vm.ToValue(map[string]interface{}{
			"success": false,
			"error":   "input and output paths are required",
		})
	}

	inputPath := call.Arguments[0].String()
	outputPath := call.Arguments[1].String()

	options := map[string]interface{}{}
	if len(call.Arguments) > 2 && !goja.IsUndefined(call.Arguments[2]) && !goja.IsNull(call.Arguments[2]) {
		if opts, ok := call.Arguments[2].Export().(map[string]interface{}); ok {
			options = opts
		}
	}

	var cmdParts []string
	cmdParts = append(cmdParts, "-i", inputPath)

	if codec, ok := options["codec"].(string); ok {
		cmdParts = append(cmdParts, "-c:a", codec)
	}

	if bitrate, ok := options["bitrate"].(string); ok {
		cmdParts = append(cmdParts, "-b:a", bitrate)
	}

	if sampleRate, ok := options["sample_rate"].(float64); ok {
		cmdParts = append(cmdParts, "-ar", fmt.Sprintf("%d", int(sampleRate)))
	}

	if channels, ok := options["channels"].(float64); ok {
		cmdParts = append(cmdParts, "-ac", fmt.Sprintf("%d", int(channels)))
	}

	cmdParts = append(cmdParts, "-y", outputPath)

	command := strings.Join(cmdParts, " ")

	execCall := goja.FunctionCall{
		Arguments: []goja.Value{ler.vm.ToValue(command)},
	}
	return ler.ffmpegExecute(execCall)
}
