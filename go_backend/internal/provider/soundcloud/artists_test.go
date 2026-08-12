package soundcloud

import (
	"net/http"
	"strings"
	"testing"
)

func TestSearchArtists_Success(t *testing.T) {
	c := mockClient(func(req *http.Request) (*http.Response, error) {
		if !strings.Contains(req.URL.String(), "/search/users") {
			t.Errorf("expected /search/users, got: %s", req.URL.Path)
		}
		return okJSON(map[string]interface{}{
			"collection": []map[string]interface{}{
				{
					"id": 789, "username": "Test Artist",
					"avatar_url": "https://i1.sndcdn.com/avatars-test-t500x500.jpg",
				},
			},
		}), nil
	})
	results, err := c.SearchArtists("test", 5)
	if err != nil {
		t.Fatal(err)
	}
	if len(results) != 1 {
		t.Fatalf("expected 1 result, got %d", len(results))
	}
	r := results[0]
	if r.ID != "sc:789" {
		t.Errorf("ID: expected sc:789, got %s", r.ID)
	}
	if r.Name != "Test Artist" {
		t.Errorf("Name: expected Test Artist, got %s", r.Name)
	}
	if !strings.Contains(r.PictureURL, "avatars-test") {
		t.Errorf("PictureURL unexpected: %s", r.PictureURL)
	}
}
