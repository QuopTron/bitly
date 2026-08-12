package main

import (
	"encoding/json"
	"fmt"
	"time"

	"github.com/zarz/bitly/go_backend/internal/bundled_extensions"
	"github.com/zarz/bitly/go_backend/internal/extensions"
)

func main() {
	fmt.Println("=== Test YT Music getHomeFeed() en sandbox goja ===")

	// Create extension registry which creates its own runtime
	reg, err := extensions.NewRegistry(".")
	if err != nil {
		fmt.Printf("ERROR creating registry: %v\n", err)
		return
	}

	// Load all bundled extensions
	list := bundled_extensions.LoadAllToRegistry(reg)
	fmt.Printf("Loaded %d bundled extensions\n", len(list))
	for _, ext := range list {
		fmt.Printf("  - %s (%s) [%s]\n", ext.ID, ext.Name, ext.Type)
	}

	// Wait a moment for the JS to fully initialize
	time.Sleep(100 * time.Millisecond)

	rt := reg.Runtime()

	// Test searchTracks first to see if the extension is alive
	fmt.Println("\n=== Testing searchTracks ===")
	searchStart := time.Now()
	searchResult, err := rt.CallMethod("ytmusic-spotiflac", "searchTracks", "queen", 3)
	searchElapsed := time.Since(searchStart)
	if err != nil {
		fmt.Printf("ERROR searchTracks: %v (elapsed: %v)\n", err, searchElapsed)
	} else {
		fmt.Printf("SearchTracks took: %v\n", searchElapsed)
		raw, _ := json.MarshalIndent(searchResult, "", "  ")
		resultStr := string(raw)
		if len(resultStr) > 2000 {
			resultStr = resultStr[:2000] + "..."
		}
		fmt.Printf("Search results:\n%s\n", resultStr)
	}

	// Call getHomeFeed
	fmt.Println("\n=== Testing getHomeFeed ===")
	start := time.Now()
	result, err := rt.CallMethod("ytmusic-spotiflac", "getHomeFeed")
	elapsed := time.Since(start)

	if err != nil {
		fmt.Printf("ERROR calling getHomeFeed: %v (elapsed: %v)\n", err, elapsed)
		return
	}

	fmt.Printf("Call took: %v\n", elapsed)

	if result == nil {
		fmt.Println("Result: nil")
		return
	}

	// Check the success field and sections length
	if resultMap, ok := result.(map[string]interface{}); ok {
		success, _ := resultMap["success"].(bool)
		fmt.Printf("Success: %v\n", success)

		if sections, ok := resultMap["sections"].([]interface{}); ok {
			fmt.Printf("Sections count: %d\n", len(sections))
			for i, s := range sections {
				if sMap, ok := s.(map[string]interface{}); ok {
					title, _ := sMap["title"].(string)
					if items, ok := sMap["items"].([]interface{}); ok {
						fmt.Printf("  Section %d: %q (%d items)\n", i+1, title, len(items))
					} else {
						fmt.Printf("  Section %d: %q (no items)\n", i+1, title)
					}
				}
			}
		} else {
			fmt.Println("No sections array found")
		}

		if errStr, ok := resultMap["error"].(string); ok && errStr != "" {
			fmt.Printf("Error: %s\n", errStr)
		}
	}

	raw, _ := json.MarshalIndent(result, "", "  ")
	resultStr := string(raw)
	if len(resultStr) > 3000 {
		resultStr = resultStr[:3000] + "..."
	}
	fmt.Printf("\nResult (truncated):\n%s\n", resultStr)
}
