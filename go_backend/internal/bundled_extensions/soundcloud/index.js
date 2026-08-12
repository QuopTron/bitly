// ============================================
// SoundCloud Extension for SpotiFLAC
// Version: 1.0.0
//
// Uses SoundCloud's internal api-v2 for metadata and direct progressive streams.
//
// client_id is extracted from SoundCloud's JS bundles
// (same pattern as Apple Music developer token extraction).
// ============================================

var SC_API = "https://api-v2.soundcloud.com";

var state = {
  clientId: null,
  clientIdExpiry: 0,
  scVersion: "",
};

// ============================================
// INITIALIZATION
// ============================================

function initialize(config) {
  log.info("[SC] SoundCloud Extension initializing...");

  try {
    var cached = storage.get("sc_state");
    if (cached) {
      var parsed = JSON.parse(cached);
      if (
        parsed.clientId &&
        parsed.clientIdExpiry &&
        Date.now() < parsed.clientIdExpiry
      ) {
        state.clientId = parsed.clientId;
        state.clientIdExpiry = parsed.clientIdExpiry;
        state.scVersion = parsed.scVersion || "";
        log.info(
          "[SC] Loaded cached client_id (expires in " +
            Math.round((state.clientIdExpiry - Date.now()) / 60000) +
            " min)",
        );
      }
    }
  } catch (e) {}

  return true;
}

function cleanup() {
  try {
    storage.set(
      "sc_state",
      JSON.stringify({
        clientId: state.clientId,
        clientIdExpiry: state.clientIdExpiry,
        scVersion: state.scVersion,
      }),
    );
  } catch (e) {}
}

function userAgentForURL(url) {
  return utils.randomUserAgent();
}

// ============================================
// CLIENT ID EXTRACTION
// ============================================

function fetchClientIdOnce() {
  log.info("[SC] Fetching SoundCloud client_id...");

  var response = http.get("https://soundcloud.com/", {
    "User-Agent": utils.randomUserAgent(),
    "Accept-Encoding": "identity",
  });

  if (!response || response.error || response.statusCode !== 200) {
    throw new Error(
      "Failed to fetch soundcloud.com: HTTP " +
        (response ? response.statusCode : "no response"),
    );
  }

  var body = response.body || "";

  // Extract __sc_version for cache key
  var versionMatch = body.match(/__sc_version="(\d{10})"/);
  if (versionMatch) {
    var newVersion = versionMatch[1];
    if (newVersion === state.scVersion && state.clientId) {
      log.info("[SC] SoundCloud version unchanged, reusing cached client_id");
      return;
    }
    state.scVersion = newVersion;
  }

  // Strategy 1: Look for client_id directly in HTML
  var directMatch = body.match(/client_id[:=]["']([a-zA-Z0-9]{32})["']/);
  if (directMatch) {
    state.clientId = directMatch[1];
    state.clientIdExpiry = Date.now() + 24 * 60 * 60 * 1000; // 24h
    log.info("[SC] Found client_id in HTML");
    return;
  }

  // Strategy 2: Extract from JS bundles at a-v2.sndcdn.com
  var scriptMatches = body.match(
    /src="(https:\/\/a-v2\.sndcdn\.com\/assets\/[^"]+\.js)"/g,
  );
  if (!scriptMatches) {
    // Fallback: any script with sndcdn
    scriptMatches = body.match(/src="(https:\/\/[^"]*sndcdn\.com[^"]*\.js)"/g);
  }

  if (scriptMatches) {
    // Prioritize the main _app bundle, then process the rest from last to
    // first (client_id usually lives in a later bundle).
    var order = [];
    var appIndex = -1;
    for (var ai = 0; ai < scriptMatches.length; ai++) {
      if (scriptMatches[ai].indexOf("_app-") !== -1) {
        appIndex = ai;
        break;
      }
    }
    if (appIndex !== -1) order.push(appIndex);
    for (var oi = scriptMatches.length - 1; oi >= 0; oi--) {
      if (oi !== appIndex) order.push(oi);
    }
    for (var oi2 = 0; oi2 < order.length && oi2 < 10; oi2++) {
      var i = order[oi2];
      var srcMatch = scriptMatches[i].match(/src="([^"]+)"/);
      if (!srcMatch) continue;

      var bundleURL = srcMatch[1];
      log.debug(
        "[SC] Checking bundle:",
        bundleURL.substring(bundleURL.lastIndexOf("/") + 1),
      );

      try {
        var bundleResp = http.get(bundleURL, {
          "User-Agent": utils.randomUserAgent(),
          "Accept-Encoding": "identity",
        });

        if (bundleResp && !bundleResp.error && bundleResp.statusCode === 200) {
          var bundleBody = bundleResp.body || "";

          // Look for client_id pattern: client_id:"XXXX" or client_id=XXXX
          var cidMatch = bundleBody.match(
            /client_id[:=]["']([a-zA-Z0-9]{32})["']/,
          );
          if (!cidMatch) {
            // Alternative pattern: ("client_id=XXXXX")
            cidMatch = bundleBody.match(/\("client_id=([a-zA-Z0-9]{32})"\)/);
          }
          if (!cidMatch) {
            // client_id=XXXXX within a string
            var idx = bundleBody.indexOf("client_id=");
            if (idx !== -1) {
              var start = idx + 10;
              var end = start;
              var chars =
                "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789";
              while (
                end < bundleBody.length &&
                end - start < 32 &&
                chars.indexOf(bundleBody.charAt(end)) !== -1
              ) {
                end++;
              }
              if (end - start === 32) {
                cidMatch = [null, bundleBody.substring(start, end)];
              }
            }
          }

          if (cidMatch) {
            state.clientId = cidMatch[1];
            state.clientIdExpiry = Date.now() + 24 * 60 * 60 * 1000;
            log.info("[SC] Found client_id in JS bundle");
            return;
          }
        }
      } catch (e) {
        log.debug("[SC] Bundle fetch failed:", e.message);
      }
    }
  }

  throw new Error("Could not find SoundCloud client_id in page or JS bundles");
}

