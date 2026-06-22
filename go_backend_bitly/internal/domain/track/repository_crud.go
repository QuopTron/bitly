package track

import (
	"database/sql"
	"fmt"
	"time"
)

type Repository struct {
	db *sql.DB
}

func NewRepository(db *sql.DB) *Repository {
	return &Repository{db: db}
}

func (r *Repository) Create(t *Track) error {
	now := time.Now().UTC().Format(time.RFC3339)
	_, err := r.db.Exec(`
		INSERT INTO tracks (id, title, normalized_title, artist_id, album_id,
			duration_ms, isrc, track_number, disc_number, explicit, metadata, created_at, updated_at)
		VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
	`, t.ID, t.Title, t.NormalizedTitle, t.ArtistID, t.AlbumID,
		t.DurationMs, t.ISRC, t.TrackNumber, t.DiscNumber, t.Explicit,
		"{}", now, now)
	if err != nil {
		return fmt.Errorf("create track: %w", err)
	}
	return nil
}

func (r *Repository) GetByID(id string) (*Track, error) {
	row := r.db.QueryRow(`
		SELECT id, title, normalized_title, artist_id, COALESCE(album_id,''),
			duration_ms, COALESCE(isrc,''), track_number, disc_number, explicit,
			created_at, updated_at
		FROM tracks WHERE id = ?
	`, id)

	var t Track
	var albumID sql.NullString
	err := row.Scan(&t.ID, &t.Title, &t.NormalizedTitle, &t.ArtistID,
		&albumID, &t.DurationMs, &t.ISRC, &t.TrackNumber, &t.DiscNumber,
		&t.Explicit, &t.CreatedAt, &t.UpdatedAt)
	if err != nil {
		return nil, fmt.Errorf("get track: %w", err)
	}
	t.AlbumID = albumID.String
	return &t, nil
}

func (r *Repository) GetByISRC(isrc string) (*Track, error) {
	row := r.db.QueryRow(`
		SELECT id, title, normalized_title, artist_id, COALESCE(album_id,''),
			duration_ms, COALESCE(isrc,''), track_number, disc_number, explicit,
			created_at, updated_at
		FROM tracks WHERE isrc = ?
	`, isrc)

	var t Track
	var albumID sql.NullString
	err := row.Scan(&t.ID, &t.Title, &t.NormalizedTitle, &t.ArtistID,
		&albumID, &t.DurationMs, &t.ISRC, &t.TrackNumber, &t.DiscNumber,
		&t.Explicit, &t.CreatedAt, &t.UpdatedAt)
	if err != nil {
		return nil, fmt.Errorf("get track by isrc: %w", err)
	}
	t.AlbumID = albumID.String
	return &t, nil
}

func (r *Repository) GetByAlbum(albumID string) ([]Track, error) {
	rows, err := r.db.Query(`
		SELECT id, title, normalized_title, artist_id, COALESCE(album_id,''),
			duration_ms, COALESCE(isrc,''), track_number, disc_number, explicit,
			created_at, updated_at
		FROM tracks WHERE album_id = ?
		ORDER BY disc_number, track_number
	`, albumID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var tracks []Track
	for rows.Next() {
		var t Track
		var albumID sql.NullString
		if err := rows.Scan(&t.ID, &t.Title, &t.NormalizedTitle, &t.ArtistID,
			&albumID, &t.DurationMs, &t.ISRC, &t.TrackNumber, &t.DiscNumber,
			&t.Explicit, &t.CreatedAt, &t.UpdatedAt); err != nil {
			return nil, err
		}
		t.AlbumID = albumID.String
		tracks = append(tracks, t)
	}
	return tracks, nil
}

func (r *Repository) Update(t *Track) error {
	now := time.Now().UTC().Format(time.RFC3339)
	_, err := r.db.Exec(`
		UPDATE tracks SET title=?, normalized_title=?, artist_id=?, album_id=?,
			duration_ms=?, isrc=?, track_number=?, disc_number=?, explicit=?,
			updated_at=?
		WHERE id=?
	`, t.Title, t.NormalizedTitle, t.ArtistID, t.AlbumID,
		t.DurationMs, t.ISRC, t.TrackNumber, t.DiscNumber, t.Explicit,
		now, t.ID)
	return err
}
