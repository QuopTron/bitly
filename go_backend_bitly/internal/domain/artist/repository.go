package artist

import (
	"database/sql"
	"fmt"
	"strings"
)

// Repository handles artist persistence.
type Repository struct {
	db *sql.DB
}

// NewRepository creates an artist repository.
func NewRepository(db *sql.DB) *Repository {
	return &Repository{db: db}
}

// Create inserts a new artist.
func (r *Repository) Create(a *Artist) error {
	a.NormalizedName = normalizeName(a.Name)
	_, err := r.db.Exec(`
		INSERT INTO artists (id, name, normalized_name, image_url, metadata)
		VALUES (?, ?, ?, ?, ?)
	`, a.ID, a.Name, a.NormalizedName, a.ImageURL, "{}")
	return err
}

// GetByID retrieves an artist by ID.
func (r *Repository) GetByID(id string) (*Artist, error) {
	row := r.db.QueryRow(`
		SELECT id, name, normalized_name, COALESCE(image_url,'')
		FROM artists WHERE id = ?
	`, id)

	var a Artist
	err := row.Scan(&a.ID, &a.Name, &a.NormalizedName, &a.ImageURL)
	if err != nil {
		return nil, fmt.Errorf("get artist: %w", err)
	}
	return &a, nil
}

// SearchByName finds artists matching a name.
func (r *Repository) SearchByName(name string) ([]Artist, error) {
	like := "%" + strings.ToLower(name) + "%"
	rows, err := r.db.Query(`
		SELECT id, name, normalized_name, COALESCE(image_url,'')
		FROM artists WHERE normalized_name LIKE ?
		LIMIT 20
	`, like)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var artists []Artist
	for rows.Next() {
		var a Artist
		if err := rows.Scan(&a.ID, &a.Name, &a.NormalizedName, &a.ImageURL); err != nil {
			return nil, err
		}
		artists = append(artists, a)
	}
	return artists, nil
}

func normalizeName(name string) string {
	return strings.ToLower(strings.TrimSpace(name))
}


