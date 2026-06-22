package album

import (
	"database/sql"
	"fmt"
)

// Repository handles album persistence.
type Repository struct {
	db *sql.DB
}

// NewRepository creates an album repository.
func NewRepository(db *sql.DB) *Repository {
	return &Repository{db: db}
}

// Create inserts a new album.
func (r *Repository) Create(a *Album) error {
	_, err := r.db.Exec(`
		INSERT INTO albums (id, title, artist_id, year, cover_url, track_count, metadata)
		VALUES (?, ?, ?, ?, ?, ?, ?)
	`, a.ID, a.Title, a.ArtistID, a.Year, a.CoverURL, a.TrackCount, "{}")
	return err
}

// GetByID retrieves an album by ID.
func (r *Repository) GetByID(id string) (*Album, error) {
	row := r.db.QueryRow(`
		SELECT id, title, artist_id, COALESCE(year,0), COALESCE(cover_url,''), track_count
		FROM albums WHERE id = ?
	`, id)

	var a Album
	err := row.Scan(&a.ID, &a.Title, &a.ArtistID, &a.Year, &a.CoverURL, &a.TrackCount)
	if err != nil {
		return nil, fmt.Errorf("get album: %w", err)
	}
	return &a, nil
}

// GetByArtist returns all albums for an artist.
func (r *Repository) GetByArtist(artistID string) ([]Album, error) {
	rows, err := r.db.Query(`
		SELECT id, title, artist_id, COALESCE(year,0), COALESCE(cover_url,''), track_count
		FROM albums WHERE artist_id = ?
		ORDER BY year DESC
	`, artistID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var albums []Album
	for rows.Next() {
		var a Album
		if err := rows.Scan(&a.ID, &a.Title, &a.ArtistID, &a.Year, &a.CoverURL, &a.TrackCount); err != nil {
			return nil, err
		}
		albums = append(albums, a)
	}
	return albums, nil
}


