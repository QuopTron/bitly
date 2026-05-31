-- Bitly SQLite Database Schema
-- Version: 1.0
-- Date: 2026-05-27
-- Description: Complete schema for Bitly master database

-- ============================================================================
-- METADATA & FILES (Core Audio Library)
-- ============================================================================

-- Metadata table: Stores track metadata
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

-- Files table: Stores file locations and technical metadata
CREATE TABLE IF NOT EXISTS files (
    id TEXT PRIMARY KEY NOT NULL,
    metadata_id TEXT NOT NULL,
    file_path TEXT UNIQUE NOT NULL,
    source TEXT NOT NULL CHECK(source IN ('download', 'local_scan')),
    format TEXT,
    bitrate INTEGER DEFAULT 0,
    bit_depth INTEGER DEFAULT 0,
    sample_rate INTEGER DEFAULT 0,
    downloaded_at TEXT,
    scanned_at TEXT,
    file_mod_time INTEGER DEFAULT 0,
    saf_file_name TEXT,
    FOREIGN KEY (metadata_id) REFERENCES metadata(id) ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS idx_files_metadata_id ON files(metadata_id);
CREATE INDEX IF NOT EXISTS idx_files_source ON files(source);
CREATE INDEX IF NOT EXISTS idx_files_file_path ON files(file_path);

-- ============================================================================
-- APPLICATION STATE
-- ============================================================================

-- Application state table: Stores app-wide configuration
CREATE TABLE IF NOT EXISTS application_state (
    key TEXT PRIMARY KEY NOT NULL,
    value TEXT NOT NULL,
    updated_at TEXT NOT NULL
);

-- ============================================================================
-- FAVORITES & COLLECTIONS
-- ============================================================================

-- Favorites table: Stores liked/favorited items
CREATE TABLE IF NOT EXISTS favorites (
    item_id TEXT PRIMARY KEY NOT NULL,
    type TEXT NOT NULL,
    name TEXT NOT NULL,
    secondary_name TEXT,
    cover_url TEXT,
    added_at TEXT NOT NULL,
    item_json TEXT,
    cover_path TEXT,
    audio_path TEXT,
    match_key TEXT,
    codec TEXT,
    bit_depth INTEGER,
    sample_rate INTEGER
);

CREATE INDEX IF NOT EXISTS idx_favorites_type ON favorites(type);
CREATE INDEX IF NOT EXISTS idx_favorites_added_at ON favorites(added_at DESC);

-- Collections table: Stores playlists and collections
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

-- Collection items table: Items in collections
CREATE TABLE IF NOT EXISTS collection_items (
    collection_id TEXT NOT NULL,
    item_id TEXT NOT NULL,
    metadata_id TEXT,
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

-- Play history table: Logs individual play events
CREATE TABLE IF NOT EXISTS play_history (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    track_id TEXT NOT NULL,
    track_name TEXT NOT NULL,
    artist_name TEXT NOT NULL,
    album_name TEXT,
    played_at TEXT NOT NULL,
    duration_ms INTEGER DEFAULT 0,
    percentage INTEGER DEFAULT 0
);

CREATE INDEX IF NOT EXISTS idx_play_history_played_at ON play_history(played_at DESC);
CREATE INDEX IF NOT EXISTS idx_play_history_track_id ON play_history(track_id);

-- Play aggregates table: Aggregated play counts
CREATE TABLE IF NOT EXISTS play_aggregates (
    item_id TEXT PRIMARY KEY NOT NULL,
    type TEXT NOT NULL CHECK(type IN ('track', 'album', 'artist')),
    play_count INTEGER DEFAULT 0,
    last_played_at TEXT
);

CREATE INDEX IF NOT EXISTS idx_play_aggregates_type ON play_aggregates(type);
CREATE INDEX IF NOT EXISTS idx_play_aggregates_play_count ON play_aggregates(play_count DESC);

-- ============================================================================
-- ACHIEVEMENTS & SECRETS
-- ============================================================================

-- Secret counters table: Stores achievement counters
CREATE TABLE IF NOT EXISTS secret_counters (
    key TEXT PRIMARY KEY NOT NULL,
    value INTEGER DEFAULT 0
);

-- Secret unlocks table: Tracks unlocked achievements
CREATE TABLE IF NOT EXISTS secret_unlocks (
    key TEXT PRIMARY KEY NOT NULL,
    unlocked_at TEXT NOT NULL
);

-- ============================================================================
-- DOWNLOAD QUEUE
-- ============================================================================

-- Download queue table: Manages pending downloads
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
-- RECENT ACCESS & HISTORY
-- ============================================================================

-- Recent access table: Tracks recently accessed items
CREATE TABLE IF NOT EXISTS recent_access (
    id TEXT PRIMARY KEY NOT NULL,
    item_json TEXT NOT NULL,
    type TEXT DEFAULT 'recent',
    accessed_at TEXT NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_recent_access_accessed_at ON recent_access(accessed_at DESC);

-- Hidden download IDs: Tracks hidden download history items
CREATE TABLE IF NOT EXISTS hidden_download_ids (
    download_id TEXT PRIMARY KEY NOT NULL
);

-- ============================================================================
-- CACHE TABLES
-- ============================================================================

-- ISRC cache table: Caches ISRC metadata lookups
CREATE TABLE IF NOT EXISTS isrc_cache (
    isrc TEXT PRIMARY KEY,
    genre TEXT NOT NULL DEFAULT '',
    album_artist TEXT NOT NULL DEFAULT '',
    fetched_at INTEGER NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_isrc_cache_fetched_at ON isrc_cache(fetched_at);
