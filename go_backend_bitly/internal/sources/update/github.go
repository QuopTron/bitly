// Package update provides GitHub release checking for app updates.
package update

import (
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"regexp"
	"strconv"
	"strings"
	"time"
)

// GitHubRelease represents a GitHub release.
type GitHubRelease struct {
	URL         string        `json:"url"`
	HTMLURL     string        `json:"html_url"`
	TagName     string        `json:"tag_name"`
	Name        string        `json:"name"`
	Prerelease  bool          `json:"prerelease"`
	CreatedAt   time.Time     `json:"created_at"`
	PublishedAt time.Time     `json:"published_at"`
	Body        string        `json:"body"`
	Assets      []GitHubAsset `json:"assets"`
}

// GitHubAsset represents a release asset.
type GitHubAsset struct {
	Name               string `json:"name"`
	BrowserDownloadURL string `json:"browser_download_url"`
	Size               int    `json:"size"`
	DownloadCount      int    `json:"download_count"`
}

// UpdateCheckResult is the result of a version check.
type UpdateCheckResult struct {
	Version        string    `json:"version"`
	Changelog      string    `json:"changelog"`
	DownloadURL    string    `json:"download_url"`
	PublishedAt    time.Time `json:"published_at"`
	IsPrerelease   bool      `json:"is_prerelease"`
	CurrentVersion string    `json:"current_version"`
	HasUpdate      bool      `json:"has_update"`
	Error          string    `json:"error,omitempty"`
}

const (
	githubAPIBase    = "https://api.github.com/repos"
	githubUserAgent  = "Bitly-Android/1.0"
	defaultRepo      = "QuopTron/bitly"
	httpTimeout      = 30 * time.Second
)

var httpClient = &http.Client{Timeout: httpTimeout}

// CheckGitHubUpdate checks if a newer version is available on GitHub.
func CheckGitHubUpdate(channel, currentVersion, repo string) (*UpdateCheckResult, error) {
	if repo == "" {
		repo = defaultRepo
	}

	var release *GitHubRelease
	var err error

	if channel == "preview" {
		releases, err := getAllReleases(repo, 10)
		if err != nil {
			return nil, fmt.Errorf("failed to get releases: %w", err)
		}
		if len(releases) == 0 {
			return &UpdateCheckResult{
				CurrentVersion: currentVersion,
				HasUpdate:      false,
				Error:          "No releases found",
			}, nil
		}
		release = &releases[0]
	} else {
		release, err = getLatestRelease(repo)
		if err != nil {
			return nil, fmt.Errorf("failed to get latest release: %w", err)
		}
	}

	tagName := release.TagName
	if tagName == "" {
		return &UpdateCheckResult{
			CurrentVersion: currentVersion,
			HasUpdate:      false,
			Error:          "Release has no tag name",
		}, nil
	}

	version := strings.TrimPrefix(tagName, "v")
	hasUpdate := isNewerVersion(version, currentVersion)

	return &UpdateCheckResult{
		Version:        version,
		Changelog:      release.Body,
		DownloadURL:    release.HTMLURL,
		PublishedAt:    release.PublishedAt,
		IsPrerelease:   release.Prerelease,
		CurrentVersion: currentVersion,
		HasUpdate:      hasUpdate,
	}, nil
}

func getLatestRelease(repo string) (*GitHubRelease, error) {
	url := fmt.Sprintf("%s/%s/releases/latest", githubAPIBase, repo)
	return fetchRelease(url)
}

func getAllReleases(repo string, perPage int) ([]GitHubRelease, error) {
	url := fmt.Sprintf("%s/%s/releases?per_page=%d", githubAPIBase, repo, perPage)
	req, err := http.NewRequest("GET", url, nil)
	if err != nil {
		return nil, err
	}
	req.Header.Set("Accept", "application/vnd.github.v3+json")
	req.Header.Set("User-Agent", githubUserAgent)

	resp, err := httpClient.Do(req)
	if err != nil {
		return nil, err
	}
	defer resp.Body.Close()

	var releases []GitHubRelease
	if err := json.NewDecoder(resp.Body).Decode(&releases); err != nil {
		return nil, err
	}
	return releases, nil
}

func fetchRelease(url string) (*GitHubRelease, error) {
	req, err := http.NewRequest("GET", url, nil)
	if err != nil {
		return nil, err
	}
	req.Header.Set("Accept", "application/vnd.github.v3+json")
	req.Header.Set("User-Agent", githubUserAgent)

	resp, err := httpClient.Do(req)
	if err != nil {
		return nil, err
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		body, _ := io.ReadAll(resp.Body)
		return nil, fmt.Errorf("GitHub API returned status %d: %s", resp.StatusCode, string(body))
	}

	var release GitHubRelease
	if err := json.NewDecoder(resp.Body).Decode(&release); err != nil {
		return nil, err
	}
	return &release, nil
}

func isNewerVersion(latest, current string) bool {
	latest = strings.TrimPrefix(latest, "v")
	current = strings.TrimPrefix(current, "v")

	latestParts := strings.Split(latest, "-")
	currentParts := strings.Split(current, "-")

	latestNums := parseVersionString(latestParts[0])
	currentNums := parseVersionString(currentParts[0])

	for len(latestNums) < 3 {
		latestNums = append(latestNums, 0)
	}
	for len(currentNums) < 3 {
		currentNums = append(currentNums, 0)
	}

	for i := 0; i < 3; i++ {
		if latestNums[i] > currentNums[i] {
			return true
		}
		if latestNums[i] < currentNums[i] {
			return false
		}
	}

	if len(latestParts) == 1 && len(currentParts) > 1 {
		return true
	}

	return false
}

func parseVersionString(version string) []int {
	var nums []int
	re := regexp.MustCompile(`(\d+)`)
	matches := re.FindAllString(version, -1)
	for _, m := range matches {
		if num, err := strconv.Atoi(m); err == nil {
			nums = append(nums, num)
		}
	}
	if len(nums) == 0 {
		return []int{0}
	}
	return nums
}