// Retry wrapper: the homepage layout varies and client_id may not appear on
// the first attempt, so try up to 3 times before giving up.
function fetchClientId() {
  var lastErr = null;
  for (var attempt = 0; attempt < 3; attempt++) {
    try {
      fetchClientIdOnce();
      if (state.clientId) return;
    } catch (e) {
      lastErr = e;
      state.clientId = null;
      state.clientIdExpiry = 0;
    }
  }
  throw lastErr || new Error("Could not find SoundCloud client_id");
}

function ensureClientId() {
  if (!state.clientId || Date.now() >= state.clientIdExpiry) {
    fetchClientId();
  }
}

// ============================================
// API HELPERS
// ============================================

function scGet(path, extraParams) {
  ensureClientId();

  var sep = path.indexOf("?") === -1 ? "?" : "&";
  var url = SC_API + "/" + path + sep + "client_id=" + state.clientId;
  if (extraParams) {
    url += "&" + extraParams;
  }

  var response = http.get(url, {
    "User-Agent": utils.randomUserAgent(),
    Accept: "application/json",
  });

  if (!response || response.error) {
    throw new Error(
      "SoundCloud API failed: " + (response ? response.error : "no response"),
    );
  }

  if (response.statusCode === 401) {
    // client_id may be invalid, try refreshing
    log.info("[SC] Got 401, refreshing client_id...");
    state.clientId = null;
    state.clientIdExpiry = 0;
    ensureClientId();
    // Retry once
    sep = path.indexOf("?") === -1 ? "?" : "&";
    url = SC_API + "/" + path + sep + "client_id=" + state.clientId;
    if (extraParams) url += "&" + extraParams;
    response = http.get(url, {
      "User-Agent": utils.randomUserAgent(),
      Accept: "application/json",
    });
    if (!response || response.statusCode !== 200) {
      throw new Error(
        "SoundCloud API failed after retry: HTTP " +
          (response ? response.statusCode : "no response"),
      );
    }
  }

  if (response.statusCode !== 200) {
    throw new Error("SoundCloud API returned HTTP " + response.statusCode);
  }

  return JSON.parse(response.body);
}

/**
 * Resolve a SoundCloud URL to its API object.
 */
function scResolve(url) {
  return scGet("resolve?url=" + encodeURIComponent(url));
}

/**
 * Artwork URL helper. Replace -large with higher resolution suffix.
 */
function hiResArtwork(url) {
  if (!url) return "";
  return url.replace("-large.", "-t500x500.");
}

function originalArtwork(url) {
  if (!url) return "";
  return url.replace("-large.", "-original.");
}

// ============================================
// FORMAT HELPERS
// ============================================

function formatTrack(track) {
  if (!track || !track.id) return null;

  var attr = track;
  var user = attr.user || {};
  var pub = attr.publisher_metadata || {};

  var artist = pub.artist || attr.metadata_artist || user.username || "";
  var albumName = pub.album_title || pub.release_title || "";

  // Build cover URL — prefer original, fallback to t500x500
  var coverURL = originalArtwork(attr.artwork_url);
  if (!coverURL && user.avatar_url) {
    coverURL = hiResArtwork(user.avatar_url);
  }

  return {
    id: String(attr.id),
    name: attr.title || "",
    artists: artist,
    album_name: albumName,
    album_artist: user.username || "",
    duration_ms: attr.full_duration || attr.duration || 0,
    cover_url: coverURL,
    images: coverURL,
    release_date: formatDate(attr.display_date || attr.created_at),
    track_number: 0,
    disc_number: 1,
    isrc: pub.isrc || attr.isrc || "",
    label: attr.label_name || "",
    copyright: pub.p_line_for_display || pub.c_line_for_display || "",
    genre: attr.genre || "",
    composer: pub.writer_composer || "",
    external_urls: attr.permalink_url || "",
    provider_id: "soundcloud",
    item_type: "track",
  };
}

function formatPlaylistOrAlbum(playlist) {
  if (!playlist || !playlist.id) return null;

  var user = playlist.user || {};
  var isAlbum =
    playlist.is_album ||
    playlist.set_type === "album" ||
    playlist.set_type === "ep" ||
    playlist.set_type === "compilation" ||
    playlist.set_type === "single";

  var coverURL = originalArtwork(playlist.artwork_url);
  if (!coverURL && user.avatar_url) {
    coverURL = hiResArtwork(user.avatar_url);
  }

  var albumType = playlist.set_type || (isAlbum ? "album" : "playlist");

  return {
    id: String(playlist.id),
    name: playlist.title || "",
    artists: user.username || "",
    artist_id: user.id ? String(user.id) : "",
    images: coverURL,
    cover_url: coverURL,
    release_date: formatDate(
      playlist.display_date || playlist.published_at || playlist.created_at,
    ),
    total_tracks: playlist.track_count || 0,
    album_type: albumType,
    record_label: playlist.label_name || "",
    genre: playlist.genre || "",
    provider_id: "soundcloud",
    item_type: isAlbum ? "album" : "playlist",
  };
}

function formatUser(user) {
  if (!user || !user.id) return null;

  var avatarURL = originalArtwork(user.avatar_url);

  return {
    id: String(user.id),
    name: user.username || user.full_name || "",
    image_url: avatarURL,
    images: avatarURL,
    listeners: user.followers_count || 0,
    provider_id: "soundcloud",
    item_type: "artist",
  };
}

function formatDate(dateStr) {
  if (!dateStr) return "";
  return dateStr.substring(0, 10);
}

// ============================================
// FETCH FUNCTIONS
// ============================================

