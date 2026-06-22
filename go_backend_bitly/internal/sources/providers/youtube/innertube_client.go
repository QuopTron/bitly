package youtube

import (
	"bytes"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
)

func (c *Client) searchInnerTubeClient(sc searchClient, query string) (string, error) {
	payload := searchPayload{
		Context: innertubeContext{
			Client: innertubeClient{
				Name:    sc.Name,
				Version: sc.Version,
			},
		},
		Query: query,
	}

	bodyBytes, err := json.Marshal(payload)
	if err != nil {
		return "", fmt.Errorf("marshal: %w", err)
	}

	apiURL := fmt.Sprintf("https://www.youtube.com/youtubei/v1/search?key=%s", sc.Key)
	req, err := http.NewRequest("POST", apiURL, bytes.NewReader(bodyBytes))
	if err != nil {
		return "", fmt.Errorf("create req: %w", err)
	}
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("User-Agent", c.innertubeUA)

	resp, err := c.httpClient.Do(req)
	if err != nil {
		return "", fmt.Errorf("http: %w", err)
	}
	defer resp.Body.Close()

	respBody, err := io.ReadAll(resp.Body)
	if err != nil {
		return "", fmt.Errorf("read: %w", err)
	}

	if resp.StatusCode != 200 {
		preview := respBody
		if len(preview) > 200 {
			preview = preview[:200]
		}
		return "", fmt.Errorf("HTTP %d: %s", resp.StatusCode, string(preview))
	}

	var result map[string]interface{}
	if err := json.Unmarshal(respBody, &result); err != nil {
		return "", fmt.Errorf("json: %w", err)
	}

	if errObj, ok := result["error"].(map[string]interface{}); ok {
		errMsg, _ := errObj["message"].(string)
		return "", fmt.Errorf("InnerTube error: %s", errMsg)
	}

	videoIDs := extractInnerTubeVideoIDs(result)
	fmt.Printf("[YTSearch] %s returned %d video IDs\n", sc.Name, len(videoIDs))

	maxVids := 1
	if len(videoIDs) < maxVids {
		maxVids = len(videoIDs)
	}
	for _, vid := range videoIDs[:maxVids] {
		streamURL, err := getYouTubeStreamURL(vid)
		if err == nil {
			return streamURL, nil
		}
		fmt.Printf("[YTSearch] vid %s failed: %v\n", vid, err)
		if isRateLimitError(err) {
			return "", fmt.Errorf("HTTP 429: %w", err)
		}
	}

	return "", fmt.Errorf("no usable videos")
}

func extractInnerTubeVideoIDs(data map[string]interface{}) []string {
	seen := map[string]bool{}
	var ids []string
	extractVideoIDsRecursive(data, &ids, &seen)
	return ids
}

func extractVideoIDsRecursive(v interface{}, ids *[]string, seen *map[string]bool) {
	switch val := v.(type) {
	case map[string]interface{}:
		if vid, ok := val["videoId"].(string); ok && vid != "" && len(vid) == 11 && !(*seen)[vid] {
			(*seen)[vid] = true
			*ids = append(*ids, vid)
		}
		for _, child := range val {
			extractVideoIDsRecursive(child, ids, seen)
		}
	case []interface{}:
		for _, child := range val {
			extractVideoIDsRecursive(child, ids, seen)
		}
	}
}
