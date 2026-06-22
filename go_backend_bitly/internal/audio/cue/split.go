package cue

import (
	"encoding/json"
	"fmt"
	"path/filepath"
)

func ParseCueFileJSON(cuePath string, audioDir string) (string, error) {
	sheet, err := ParseCueFile(cuePath)
	if err != nil {
		return "", fmt.Errorf("failed to parse cue file: %w", err)
	}

	info, err := BuildCueSplitInfo(cuePath, sheet, audioDir)
	if err != nil {
		return "", err
	}

	jsonBytes, err := json.Marshal(info)
	if err != nil {
		return "", fmt.Errorf("failed to marshal cue split info: %w", err)
	}

	return string(jsonBytes), nil
}

func BuildCueSplitInfo(cuePath string, sheet *CueSheet, audioDir string) (*CueSplitInfo, error) {
	resolveDir := cuePath
	if audioDir != "" {
		resolveDir = filepath.Join(audioDir, filepath.Base(cuePath))
	}
	audioPath := ResolveCueAudioPath(resolveDir, sheet.FileName)
	if audioPath == "" {
		return nil, fmt.Errorf("audio file not found for cue sheet: %s (referenced: %s)", cuePath, sheet.FileName)
	}

	info := &CueSplitInfo{
		CuePath:   cuePath,
		AudioPath: audioPath,
		Album:     sheet.Title,
		Artist:    sheet.Performer,
		Genre:     sheet.Genre,
		Date:      sheet.Date,
	}

	for i, track := range sheet.Tracks {
		performer := track.Performer
		if performer == "" {
			performer = sheet.Performer
		}

		composer := track.Composer
		if composer == "" {
			composer = sheet.Composer
		}

		endSec := float64(-1)
		if i+1 < len(sheet.Tracks) {
			nextTrack := sheet.Tracks[i+1]
			if nextTrack.PreGap >= 0 {
				endSec = nextTrack.PreGap
			} else {
				endSec = nextTrack.StartTime
			}
		}

		info.Tracks = append(info.Tracks, CueSplitTrack{
			Number:   track.Number,
			Title:    track.Title,
			Artist:   performer,
			ISRC:     track.ISRC,
			Composer: composer,
			StartSec: track.StartTime,
			EndSec:   endSec,
		})
	}

	return info, nil
}
