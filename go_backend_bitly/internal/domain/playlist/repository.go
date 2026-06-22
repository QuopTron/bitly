package playlist

import (
	"database/sql"
	"fmt"
	"time"

	"github.com/zarz/bitly/go_backend_bitly/internal/domain/track"
)

// Repository handles playlist persistence.
type Repository struct {
	db *sql.DB
}

// NewRepository creates a playlist repository.
func NewRepository(db *sql.DB) *Repository {
	return &Repository{db: db}
}

// Create inserts a new playlist.
func (r *Repository) Create(p *Playlist) error {
	now := time.Now().UTC().Format(time.RFC3339)
	_, err := r.db.Exec(`
		INSERT INTO collections (id, name, description, cover_url, track_count, created_at, updated_at)
		VALUES (?, ?, ?, ?, ?, ?, ?)
	`, p.ID, p.Name, p.Description, p.CoverURL, p.TrackCount, now, now)
	return err
}

// GetByID retrieves a playlist by ID.
func (r *Repository) GetByID(id string) (*Playlist, error) {
	row := r.db.QueryRow(`
		SELECT id, name, COALESCE(description,''), COALESCE(cover_url,''), track_count, created_at, updated_at
		FROM collections WHERE id = ?
	`, id)

	var p Playlist
	err := row.Scan(&p.ID, &p.Name, &p.Description, &p.CoverURL, &p.TrackCount, &p.CreatedAt, &p.UpdatedAt)
	if err != nil {
		return nil, fmt.Errorf("get playlist: %w", err)
	}
	return &p, nil
}

// GetByUser returns all playlists for a user.
func (r *Repository) GetByUser(userID string) ([]Playlist, error) {
	rows, err := r.db.Query(`
		SELECT id, name, COALESCE(description,''), COALESCE(cover_url,''), track_count, created_at, updated_at
		FROM collections ORDER BY updated_at DESC
	`)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var playlists []Playlist
	for rows.Next() {
		var p Playlist
		if err := rows.Scan(&p.ID, &p.Name, &p.Description, &p.CoverURL, &p.TrackCount, &p.CreatedAt, &p.UpdatedAt); err != nil {
			return nil, err
		}
		playlists = append(playlists, p)
	}
	return playlists, nil
}

// AddTrack adds a track to a playlist at the given position.
func (r *Repository) AddTrack(playlistID, trackID string, position int) error {
	now := time.Now().UTC().Format(time.RFC3339)
	_, err := r.db.Exec(`
		INSERT INTO collection_items (collection_id, item_id, position, added_at)
		VALUES (?, ?, ?, ?)
	`, playlistID, trackID, position, now)
	return err
}

// RemoveTrack removes a track from a playlist.
func (r *Repository) RemoveTrack(playlistID, trackID string) error {
	_, err := r.db.Exec(`DELETE FROM collection_items WHERE collection_id = ? AND item_id = ?`, playlistID, trackID)
	return err
}

// GetTracks returns all tracks in a playlist, ordered by position.
func (r *Repository) GetTracks(playlistID string) ([]track.Track, error) {
	rows, err := r.db.Query(`
		SELECT t.id, t.title, t.normalized_title, t.artist_id, COALESCE(t.album_id,''),
			t.duration_ms, COALESCE(t.isrc,''), t.track_number, t.disc_number, t.explicit,
			t.created_at, t.updated_at
		FROM collection_items ci
		JOIN tracks t ON t.id = ci.item_id
		WHERE ci.collection_id = ?
		ORDER BY ci.position ASC
	`, playlistID)
	if err != nil {
		return nil, fmt.Errorf("get playlist tracks: %w", err)
	}
	defer rows.Close()

	var tracks []track.Track
	for rows.Next() {
		var t track.Track
		var albumID string
		if err := rows.Scan(&t.ID, &t.Title, &t.NormalizedTitle, &t.ArtistID,
			&albumID, &t.DurationMs, &t.ISRC, &t.TrackNumber, &t.DiscNumber,
			&t.Explicit, &t.CreatedAt, &t.UpdatedAt); err != nil {
			return nil, err
		}
		t.AlbumID = albumID
		tracks = append(tracks, t)
	}
	return tracks, nil
}

// Update updates a playlist's metadata.
func (r *Repository) Update(p *Playlist) error {
	now := time.Now().UTC().Format(time.RFC3339)
	_, err := r.db.Exec(`
		UPDATE collections SET name=?, description=?, cover_url=?, track_count=?, updated_at=?
		WHERE id=?
	`, p.Name, p.Description, p.CoverURL, p.TrackCount, now, p.ID)
	return err
}

// Delete removes a playlist and its items.
func (r *Repository) Delete(id string) error {
	_, err := r.db.Exec(`DELETE FROM collection_items WHERE collection_id = ?`, id)
	if err != nil {
		return err
	}
	_, err = r.db.Exec(`DELETE FROM collections WHERE id = ?`, id)
	return err
}
