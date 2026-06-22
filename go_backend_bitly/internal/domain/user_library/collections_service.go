package userlibrary

import (
	"database/sql"
	"time"
)

type CollectionService struct {
	db *sql.DB
}

func NewCollectionService(db *sql.DB) *CollectionService {
	return &CollectionService{db: db}
}

func (s *CollectionService) Create(c *Collection) error {
	_, err := s.db.Exec(`
		INSERT INTO collections (id, user_id, name, description, cover_url, created_at, updated_at)
		VALUES (?, ?, ?, ?, ?, ?, ?)
	`, c.ID, c.UserID, c.Name, c.Description, c.CoverURL,
		c.CreatedAt.Format(time.RFC3339), c.UpdatedAt.Format(time.RFC3339))
	return err
}

func (s *CollectionService) GetByID(id string) (*Collection, error) {
	var c Collection
	var createdAt, updatedAt string
	err := s.db.QueryRow(`
		SELECT id, user_id, name, COALESCE(description,''), COALESCE(cover_url,''), created_at, updated_at
		FROM collections WHERE id = ?
	`, id).Scan(&c.ID, &c.UserID, &c.Name, &c.Description, &c.CoverURL, &createdAt, &updatedAt)
	if err != nil {
		return nil, err
	}
	c.CreatedAt, _ = time.Parse(time.RFC3339, createdAt)
	c.UpdatedAt, _ = time.Parse(time.RFC3339, updatedAt)
	return &c, nil
}

func (s *CollectionService) GetByUser(userID string) ([]Collection, error) {
	rows, err := s.db.Query(`
		SELECT c.id, c.user_id, c.name, COALESCE(c.description,''), COALESCE(c.cover_url,''),
			COALESCE((SELECT COUNT(*) FROM collection_tracks ct WHERE ct.collection_id = c.id), 0),
			c.created_at, c.updated_at
		FROM collections c WHERE c.user_id = ? ORDER BY c.updated_at DESC
	`, userID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var cols []Collection
	for rows.Next() {
		var c Collection
		var createdAt, updatedAt string
		if err := rows.Scan(&c.ID, &c.UserID, &c.Name, &c.Description, &c.CoverURL,
			&c.TrackCount, &createdAt, &updatedAt); err != nil {
			return nil, err
		}
		c.CreatedAt, _ = time.Parse(time.RFC3339, createdAt)
		c.UpdatedAt, _ = time.Parse(time.RFC3339, updatedAt)
		cols = append(cols, c)
	}
	return cols, nil
}

func (s *CollectionService) AddTrack(collectionID, trackID string, position int) error {
	_, err := s.db.Exec(`
		INSERT INTO collection_tracks (collection_id, track_id, position, added_at)
		VALUES (?, ?, ?, ?)
		ON CONFLICT(collection_id, track_id) DO UPDATE SET position=excluded.position
	`, collectionID, trackID, position, time.Now().UTC().Format(time.RFC3339))
	if err != nil {
		return err
	}
	_, err = s.db.Exec(`UPDATE collections SET updated_at = ? WHERE id = ?`,
		time.Now().UTC().Format(time.RFC3339), collectionID)
	return err
}

func (s *CollectionService) RemoveTrack(collectionID, trackID string) error {
	_, err := s.db.Exec(`DELETE FROM collection_tracks WHERE collection_id = ? AND track_id = ?`,
		collectionID, trackID)
	if err != nil {
		return err
	}
	_, err = s.db.Exec(`UPDATE collections SET updated_at = ? WHERE id = ?`,
		time.Now().UTC().Format(time.RFC3339), collectionID)
	return err
}

func (s *CollectionService) Update(c *Collection) error {
	_, err := s.db.Exec(`
		UPDATE collections SET name = ?, description = ?, cover_url = ?, updated_at = ?
		WHERE id = ?
	`, c.Name, c.Description, c.CoverURL, time.Now().UTC().Format(time.RFC3339), c.ID)
	return err
}

func (s *CollectionService) Delete(id string) error {
	_, err := s.db.Exec(`DELETE FROM collection_tracks WHERE collection_id = ?`, id)
	if err != nil {
		return err
	}
	_, err = s.db.Exec(`DELETE FROM collections WHERE id = ?`, id)
	return err
}
