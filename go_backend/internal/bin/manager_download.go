package bin

import (
	"io"
	"os"
	"path/filepath"
	"runtime"
)

func exeSuffix() string {
	if runtime.GOOS == "windows" {
		return ".exe"
	}
	return ""
}

func ytdlpDownloadURL() string {
	base := "https://github.com/yt-dlp/yt-dlp/releases/latest/download/yt-dlp"
	switch runtime.GOOS {
	case "windows":
		return base + ".exe"
	case "darwin":
		switch runtime.GOARCH {
		case "arm64":
			return base + "_macos_arm64"
		default:
			return base + "_macos"
		}
	case "linux":
		switch runtime.GOARCH {
		case "arm64":
			return base + "_linux_aarch64"
		case "arm":
			return base + "_linux_arm"
		default:
			return base + "_linux"
		}
	case "android":
		// yt-dlp publishes an Android NDK build under the community repo.
		switch runtime.GOARCH {
		case "arm64":
			return "https://github.com/yt-dlp/yt-dlp-android-builds/releases/latest/download/yt-dlp_android-arm64"
		case "arm":
			return "https://github.com/yt-dlp/yt-dlp-android-builds/releases/latest/download/yt-dlp_android-arm"
		default:
			return "https://github.com/yt-dlp/yt-dlp-android-builds/releases/latest/download/yt-dlp_android-x86_64"
		}
	default:
		return ""
	}
}

func ffmpegDownloadURL() string {
	// Static ffmpeg builds from johnvansickle (Linux) and gyan.dev (Windows)
	// cover desktop; mobile relies on embedded/extended providers instead.
	switch runtime.GOOS {
	case "linux":
		switch runtime.GOARCH {
		case "arm64":
			return "https://johnvansickle.com/ffmpeg/releases/ffmpeg-release-arm64-static.tar.xz"
		case "arm":
			return "https://johnvansickle.com/ffmpeg/releases/ffmpeg-release-armhf-static.tar.xz"
		default:
			return "https://johnvansickle.com/ffmpeg/releases/ffmpeg-release-amd64-static.tar.xz"
		}
	case "darwin":
		return ""
	default:
		return ""
	}
}

func (m *Manager) download(url, dest string, mode os.FileMode) error {
	resp, err := m.http.Get(url)
	if err != nil {
		return err
	}
	defer resp.Body.Close()

	if err := os.MkdirAll(filepath.Dir(dest), 0755); err != nil {
		return err
	}

	out, err := os.CreateTemp(filepath.Dir(dest), "download-*")
	if err != nil {
		return err
	}
	tmpPath := out.Name()

	if _, err := io.Copy(out, resp.Body); err != nil {
		out.Close()
		os.Remove(tmpPath)
		return err
	}
	out.Close()

	if err := os.Chmod(tmpPath, mode); err != nil {
		os.Remove(tmpPath)
		return err
	}

	return os.Rename(tmpPath, dest)
}
