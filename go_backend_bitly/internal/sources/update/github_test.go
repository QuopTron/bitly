package update

import (
	"encoding/json"
	"fmt"
	"net/http"
	"strings"
	"testing"
	"time"
)

func TestGitHubReleaseTypes(t *testing.T) {
	r := GitHubRelease{
		TagName: "v1.0.0",
		Assets:  []GitHubAsset{{Name: "app.apk", Size: 100, DownloadCount: 10}},
	}
	if r.TagName != "v1.0.0" {
		t.Errorf("TagName = %q", r.TagName)
	}
	if len(r.Assets) != 1 {
		t.Errorf("assets = %d", len(r.Assets))
	}
}

func TestUpdateCheckResult(t *testing.T) {
	r := &UpdateCheckResult{
		Version: "1.0.0", CurrentVersion: "0.9.0", HasUpdate: true,
	}
	if r.Version != "1.0.0" {
		t.Errorf("Version = %q", r.Version)
	}
}

func TestCheckGitHubUpdate_DefaultRepo(t *testing.T) {
	handler := http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if strings.Contains(r.URL.Path, "/releases/latest") {
			json.NewEncoder(w).Encode(GitHubRelease{
				TagName: "v2.0.0", HTMLURL: "https://github.com/releases/2",
				Body: "New version", PublishedAt: time.Now(),
			})
			return
		}
		w.WriteHeader(http.StatusNotFound)
	})
	origClient := httpClient
	httpClient = testHTTPClient(handler)
	defer func() { httpClient = origClient }()

	result, err := CheckGitHubUpdate("stable", "1.0.0", "")
	if err != nil {
		t.Fatal(err)
	}
	if !result.HasUpdate {
		t.Error("expected HasUpdate = true")
	}
	if result.Version != "2.0.0" {
		t.Errorf("Version = %q", result.Version)
	}
}

func TestCheckGitHubUpdate_NoTag(t *testing.T) {
	handler := http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		json.NewEncoder(w).Encode(GitHubRelease{TagName: "", HTMLURL: ""})
	})
	origClient := httpClient
	httpClient = testHTTPClient(handler)
	defer func() { httpClient = origClient }()

	result, err := CheckGitHubUpdate("stable", "1.0.0", "owner/repo")
	if err != nil {
		t.Fatal(err)
	}
	if result.HasUpdate {
		t.Error("expected HasUpdate = false for empty tag")
	}
	if result.Error == "" {
		t.Error("expected error message for empty tag")
	}
}

func TestCheckGitHubUpdate_PreviewChannel(t *testing.T) {
	handler := http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		json.NewEncoder(w).Encode([]GitHubRelease{
			{TagName: "v3.0.0-preview", HTMLURL: "https://github.com/preview"},
		})
	})
	origClient := httpClient
	httpClient = testHTTPClient(handler)
	defer func() { httpClient = origClient }()

	result, err := CheckGitHubUpdate("preview", "2.0.0", "owner/repo")
	if err != nil {
		t.Fatal(err)
	}
	if !result.HasUpdate {
		t.Error("expected HasUpdate for preview")
	}
}

func TestCheckGitHubUpdate_EmptyReleases(t *testing.T) {
	handler := http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		json.NewEncoder(w).Encode([]GitHubRelease{})
	})
	origClient := httpClient
	httpClient = testHTTPClient(handler)
	defer func() { httpClient = origClient }()

	result, err := CheckGitHubUpdate("preview", "1.0.0", "owner/repo")
	if err != nil {
		t.Fatal(err)
	}
	if result.HasUpdate {
		t.Error("expected HasUpdate = false")
	}
	if result.Error != "No releases found" {
		t.Errorf("Error = %q", result.Error)
	}
}

func TestCheckGitHubUpdate_HTTPError(t *testing.T) {
	handler := http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(http.StatusInternalServerError)
		fmt.Fprint(w, `server error`)
	})
	origClient := httpClient
	httpClient = testHTTPClient(handler)
	defer func() { httpClient = origClient }()

	_, err := CheckGitHubUpdate("stable", "1.0.0", "owner/repo")
	if err == nil {
		t.Fatal("expected error for HTTP 500")
	}
}