function fetchTrack(trackId) {
  log.info("[SC] Fetching track:", trackId);
  var data = scGet("tracks/" + trackId);
  return formatTrack(data);
}

function fetchPlaylistOrAlbum(playlistId) {
  log.info("[SC] Fetching playlist/album:", playlistId);
  var data = scGet("playlists/" + playlistId + "?representation=full");

  var info = formatPlaylistOrAlbum(data);
  if (!info) throw new Error("Failed to format playlist/album");

  var tracks = [];
  var trackItems = data.tracks || [];

  // SoundCloud may return abbreviated tracks — collect full IDs for batch fetch
  var needFullFetch = [];
  for (var i = 0; i < trackItems.length; i++) {
    var t = trackItems[i];
    if (t.title) {
      // Full track object
      var ft = formatTrack(t);
      if (ft) {
        ft.track_number = i + 1;
        tracks.push(ft);
      }
    } else if (t.id) {
      // Abbreviated — just has id
      needFullFetch.push(t.id);
    }
  }

  // Batch fetch missing tracks (API supports comma-separated IDs)
  if (needFullFetch.length > 0) {
    var batchSize = 50;
    for (var b = 0; b < needFullFetch.length; b += batchSize) {
      var batch = needFullFetch.slice(b, b + batchSize);
      try {
        var batchData = scGet("tracks?ids=" + batch.join(","));
        if (batchData && batchData.length) {
          // Build ID->track map for ordering
          var trackMap = {};
          for (var j = 0; j < batchData.length; j++) {
            trackMap[batchData[j].id] = batchData[j];
          }
          for (var k = 0; k < batch.length; k++) {
            var fullTrack = trackMap[batch[k]];
            if (fullTrack) {
              var formatted = formatTrack(fullTrack);
              if (formatted) {
                formatted.track_number = tracks.length + 1;
                tracks.push(formatted);
              }
            }
          }
        }
      } catch (e) {
        log.debug("[SC] Batch track fetch failed:", e.message);
      }
    }
  }

  info.total_tracks = tracks.length;
  return { info: info, tracks: tracks };
}

function fetchArtist(userId) {
  log.info("[SC] Fetching artist:", userId);
  var userData = scGet("users/" + userId);
  var artistInfo = formatUser(userData);
  if (!artistInfo) throw new Error("Failed to format user");

  // Fetch top tracks
  var topTracks = [];
  try {
    var topData = scGet("users/" + userId + "/toptracks", "limit=20");
    var topItems = topData.collection || topData || [];
    if (Array.isArray(topItems)) {
      for (var i = 0; i < topItems.length; i++) {
        var t = formatTrack(topItems[i]);
        if (t) topTracks.push(t);
      }
    }
  } catch (e) {
    log.debug("[SC] Top tracks fetch failed:", e.message);
    // Fallback to recent tracks
    try {
      var recentData = scGet("users/" + userId + "/tracks", "limit=20");
      var recentItems = recentData.collection || recentData || [];
      if (Array.isArray(recentItems)) {
        for (var ri = 0; ri < recentItems.length; ri++) {
          var rt = formatTrack(recentItems[ri]);
          if (rt) topTracks.push(rt);
        }
      }
    } catch (e2) {
      log.debug("[SC] Recent tracks fetch failed:", e2.message);
    }
  }

  // Fetch albums
  var albums = [];
  try {
    var albumData = scGet("users/" + userId + "/albums", "limit=50");
    var albumItems = albumData.collection || albumData || [];
    if (Array.isArray(albumItems)) {
      for (var a = 0; a < albumItems.length; a++) {
        var albumInfo = formatPlaylistOrAlbum(albumItems[a]);
        if (albumInfo) albums.push(albumInfo);
      }
    }
  } catch (e) {
    log.debug("[SC] Albums fetch failed:", e.message);
  }

  return {
    type: "artist",
    artist: {
      id: artistInfo.id,
      name: artistInfo.name,
      image_url: artistInfo.image_url,
      listeners: artistInfo.listeners,
      albums: albums,
      top_tracks: topTracks,
      provider_id: "soundcloud",
    },
  };
}

// ============================================
// SEARCH
// ============================================

function customSearch(query, options) {
  log.info("[SC] Searching:", query);

  var limit = (options && options.limit) || 20;
  var offset = (options && options.offset) || 0;
  var filter = (options && options.filter) || null;
  if (limit <= 0 || limit > 50) limit = 50;

  // Normalize singular/plural filter forms ("track"/"song" -> "tracks", etc.)
  if (filter) {
    var nf = String(filter).toLowerCase();
    if (nf === "song" || nf === "track") filter = "tracks";
    else if (nf === "album") filter = "albums";
    else if (nf === "artist") filter = "artists";
    else if (nf === "playlist") filter = "playlists";
  }

  var isFiltered = filter && filter !== "all";
  var results = [];

  // Determine which types to search
  var searchTypes = ["tracks", "albums", "users", "playlists"];
  if (isFiltered) {
    var typeMap = {
      tracks: "tracks",
      albums: "albums",
      artists: "users",
      playlists: "playlists",
    };
    searchTypes = [typeMap[filter] || "tracks"];
  }

  for (var ti = 0; ti < searchTypes.length; ti++) {
    var searchType = searchTypes[ti];
    var searchLimit = isFiltered ? limit : searchType === "tracks" ? limit : 5;

    try {
      var data = scGet(
        "search/" + searchType + "?q=" + encodeURIComponent(query),
        "limit=" + searchLimit + "&offset=" + offset + "&access=playable",
      );

      var items = data.collection || [];

      for (var i = 0; i < items.length; i++) {
        var item = items[i];

        if (searchType === "tracks") {
          var track = formatTrack(item);
          if (track) results.push(track);
        } else if (searchType === "albums") {
          var album = formatPlaylistOrAlbum(item);
          if (album) {
            album.item_type = "album";
            results.push(album);
          }
        } else if (searchType === "users") {
          var user = formatUser(item);
          if (user) {
            user.item_type = "artist";
            results.push(user);
          }
        } else if (searchType === "playlists") {
          var pl = formatPlaylistOrAlbum(item);
          if (pl) {
            pl.item_type = "playlist";
            results.push(pl);
          }
        }
      }
    } catch (e) {
      log.debug("[SC] Search for " + searchType + " failed:", e.message);
    }
  }

  log.info(
    "[SC] Found",
    results.length,
    "results (filter:",
    filter || "all",
    ")",
  );
  return results;
}

