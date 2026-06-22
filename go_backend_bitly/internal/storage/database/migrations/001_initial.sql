-- Bitly SQLite Database Schema v2.0
-- Normalized schema with artists, albums, tracks, sources, and files.
-- Provides 1:many relationships: artist -> albums -> tracks -> sources/files.
-- Deduplicates artists/albums by normalized_name and ISRC.
-- Keeps legacy tables (metadata, favorites) for backward compatibility
-- with existing Go functions.

-- ============================================================================
-- LEGACY TABLES (backward compat - old Go functions still write here)
-- ============================================================================

CREATE TABLE IF NOT EXISTS metadata (
    id TEXT PRIMARY KEY NOT NULL,
    track_name TEXT NOT NULL,
    artist_name TEXT NOT NULL,
    album_name TEXT NOT NULL,
    album_artist TEXT,
    isrc TEXT,
    duration_ms INTEGER DEFAULT 0,
    track_number INTEGER DEFAULT 0,
    total_tracks INTEGER DEFAULT 0,
    disc_number INTEGER DEFAULT 1,
    total_discs INTEGER DEFAULT 1,
    release_date TEXT,
    genre TEXT,
    composer TEXT,
    label TEXT,
    copyright TEXT,
    spotify_id TEXT,
    cover_url TEXT,
    cover_path TEXT
);

CREATE INDEX IF NOT EXISTS idx_metadata_spotify_id ON metadata(spotify_id);
CREATE INDEX IF NOT EXISTS idx_metadata_isrc ON metadata(isrc);
CREATE INDEX IF NOT EXISTS idx_metadata_track_artist ON metadata(track_name, artist_name);

-- ============================================================================
-- ENTIDADES CANÓNICAS (V2)
-- ============================================================================

