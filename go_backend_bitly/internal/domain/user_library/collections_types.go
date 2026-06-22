package userlibrary

import "time"

type Collection struct {
	ID          string    `json:"id"`
	UserID      string    `json:"user_id"`
	Name        string    `json:"name"`
	Description string    `json:"description,omitempty"`
	CoverURL    string    `json:"cover_url,omitempty"`
	TrackCount  int       `json:"track_count"`
	CreatedAt   time.Time `json:"created_at"`
	UpdatedAt   time.Time `json:"updated_at"`
}

type CollectionTrack struct {
	CollectionID string    `json:"collection_id"`
	TrackID      string    `json:"track_id"`
	Position     int       `json:"position"`
	AddedAt      time.Time `json:"added_at"`
}