// ============================================
// URL HANDLING
// ============================================

/**
 * Parse a SoundCloud URL into components.
 * Returns { type, permalink_url } or null.
 */
function parseSoundCloudURL(url) {
  url = (url || "").trim();
  if (!url) return null;

  // Normalize mobile/short URLs
  url = url.replace(/^https?:\/\/m\.soundcloud\.com/, "https://soundcloud.com");
  // on.soundcloud.com short links need resolution
  if (url.indexOf("on.soundcloud.com") !== -1) {
    return { type: "resolve", permalink_url: url };
  }

  // https://soundcloud.com/{author}/sets/{slug}
  var setsMatch = url.match(/soundcloud\.com\/([^/?#]+)\/sets\/([^/?#]+)/i);
  if (setsMatch) {
    return {
      type: "playlist",
      permalink_url:
        "https://soundcloud.com/" + setsMatch[1] + "/sets/" + setsMatch[2],
    };
  }

  // https://soundcloud.com/{author}/{track}
  var trackMatch = url.match(/soundcloud\.com\/([^/?#]+)\/([^/?#]+)/i);
  if (
    trackMatch &&
    trackMatch[2] !== "sets" &&
    trackMatch[2] !== "albums" &&
    trackMatch[2] !== "tracks" &&
    trackMatch[2] !== "likes" &&
    trackMatch[2] !== "followers" &&
    trackMatch[2] !== "following" &&
    trackMatch[2] !== "reposts" &&
    trackMatch[2] !== "playlists" &&
    trackMatch[2] !== "popular-tracks"
  ) {
    return {
      type: "track",
      permalink_url:
        "https://soundcloud.com/" + trackMatch[1] + "/" + trackMatch[2],
    };
  }

  // https://soundcloud.com/{author} (user profile)
  var userMatch = url.match(/soundcloud\.com\/([^/?#]+)\/?$/i);
  if (userMatch) {
    return {
      type: "user",
      permalink_url: "https://soundcloud.com/" + userMatch[1],
    };
  }

  // Unknown — try resolving
  return { type: "resolve", permalink_url: url };
}

function handleURL(url) {
  log.info("[SC] Handling URL:", url);

  var parsed = parseSoundCloudURL(url);
  if (!parsed) {
    return { success: false, error: "Invalid SoundCloud URL" };
  }

  // on.soundcloud.com short links are 302 redirects that the API can't resolve.
  // Follow the redirect to get the real soundcloud.com URL first.
  if (
    parsed.type === "resolve" &&
    parsed.permalink_url.indexOf("on.soundcloud.com") !== -1
  ) {
    log.info("[SC] Resolving short link:", parsed.permalink_url);
    try {
      var redirectResp = http.get(parsed.permalink_url, {
        "User-Agent": utils.randomUserAgent(),
        "Accept-Encoding": "identity",
      });
      var finalUrl = "";

      // Method 1: Use response.url (final URL after redirects, requires updated Go backend)
      if (
        redirectResp &&
        !redirectResp.error &&
        redirectResp.url &&
        redirectResp.url.indexOf("soundcloud.com") !== -1 &&
        redirectResp.url.indexOf("on.soundcloud.com") === -1
      ) {
        finalUrl = redirectResp.url;
        log.info("[SC] Got final URL from response.url");
      }

      // Method 2: Parse canonical URL from HTML body
      if (!finalUrl && redirectResp && redirectResp.body) {
        var canonMatch = redirectResp.body.match(
          /<link[^>]*rel=["']canonical["'][^>]*href=["']([^"']+)["']/i,
        );
        if (!canonMatch) {
          canonMatch = redirectResp.body.match(
            /<meta[^>]*property=["']og:url["'][^>]*content=["']([^"']+)["']/i,
          );
        }
        if (
          canonMatch &&
          canonMatch[1] &&
          canonMatch[1].indexOf("soundcloud.com") !== -1
        ) {
          finalUrl = canonMatch[1];
          log.info("[SC] Got final URL from HTML meta tag");
        }
      }

      if (finalUrl) {
        // Strip tracking params
        var qIdx = finalUrl.indexOf("?");
        if (qIdx !== -1) finalUrl = finalUrl.substring(0, qIdx);
        log.info("[SC] Resolved short link ->", finalUrl);
        parsed = parseSoundCloudURL(finalUrl);
        if (!parsed) {
          return {
            success: false,
            error: "Could not parse resolved URL: " + finalUrl,
          };
        }
      } else {
        log.warn("[SC] Could not extract final URL from short link response");
      }
    } catch (e) {
      log.warn("[SC] Short link redirect failed:", e.message);
      // Fall through — will try /resolve with original URL as last resort
    }
  }

  try {
    // Use the resolve endpoint — works for all URL types
    var resolved = scResolve(parsed.permalink_url);
    if (!resolved) {
      return { success: false, error: "Could not resolve URL" };
    }

    var kind = resolved.kind;

    if (kind === "track") {
      var track = formatTrack(resolved);
      return { success: true, type: "track", track: track };
    }

    if (kind === "playlist") {
      var playlistData = fetchPlaylistOrAlbum(resolved.id);
      var isAlbum =
        resolved.is_album ||
        resolved.set_type === "album" ||
        resolved.set_type === "ep" ||
        resolved.set_type === "single";

      if (isAlbum) {
        return {
          success: true,
          type: "album",
          album: {
            id: String(resolved.id),
            name: playlistData.info.name,
            artists: playlistData.info.artists,
            cover_url: playlistData.info.cover_url,
            release_date: playlistData.info.release_date,
            total_tracks: playlistData.tracks.length,
            tracks: playlistData.tracks,
          },
          tracks: playlistData.tracks,
          name: playlistData.info.name,
          cover_url: playlistData.info.cover_url,
        };
      }

      return {
        success: true,
        type: "playlist",
        tracks: playlistData.tracks,
        name: playlistData.info.name,
        cover_url: playlistData.info.cover_url,
      };
    }

    if (kind === "user") {
      var artistResult = fetchArtist(resolved.id);
      return {
        success: true,
        type: "artist",
        artist: artistResult.artist,
      };
    }

    return { success: false, error: "Unsupported resource type: " + kind };
  } catch (e) {
    log.error("[SC] URL handling failed:", e.message);
    return { success: false, error: e.message || "Failed to resolve URL" };
  }
}

// ============================================
// ENRICHMENT
// ============================================

function enrichTrack(track) {
  log.info("[SC] enrichTrack for:", track.name, "by", track.artists);

  var scId = (track.id || "").trim();

  // If the ID is numeric (SoundCloud track ID), fetch directly
  if (scId && /^\d+$/.test(scId)) {
    try {
      var data = scGet("tracks/" + scId);
      if (data) {
        var pub = data.publisher_metadata || {};
        if (pub.isrc || data.isrc) {
          track.isrc = pub.isrc || data.isrc;
          log.info("[SC] Enriched ISRC:", track.isrc);
        }
        if (data.genre && !track.genre) track.genre = data.genre;
        if (data.label_name && !track.label) track.label = data.label_name;
        if (pub.p_line_for_display && !track.copyright) {
          track.copyright = pub.p_line_for_display;
        }
        if (pub.writer_composer && !track.composer) {
          track.composer = pub.writer_composer;
        }
      }
    } catch (e) {
      log.debug("[SC] Direct enrichment failed:", e.message);
    }
  }

  // If no ISRC, try searching + matching
  if (!track.isrc) {
    var searchTerm = (track.name || "") + " " + (track.artists || "");
    searchTerm = searchTerm.trim();
    if (searchTerm) {
      try {
        var searchData = scGet(
          "search/tracks?q=" + encodeURIComponent(searchTerm),
          "limit=5&access=playable",
        );
        var songs = searchData.collection || [];
        var best = findBestMatch(
          songs,
          track.name,
          track.artists,
          track.duration_ms,
        );
        if (best) {
          var bPub = best.publisher_metadata || {};
          if (bPub.isrc || best.isrc) {
            track.isrc = bPub.isrc || best.isrc;
            log.info("[SC] Enriched ISRC via search:", track.isrc);
          }
          if (!track.genre && best.genre) track.genre = best.genre;
          if (!track.label && best.label_name) track.label = best.label_name;
        }
      } catch (e) {
        log.debug("[SC] Search enrichment failed:", e.message);
      }
    }
  }

  return track;
}

// ============================================
// DOWNLOAD PROVIDER
// ============================================

function checkAvailability(isrc, trackName, artistName, options) {
  log.info("[SC] checkAvailability:", trackName, "-", artistName);

  // If we have a SoundCloud track ID in options
  var scId = options && options.spotify_id;
  if (scId && /^\d{5,}$/.test(scId)) {
    // Verify it exists and is playable
    try {
      var track = scGet("tracks/" + scId);
      if (track && track.access === "playable" && track.streamable) {
        return {
          available: true,
          track_id: String(track.id),
          skip_fallback: true,
          reason: "direct SoundCloud track ID",
        };
      }
      return {
        available: false,
        skip_fallback: true,
        reason: "direct SoundCloud track is not playable",
      };
    } catch (e) {
      log.debug("[SC] Direct availability check failed:", e.message);
      return {
        available: false,
        skip_fallback: true,
        reason: "direct SoundCloud lookup failed: " + e.message,
      };
    }
  }

  // Search by name + artist
  var query = (trackName || "") + " " + (artistName || "");
  query = query.trim();
  if (!query) {
    return { available: false, reason: "No search query" };
  }

  try {
    var targetDurationMs = 0;
    if (options && options.duration_ms) {
      targetDurationMs = Number(options.duration_ms) || 0;
    }
    var data = scGet(
      "search/tracks?q=" + encodeURIComponent(query),
      "limit=5&access=playable",
    );
    var tracks = data.collection || [];

    var best = findBestMatch(
      tracks,
      trackName,
      artistName,
      targetDurationMs,
      65,
    );
    if (best && best.access === "playable" && best.streamable !== false) {
      return { available: true, track_id: String(best.id) };
    }

    return {
      available: false,
      reason: "No confident playable match found on SoundCloud",
    };
  } catch (e) {
    return { available: false, reason: "Search failed: " + e.message };
  }
}

/**
 * Resolve the direct progressive stream URL for a SoundCloud track.
 * Shared by download() (saves to disk) and getDownloadUrl() (live streaming).
 * Returns { url, format, error } with url empty on failure.
 */
function resolveStreamURL(trackID, audioFormat, allowHls, allowPreview) {
  var trackData;
  try {
    trackData = scGet("tracks/" + trackID);
  } catch (e) {
    return {
      url: "",
      format: audioFormat,
      error: "Could not fetch track data: " + e.message,
    };
  }
  if (!trackData) {
    return {
      url: "",
      format: audioFormat,
      error: "Track not found: " + trackID,
    };
  }

  var transcodings = (trackData.media && trackData.media.transcodings) || [];
  var trackAuth = trackData.track_authorization || "";

  if (transcodings.length === 0 || !trackAuth) {
    return {
      url: "",
      format: audioFormat,
      error: "No transcodings or track_authorization available",
    };
  }

  // Pick the best transcoding matching requested format
  var bestTranscoding = pickTranscoding(
    transcodings,
    audioFormat,
    allowHls,
    allowPreview,
  );
  if (!bestTranscoding) {
    log.warn(
      "[SC] no transcoding for " +
        audioFormat +
        " (allowHls=" +
        allowHls +
        "); tracks with protocol/mime: " +
        JSON.stringify(
          transcodings
            .filter(function (t) {
              return t && t.format;
            })
            .map(function (t) {
              return {
                p: (t.format && t.format.protocol) || "?",
                m: (t.format && t.format.mime_type) || "?",
                q: t.quality,
                sn: !!t.snipped,
              };
            }),
        ),
    );
    return {
      url: "",
      format: audioFormat,
      error: "No suitable transcoding found for format: " + audioFormat,
    };
  }

  try {
    var streamInfoUrl = bestTranscoding.url;
    var sep = streamInfoUrl.indexOf("?") === -1 ? "?" : "&";
    streamInfoUrl +=
      sep + "client_id=" + state.clientId + "&track_authorization=" + trackAuth;

    var streamResp = http.get(streamInfoUrl, {
      "User-Agent": utils.randomUserAgent(),
      Accept: "application/json",
    });

    if (!streamResp || streamResp.error || streamResp.statusCode !== 200) {
      return {
        url: "",
        format: audioFormat,
        error:
          "Stream URL fetch returned HTTP " +
          (streamResp ? streamResp.statusCode : "null"),
      };
    }

    var streamData = JSON.parse(streamResp.body);
    if (!streamData.url) {
      return {
        url: "",
        format: audioFormat,
        error: "Stream response missing url",
      };
    }

    var actualFormat = audioFormat;
    var mime =
      (bestTranscoding.format && bestTranscoding.format.mime_type) || "";
    if (mime.indexOf("opus") !== -1) {
      actualFormat = "opus";
    } else if (mime.indexOf("mpeg") !== -1 || mime.indexOf("mp3") !== -1) {
      actualFormat = "mp3";
    } else if (mime.indexOf("ogg") !== -1) {
      actualFormat = "ogg";
    }
    log.info(
      "[SC] Got direct stream URL (format: " +
        actualFormat +
        ", protocol: " +
        ((bestTranscoding.format && bestTranscoding.format.protocol) || "?") +
        ")",
    );
    return { url: streamData.url, format: actualFormat, error: "" };
  } catch (e) {
    return {
      url: "",
      format: audioFormat,
      error: "Stream URL fetch failed: " + e.message,
    };
  }
}

function download(trackID, quality, outputPath, onProgress) {
  log.info("[SC] Downloading track:", trackID, "quality:", quality);

  var qualityParts = quality.split("_");
  var audioFormat = qualityParts[0] || "mp3";

  // ---- Primary: Direct SoundCloud stream ----
  if (onProgress) onProgress(0.1);

  var resolved = resolveStreamURL(trackID, audioFormat);
  var downloadURL = resolved.url;
  var downloadError = resolved.error;
  var actualFormat = resolved.format || audioFormat;

  if (!downloadURL) {
    return {
      success: false,
      error_message:
        "No direct SoundCloud progressive stream found for track: " +
        trackID +
        (downloadError ? " (" + downloadError + ")" : ""),
      error_type: "api_error",
    };
  }

  if (onProgress) onProgress(0.3);

  // Fix output path extension to match actual format
  var actualExt = "." + actualFormat;
  if (actualFormat === "mpeg") actualExt = ".mp3";
  var actualOutputPath = outputPath;
  var dotIdx = outputPath.lastIndexOf(".");
  if (dotIdx >= 0) {
    var currentExt = outputPath.substring(dotIdx).toLowerCase();
    if (currentExt !== actualExt) {
      actualOutputPath = outputPath.substring(0, dotIdx) + actualExt;
      log.info("[SC] Corrected output extension:", currentExt, "->", actualExt);
    }
  }

  log.info("[SC] Downloading file to:", actualOutputPath);
  var downloadResult = file.download(downloadURL, actualOutputPath, {
    headers: { "User-Agent": userAgentForURL(downloadURL) },
  });

  if (!downloadResult || !downloadResult.success) {
    var errMsg = downloadResult
      ? downloadResult.error
      : "file.download returned null";
    return {
      success: false,
      error_message: "Failed to download file: " + errMsg,
      error_type: "download_error",
    };
  }

  if (onProgress) onProgress(1.0);

  log.info("[SC] Download complete for track:", trackID);
  return {
    success: true,
    file_path: downloadResult.path || actualOutputPath,
    bit_depth: 0,
    sample_rate: 0,
  };
}

/**
 * Pick the best transcoding from the list, preferring the requested format
 * and progressive protocol. When [allowHls] is true and no progressive
 * transcoding exists, falls back to an HLS (m3u8) transcoding instead — the
 * player (media_kit) can stream an m3u8 playlist, even though it is not
 * suitable for file.download as a direct audio file.
 */
function pickTranscoding(transcodings, preferFormat, allowHls, allowPreview) {
  if (!transcodings || transcodings.length === 0) return null;

  // Score each transcoding
  var best = null;
  var bestScore = -1;
  var hlsBest = null;
  var hlsBestScore = -1;
  var previewBest = null;
  var previewBestScore = -1;

  for (var i = 0; i < transcodings.length; i++) {
    var t = transcodings[i];
    if (!t.url || !t.format) continue;
    // Snipped (preview) transcodings are only used as a last resort when
    // [allowPreview] is set AND no full-length transcoding exists.
    if (t.snipped) {
      if (!allowPreview) continue;
      var pScore = 10 + (t.quality === "hq" ? 5 : t.quality === "sq" ? 2 : 0);
      if (pScore > previewBestScore) {
        previewBestScore = pScore;
        previewBest = t;
      }
      continue;
    }

    var score = 0;
    var mime = t.format.mime_type || "";
    var protocol = t.format.protocol || "";

    // Match requested format (shared scoring between progressive and HLS)
    var formatScore = 0;
    if (preferFormat === "opus" && mime.indexOf("opus") !== -1) {
      formatScore = 30;
    } else if (
      preferFormat === "mp3" &&
      (mime.indexOf("mpeg") !== -1 || mime.indexOf("mp3") !== -1)
    ) {
      formatScore = 30;
    } else if (preferFormat === "ogg" && mime.indexOf("ogg") !== -1) {
      formatScore = 20;
    }

    // Higher quality tiers
    var tierScore = t.quality === "hq" ? 10 : t.quality === "sq" ? 5 : 0;

    if (protocol === "progressive") {
      score = 50 + formatScore + tierScore;
      if (score > bestScore) {
        bestScore = score;
        best = t;
      }
    } else if (allowHls && protocol.indexOf("hls") !== -1) {
      // Keep the best HLS candidate as a fallback (no progressive found).
      var hScore = 40 + formatScore + tierScore;
      if (hScore > hlsBestScore) {
        hlsBestScore = hScore;
        hlsBest = t;
      }
    }
  }

  if (best) return best;
  if (allowHls && hlsBest) return hlsBest;
  return previewBest;
}

// ============================================
// MATCHING
// ============================================

function findBestMatch(
  tracks,
  targetName,
  targetArtist,
  targetDurationMs,
  minScore,
) {
  if (!tracks || tracks.length === 0) return null;

  var bestScore = -1;
  var bestTrack = null;

  for (var i = 0; i < tracks.length; i++) {
    var t = tracks[i];
    var tTitle = t.title || "";
    var tArtist =
      (t.publisher_metadata && t.publisher_metadata.artist) ||
      t.metadata_artist ||
      (t.user && t.user.username) ||
      "";
    var score = 0;

    score += matching.compareStrings(targetName || "", tTitle) * 50;
    score += matching.compareStrings(targetArtist || "", tArtist) * 30;

    if (targetDurationMs > 0 && t.duration) {
      score += matching.compareDuration(targetDurationMs, t.duration) * 20;
    }

    // Prefer tracks with a full-length transcoding. Re-uploads/remixes often
    // only expose a 30s snipped preview — picking one burns the whole fallback
    // on "no transcoding" for every format. A full transcoding gets a strong
    // bonus; a preview-only track is heavily penalized (but not excluded, in
    // case every candidate is a preview and duration/title still need to win).
    var hasFull = false;
    var media = t.media || {};
    var trs = media.transcodings || [];
    for (var j = 0; j < trs.length; j++) {
      if (trs[j] && !trs[j].snipped) {
        hasFull = true;
        break;
      }
    }
    if (hasFull) {
      score += 25;
    } else if (trs.length > 0) {
      score -= 40;
    }

    if (score > bestScore) {
      bestScore = score;
      bestTrack = t;
    }
  }

  var threshold = typeof minScore === "number" ? minScore : 40;
  if (bestScore < threshold) return null;
  return bestTrack;
}

function normalizeText(text) {
  if (!text) return "";
  return text
    .toLowerCase()
    .replace(
      /[^a-z0-9\u00c0-\u024f\u0400-\u04ff\u3040-\u30ff\u3400-\u9fff\uac00-\ud7af]+/g,
      " ",
    )
    .replace(/\s+/g, " ")
    .trim();
}

// ============================================
// STREAMING
// ============================================

/**
 * Returns a direct progressive stream URL for live playback, or null if the
 * track cannot be streamed. Used by GetStreamPackage -> GetStreamURL.
 */
function getDownloadUrl(trackID, quality) {
  try {
    var qualityParts = String(quality || "mp3").split("_");
    var audioFormat = qualityParts[0] || "mp3";
    var resolved = resolveStreamURL(
      String(trackID || "").trim(),
      audioFormat,
      true,
      false,
    );
    if (resolved && resolved.url) {
      log.info("[SC] getDownloadUrl resolved stream for", trackID);
      return resolved.url;
    }
    log.warn(
      "[SC] getDownloadUrl failed:",
      resolved && resolved.error ? resolved.error : "no stream",
    );
  } catch (e) {
    log.warn(
      "[SC] getDownloadUrl exception:",
      e && e.message ? e.message : String(e),
    );
  }
  return null;
}

// ============================================
// EXPORTED API
// ============================================

function getTrack(trackId) {
  try {
    return fetchTrack(trackId);
  } catch (e) {
    log.error("[SC] getTrack failed:", e.message);
    return null;
  }
}

function getAlbum(albumId) {
  try {
    var result = fetchPlaylistOrAlbum(albumId);
    var tracks = result.tracks.map(function (t) {
      t.provider_id = "soundcloud";
      return t;
    });
    return {
      id: albumId,
      name: result.info.name,
      artists: result.info.artists,
      artist_id: result.info.artist_id,
      release_date: result.info.release_date,
      total_tracks: tracks.length,
      images: result.info.images,
      cover_url: result.info.cover_url,
      tracks: tracks,
      provider_id: "soundcloud",
    };
  } catch (e) {
    log.error("[SC] getAlbum failed:", e.message);
    return null;
  }
}

function getPlaylist(playlistId) {
  try {
    var result = fetchPlaylistOrAlbum(playlistId);
    var tracks = result.tracks.map(function (t) {
      t.provider_id = "soundcloud";
      return t;
    });
    return {
      id: playlistId,
      name: result.info.name,
      description: "",
      owner: result.info.artists,
      cover: result.info.cover_url,
      cover_url: result.info.cover_url,
      total_tracks: tracks.length,
      tracks: tracks,
      provider_id: "soundcloud",
    };
  } catch (e) {
    log.error("[SC] getPlaylist failed:", e.message);
    return null;
  }
}

function getArtist(artistId) {
  try {
    var result = fetchArtist(artistId);
    return result.artist;
  } catch (e) {
    log.error("[SC] getArtist failed:", e.message);
    return null;
  }
}

function searchTracks(query, limit) {
  return customSearch(query, { limit: limit || 20, filter: "tracks" });
}

// ============================================
// HOME FEED — SoundCloud Trending + Featured
// ============================================

// Unified cover URL: prefer t500x500 for a good balance of quality/size.
function feedCover(url) {
  if (!url) return "";
  return url
    .replace("-large.", "-t500x500.")
    .replace("-original.", "-t500x500.");
}

function extractChartsItems(data, maxItems) {
  if (!data) return [];
  var items = [];
  var collection = data.collection || [];
  if (!collection.length) return [];
  for (var i = 0; i < Math.min(collection.length, maxItems || 15); i++) {
    var entry = collection[i];
    if (!entry) continue;
    // Charts entries can be tracks or playlists
    var item = entry.track || entry.playlist || entry;
    if (!item || !item.id) continue;
    var isTrack = !!(
      item.genre ||
      item.duration ||
      item.full_duration ||
      entry.track
    );
    if (isTrack) {
      var track = formatTrack(item);
      if (track) {
        track.cover_url = feedCover(track.cover_url);
        items.push(track);
      }
    } else {
      var pl = formatPlaylistOrAlbum(item);
      if (pl) items.push(pl);
    }
  }
  return items;
}

// featured_tracks collections are abbreviated tracks (no user/artist field).
// Enrich via a tracks?ids= batch request to recover artist + publisher_metadata.
function extractFeaturedItems(collection, maxItems) {
  if (!collection || !collection.length) return [];
  var limit = maxItems || 10;
  var ids = [];
  for (var i = 0; i < Math.min(collection.length, limit); i++) {
    var it = collection[i];
    if (it && it.id) ids.push(String(it.id));
  }
  if (!ids.length) return [];

  var trackMap = {};
  try {
    var batchData = scGet("tracks?ids=" + ids.join(","));
    if (batchData && batchData.length) {
      for (var j = 0; j < batchData.length; j++) {
        trackMap[batchData[j].id] = batchData[j];
      }
    }
  } catch (e) {
    log.debug("[SC] Featured batch fetch failed:", e.message);
  }

  var items = [];
  for (var k = 0; k < collection.length && items.length < limit; k++) {
    var orig = collection[k];
    if (!orig || !orig.id) continue;
    var full = trackMap[orig.id] || orig;
    var track = formatTrack(full);
    if (track) {
      track.cover_url = feedCover(track.cover_url);
      items.push(track);
    }
  }
  return items;
}

function fetchHomeFeed() {
  log.info("[SC] Fetching SoundCloud home feed...");
  var sections = [];
  try {
    ensureClientId();
  } catch (e) {}

  // Section 1: Trending charts — top 15 (all-music genre).
  try {
    var topData = scGet(
      "charts?kind=trending&genre=soundcloud:genres:all-music",
      "limit=15&offset=0",
    );
    var topItems = extractChartsItems(topData, 15);
    if (topItems.length > 0) {
      sections.push({
        uri: "sc:charts:trending",
        title: "Tendencias de SoundCloud",
        items: topItems,
      });
    }
  } catch (e1) {
    log.debug("[SC] charts trending failed:", e1.message);
  }

  // Section 2: Curated featured tracks (the API returns only 5 unique ones).
  if (sections.length < 2) {
    try {
      var fData = scGet("featured_tracks/top/all-music", "limit=10");
      var fItems = extractFeaturedItems(fData.collection || fData, 10);
      if (fItems.length > 0) {
        sections.push({
          uri: "sc:featured:all-music",
          title: "Destacados de SoundCloud",
          items: fItems,
        });
      }
    } catch (e2) {
      log.debug("[SC] featured failed:", e2.message);
    }
  }

  // Section 3: Next trending page (rising tracks) — pagination returns
  // 15 new unique tracks per offset, so this adds real variety.
  if (sections.length < 3) {
    try {
      var risingData = scGet(
        "charts?kind=trending&genre=soundcloud:genres:all-music",
        "limit=15&offset=15",
      );
      var risingItems = extractChartsItems(risingData, 15);
      if (risingItems.length > 0) {
        sections.push({
          uri: "sc:charts:rising",
          title: "En ascenso",
          items: risingItems,
        });
      }
    } catch (e3) {
      log.debug("[SC] charts rising failed:", e3.message);
    }
  }

  if (sections.length > 0) {
    log.info("[SC] Fetched", sections.length, "real sections");
    return { success: true, sections: sections };
  }
  log.info("[SC] No real home feed available");
  return { success: false, error: "No home feed available", sections: [] };
}

function getHomeFeed() {
  try {
    return fetchHomeFeed();
  } catch (e) {
    return { success: false, error: e.message, sections: [] };
  }
}

// ============================================
// REGISTER EXTENSION
// ============================================

registerExtension({
  initialize: initialize,
  cleanup: cleanup,
  customSearch: customSearch,
  handleUrl: handleURL,
  getTrack: getTrack,
  getAlbum: getAlbum,
  getArtist: getArtist,
  getPlaylist: getPlaylist,
  searchTracks: searchTracks,
  enrichTrack: enrichTrack,
  getHomeFeed: getHomeFeed,

  // Download provider
  checkAvailability: checkAvailability,
  download: download,
  getDownloadUrl: getDownloadUrl,
});

log.info("[SC] SoundCloud Extension loaded!");