CREATE TABLE IF NOT EXISTS artists (
    id TEXT PRIMARY KEY NOT NULL,
    name TEXT NOT NULL,
    normalized_name TEXT NOT NULL,
    image_url TEXT,
    image_path TEXT,
    provider TEXT,
    created_at TEXT NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_artists_normalized_name ON artists(normalized_name);
CREATE INDEX IF NOT EXISTS idx_artists_provider ON artists(provider);

CREATE TABLE IF NOT EXISTS albums (
    id TEXT PRIMARY KEY NOT NULL,
    artist_id TEXT NOT NULL REFERENCES artists(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    normalized_name TEXT NOT NULL,
    cover_url TEXT,
    cover_path TEXT,
    release_date TEXT,
    total_tracks INTEGER DEFAULT 0,
    album_type TEXT,
    provider TEXT,
    created_at TEXT NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_albums_artist_id ON albums(artist_id);
CREATE INDEX IF NOT EXISTS idx_albums_normalized_name ON albums(normalized_name);
CREATE INDEX IF NOT EXISTS idx_albums_provider ON albums(provider);

CREATE TABLE IF NOT EXISTS tracks (
    id TEXT PRIMARY KEY NOT NULL,
    name TEXT NOT NULL,
    artist_id TEXT NOT NULL REFERENCES artists(id) ON DELETE CASCADE,
    album_id TEXT REFERENCES albums(id) ON DELETE SET NULL,
    isrc TEXT,
    duration_ms INTEGER DEFAULT 0,
    track_number INTEGER DEFAULT 0,
    total_tracks INTEGER DEFAULT 0,
    disc_number INTEGER DEFAULT 1,
    total_discs INTEGER DEFAULT 1,
    release_date TEXT,
    genre TEXT,
    composer TEXT,
    label TEXT,
    copyright TEXT,
    cover_url TEXT,
    cover_path TEXT,
    video_path TEXT,
    lyrics_path TEXT,
    spotify_id TEXT,
    created_at TEXT NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_tracks_artist_id ON tracks(artist_id);
CREATE INDEX IF NOT EXISTS idx_tracks_album_id ON tracks(album_id);
CREATE INDEX IF NOT EXISTS idx_tracks_isrc ON tracks(isrc);
CREATE INDEX IF NOT EXISTS idx_tracks_spotify_id ON tracks(spotify_id);
CREATE INDEX IF NOT EXISTS idx_tracks_name_artist ON tracks(name, artist_id);

-- ============================================================================
-- MÚLTIPLES FUENTES POR TRACK
-- ============================================================================

CREATE TABLE IF NOT EXISTS sources (
    id TEXT PRIMARY KEY NOT NULL,
    track_id TEXT NOT NULL REFERENCES tracks(id) ON DELETE CASCADE,
    provider TEXT NOT NULL,
    external_id TEXT NOT NULL,
    quality TEXT,
    audio_quality TEXT,
    cover_url TEXT,
    metadata_json TEXT,
    created_at TEXT NOT NULL,
    UNIQUE(track_id, provider)
);

-- idx_sources_track_id is created conditionally in RunMigrationV2 (ensureTablesHaveTrackId)
-- to support existing databases that have sources without a track_id column.
CREATE INDEX IF NOT EXISTS idx_sources_provider_external ON sources(provider, external_id);

-- ============================================================================
-- ARCHIVOS FÍSICOS
-- ============================================================================

CREATE TABLE IF NOT EXISTS files (
    id TEXT PRIMARY KEY NOT NULL,
    track_id TEXT REFERENCES tracks(id) ON DELETE CASCADE,
    metadata_id TEXT,
    source_id TEXT REFERENCES sources(id) ON DELETE SET NULL,
    file_path TEXT UNIQUE NOT NULL,
    source TEXT NOT NULL CHECK(source IN ('download', 'local_scan')),
    format TEXT,
    bitrate INTEGER DEFAULT 0,
    bit_depth INTEGER DEFAULT 0,
    sample_rate INTEGER DEFAULT 0,
    downloaded_at TEXT,
    scanned_at TEXT,
    file_mod_time INTEGER DEFAULT 0,
    saf_file_name TEXT
);
-- The track_id column is ensured in RunMigrationV2 (PRAGMA check + ALTER TABLE)
-- for databases created by older schemas without it.

CREATE INDEX IF NOT EXISTS idx_files_source ON files(source);
CREATE INDEX IF NOT EXISTS idx_files_file_path ON files(file_path);

-- ============================================================================
-- JOIN TABLES (acciones del usuario)
-- ============================================================================

CREATE TABLE IF NOT EXISTS loved_tracks (
    track_id TEXT NOT NULL REFERENCES tracks(id) ON DELETE CASCADE,
    added_at TEXT NOT NULL,
    PRIMARY KEY (track_id)
);

CREATE TABLE IF NOT EXISTS favorite_artists (
    artist_id TEXT NOT NULL REFERENCES artists(id) ON DELETE CASCADE,
    added_at TEXT NOT NULL,
    PRIMARY KEY (artist_id)
);

CREATE TABLE IF NOT EXISTS favorite_albums (
    album_id TEXT NOT NULL REFERENCES albums(id) ON DELETE CASCADE,
    added_at TEXT NOT NULL,
    PRIMARY KEY (album_id)
);

CREATE TABLE IF NOT EXISTS wishlist_tracks (
    track_id TEXT NOT NULL REFERENCES tracks(id) ON DELETE CASCADE,
    added_at TEXT NOT NULL,
    PRIMARY KEY (track_id)
);

-- ============================================================================
-- PLAYLISTS & COLLECTIONS (se mantienen igual pero items referencian tracks.id)
-- ============================================================================

CREATE TABLE IF NOT EXISTS collections (
    id TEXT PRIMARY KEY NOT NULL,
    name TEXT NOT NULL,
    type TEXT,
    cover_path TEXT,
    created_at TEXT NOT NULL,
    updated_at TEXT NOT NULL,
    custom_json TEXT,
    item_json TEXT
);

CREATE INDEX IF NOT EXISTS idx_collections_updated_at ON collections(updated_at DESC);

CREATE TABLE IF NOT EXISTS collection_items (
    collection_id TEXT NOT NULL,
    item_id TEXT NOT NULL,
    track_id TEXT REFERENCES tracks(id) ON DELETE SET NULL,
    item_json TEXT,
    added_at TEXT NOT NULL,
    position INTEGER DEFAULT 0,
    PRIMARY KEY (collection_id, item_id),
    FOREIGN KEY (collection_id) REFERENCES collections(id) ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS idx_collection_items_item_id ON collection_items(item_id);
CREATE INDEX IF NOT EXISTS idx_collection_items_collection_id ON collection_items(collection_id);

-- ============================================================================
-- PLAYBACK & STATISTICS
-- ============================================================================

CREATE TABLE IF NOT EXISTS play_history (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    track_id TEXT REFERENCES tracks(id) ON DELETE SET NULL,
    track_name TEXT NOT NULL,
    artist_name TEXT NOT NULL,
    album_name TEXT,
    played_at TEXT NOT NULL,
    duration_ms INTEGER DEFAULT 0,
    percentage INTEGER DEFAULT 0
);

CREATE INDEX IF NOT EXISTS idx_play_history_played_at ON play_history(played_at DESC);
-- idx_play_history_track_id is created conditionally in RunMigrationV2 (ensureTablesHaveTrackId)
-- to support existing databases that have play_history without a track_id column.

CREATE TABLE IF NOT EXISTS play_aggregates (
    item_id TEXT PRIMARY KEY NOT NULL,
    type TEXT NOT NULL CHECK(type IN ('track', 'album', 'artist')),
    play_count INTEGER DEFAULT 0,
    last_played_at TEXT
);

CREATE INDEX IF NOT EXISTS idx_play_aggregates_type ON play_aggregates(type);
CREATE INDEX IF NOT EXISTS idx_play_aggregates_play_count ON play_aggregates(play_count DESC);

-- ============================================================================
-- APPLICATION STATE
-- ============================================================================

CREATE TABLE IF NOT EXISTS application_state (
    key TEXT PRIMARY KEY NOT NULL,
    value TEXT NOT NULL,
    updated_at TEXT NOT NULL
);

-- ============================================================================
-- DOWNLOAD QUEUE
-- ============================================================================

CREATE TABLE IF NOT EXISTS download_queue (
    id TEXT PRIMARY KEY NOT NULL,
    track_json TEXT NOT NULL,
    item_json TEXT,
    status TEXT NOT NULL DEFAULT 'pending' CHECK(status IN ('pending', 'downloading', 'completed', 'failed')),
    progress REAL DEFAULT 0.0,
    created_at TEXT NOT NULL,
    updated_at TEXT NOT NULL,
    added_at TEXT NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_download_queue_status ON download_queue(status);
CREATE INDEX IF NOT EXISTS idx_download_queue_added_at ON download_queue(added_at);

-- ============================================================================
-- RECENT ACCESS & HIDDEN DOWNLOAD IDS
-- ============================================================================

CREATE TABLE IF NOT EXISTS recent_access (
    id TEXT PRIMARY KEY NOT NULL,
    item_json TEXT NOT NULL,
    type TEXT DEFAULT 'recent',
    accessed_at TEXT NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_recent_access_accessed_at ON recent_access(accessed_at DESC);

CREATE TABLE IF NOT EXISTS hidden_download_ids (
    download_id TEXT PRIMARY KEY NOT NULL
);

-- ============================================================================
-- CACHE TABLES
-- ============================================================================

CREATE TABLE IF NOT EXISTS isrc_cache (
    isrc TEXT PRIMARY KEY,
    genre TEXT NOT NULL DEFAULT '',
    album_artist TEXT NOT NULL DEFAULT '',
    fetched_at INTEGER NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_isrc_cache_fetched_at ON isrc_cache(fetched_at);

CREATE TABLE IF NOT EXISTS video_url_cache (
    id TEXT PRIMARY KEY NOT NULL,
    track_name TEXT NOT NULL,
    artist_name TEXT NOT NULL,
    url TEXT NOT NULL,
    source TEXT DEFAULT '',
    cached_at INTEGER NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_video_url_cache_names ON video_url_cache(track_name, artist_name);
CREATE INDEX IF NOT EXISTS idx_video_url_cache_cached_at ON video_url_cache(cached_at);

-- ============================================================================
-- ACHIEVEMENTS & SECRETS (sin cambios)
-- ============================================================================

CREATE TABLE IF NOT EXISTS secret_counters (
    key TEXT PRIMARY KEY NOT NULL,
    value INTEGER DEFAULT 0
);

CREATE TABLE IF NOT EXISTS secret_unlocks (
    key TEXT PRIMARY KEY NOT NULL,
    unlocked_at TEXT NOT NULL
);

-- ============================================================================
-- USER PREMIUM & TIERS (V2)
-- ============================================================================

CREATE TABLE IF NOT EXISTS user_premium (
    id TEXT PRIMARY KEY NOT NULL DEFAULT 'default',
    tier TEXT NOT NULL DEFAULT 'free' CHECK(tier IN ('free', 'premium', 'lifetime')),
    premium_until INTEGER DEFAULT 0,
    daily_play_limit INTEGER DEFAULT 50,
    created_at TEXT NOT NULL,
    updated_at TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS user_daily_plays (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    date TEXT NOT NULL,
    play_count INTEGER DEFAULT 0,
    UNIQUE(date)
);

-- ============================================================================
-- SIMILAR ARTISTS (V2)
-- ============================================================================

CREATE TABLE IF NOT EXISTS similar_artists (
    artist_id TEXT NOT NULL REFERENCES artists(id) ON DELETE CASCADE,
    similar_artist_id TEXT NOT NULL REFERENCES artists(id) ON DELETE CASCADE,
    similarity_score REAL DEFAULT 0.0,
    created_at TEXT NOT NULL,
    PRIMARY KEY (artist_id, similar_artist_id)
);

CREATE INDEX IF NOT EXISTS idx_similar_artists_artist_id ON similar_artists(artist_id);
CREATE INDEX IF NOT EXISTS idx_similar_artists_similar_id ON similar_artists(similar_artist_id);

-- ============================================================================
-- DOWNLOAD TRACKING (V2)
-- ============================================================================

CREATE TABLE IF NOT EXISTS download_history_log (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    track_id TEXT REFERENCES tracks(id) ON DELETE SET NULL,
    album_id TEXT REFERENCES albums(id) ON DELETE SET NULL,
    file_id TEXT REFERENCES files(id) ON DELETE SET NULL,
    downloaded_at TEXT NOT NULL,
    source TEXT NOT NULL DEFAULT 'download'
);

CREATE INDEX IF NOT EXISTS idx_download_history_log_track_id ON download_history_log(track_id);
CREATE INDEX IF NOT EXISTS idx_download_history_log_album_id ON download_history_log(album_id);
