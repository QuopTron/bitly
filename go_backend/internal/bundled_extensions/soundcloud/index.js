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
  // clientIdBusy dedupes concurrent fetches: a queue prefetch fires several
  // ISRC searches in parallel, and without a guard each would re-run the whole
  // HTML+bundle scan (2-3s each) against the same state. Only the first call
  // fetches; the rest see the in-flight marker and reuse its result. On
  // failure the marker is cleared after a short backoff so the next search
  // retries, but a burst of parallel failures doesn't hammer soundcloud.com.
  clientIdBusy: false,
  clientIdNextRetry: 0,
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
  persistirClientId();
}

function userAgentForURL(url) {
  return utils.randomUserAgent();
}

// ============================================
// CLIENT ID EXTRACTION
// ============================================

// ── CÓMO SE OBTIENE EL client_id ─────────────────────────────
//
// Por qué hay VARIAS estrategias y todas se VALIDAN: SoundCloud fue moviendo
// dónde publica su client_id, y cada formato nuevo dejaba la fuente muerta de a
// ratos —no solo el feed: la búsqueda y la descarga también salen por esa API.
// Medido: dos corridas seguidas en la misma máquina, una con client_id y la otra
// agotando ~30 bundles para no encontrar nada y responder 401.
//
// Lo que cambió el juego: la página YA trae el id en su bloque de arranque
// (`window.__sc_hydration`, entrada `apiClient`), así que en el caso normal
// alcanza con UNA petición que no es un bundle. El recorrido de bundles queda
// como último recurso, porque es el lento (~2-3s) y el que más se rompe.
//
// Y cada candidato se COMPRUEBA contra la API antes de guardarlo. Un id con
// formato válido pero muerto era indistinguible de uno bueno hasta que la
// búsqueda ya había fallado; así el rescate de client_id no queda envenenado 24h.

// PATRONES_CLIENT_ID son las formas conocidas del id en un texto (HTML o JS).
// El orden importa: primero las que incluyen la clave del dato, después las
// sueltas.
var PATRONES_CLIENT_ID = [
  /"client_id"\s*:\s*"([a-zA-Z0-9]{32})"/,
  /client_id["']?\s*[:=]\s*["']([a-zA-Z0-9]{32})["']/,
  /client_id=([a-zA-Z0-9]{32})/,
  /"clientId"\s*:\s*"([a-zA-Z0-9]{32})"/,
];

// PAGINAS_CLIENT_ID son las páginas donde SoundCloud publica el bloque de
// arranque, en orden de preferencia. La principal alcanza en el uso normal; las
// otras dos cubren la variante de frontend y la redirección regional, que son
// justo los casos "de a ratos".
var PAGINAS_CLIENT_ID = [
  "https://soundcloud.com/",
  "https://soundcloud.com/discover",
  "https://m.soundcloud.com/",
];

// bajarTextoRecurso hace un GET de navegador y devuelve el cuerpo ("" si no se
// pudo). Nunca lanza: quien llama decide si prueba otra página.
function bajarTextoRecurso(url, accept) {
  try {
    var resp = http.get(url, {
      "User-Agent": utils.randomUserAgent(),
      "Accept-Encoding": "identity",
      Accept: accept || "text/html,application/xhtml+xml,*/*",
    });
    if (!resp || resp.error || resp.statusCode !== 200) return "";
    return resp.body || "";
  } catch (e) {
    log.debug("[SC] GET falló para " + url + ": " + e.message);
    return "";
  }
}

// clientIdDesdeHydration lee el id del bloque con el que la SPA arranca:
// window.__sc_hydration = [..., {"hydratable":"apiClient",
// "data":{"id":"<32 chars>","isExpiring":false}}, ...].
//
// Se busca por posicional: el JSON llega minificado y el orden de las claves no
// es estable entre builds, así que se ubica "apiClient" y se mira una ventana
// alrededor por si el id está antes o después.
function clientIdDesdeHydration(cuerpo) {
  var idx = cuerpo.indexOf("apiClient");
  if (idx === -1) return "";

  var desde = Math.max(0, idx - 300);
  var hasta = Math.min(cuerpo.length, idx + 300);
  var ventana = cuerpo.substring(desde, hasta);

  var m = ventana.match(
    /["']data["']\s*:\s*\{[^{}]{0,200}?["']id["']\s*:\s*["']([a-zA-Z0-9]{32})["']/,
  );
  if (m) return m[1];
  m = ventana.match(/["']id["']\s*:\s*["']([a-zA-Z0-9]{32})["']/);
  return m ? m[1] : "";
}

// clientIdDeTexto aplica los patrones conocidos a un texto cualquiera.
function clientIdDeTexto(texto) {
  if (!texto) return "";
  for (var i = 0; i < PATRONES_CLIENT_ID.length; i++) {
    var m = texto.match(PATRONES_CLIENT_ID[i]);
    if (m) return m[1];
  }
  return "";
}

// verificarClientId comprueba el candidato con la llamada autenticada más
// barata que existe (una búsqueda de un resultado).
//
// Devuelve "ok" | "rechazado" | "sin-verificar". Solo un rechazo EXPLÍCITO de
// autorización invalida el candidato: un 429, un 5xx o un fallo de red no
// dicen nada del id, y descartarlo por eso dejaría la fuente muerta cuando el
// problema era nuestro.
function verificarClientId(id) {
  if (!id) return "rechazado";
  try {
    var resp = http.get(
      SC_API + "/search/tracks?q=a&limit=1&client_id=" + encodeURIComponent(id),
      {
        "User-Agent": utils.randomUserAgent(),
        Accept: "application/json",
      },
    );
    if (resp && resp.statusCode === 200) return "ok";
    if (resp && (resp.statusCode === 401 || resp.statusCode === 403)) {
      log.debug("[SC] client_id candidato rechazado: HTTP " + resp.statusCode);
      return "rechazado";
    }
    log.debug(
      "[SC] client_id sin poder verificar: HTTP " +
        (resp ? resp.statusCode : "sin respuesta"),
    );
    return "sin-verificar";
  } catch (e) {
    return "sin-verificar";
  }
}

// invalidarClientId borra el id cacheado y lo saca del storage. Se usa cuando el
// id recién rescatado tampoco sirvió: sin esto quedaría 24h guardado y cada
// arranque de la app lo volvería a usar para volver a fallar.
function invalidarClientId() {
  state.clientId = null;
  state.clientIdExpiry = 0;
  state.clientIdNextRetry = Date.now() + 30 * 1000;
  try {
    if (
      typeof storage !== "undefined" &&
      storage &&
      typeof storage.remove === "function"
    ) {
      storage.remove("sc_state");
    }
  } catch (e) {}
}

// guardarClientId deja el id listo para usar y lo persiste.
function guardarClientId(id, origen) {
  state.clientId = id;
  state.clientIdExpiry = Date.now() + 24 * 60 * 60 * 1000; // 24h
  state.clientIdNextRetry = 0;
  persistirClientId();
  log.info("[SC] client_id obtenido de " + origen);
}

// persistirClientId guarda el estado en el storage de la extensión para que un
// reinicio de la app no pague otra vez el rescate.
function persistirClientId() {
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

// esElMismoIdMuerto dice si el candidato es el id con el que la API acaba de
// responder 401. Ese id está muerto por definición: adoptarlo sería cachear 24h
// un id que ya falló, y comprobarlo sería gastar una petición para que la API
// repita lo que ya dijo.
function esElMismoIdMuerto(candidato, idAnterior) {
  return !!idAnterior && candidato === idAnterior;
}

// candidatoClientId prueba las estrategias sobre UNA página ya descargada y
// devuelve {id, origen} o null.
//
// opciones:
//   idAnterior    el id con el que la API acaba de dar 401 (ver
//                 esElMismoIdMuerto).
//   sinVerificar  salta la comprobación previa contra la API. Se usa SOLO en el
//                 camino del 401, donde el reintento con el id nuevo ES la
//                 verificación: comprobar antes duplicaba las peticiones para
//                 obtener la misma información.
function candidatoClientId(cuerpo, opciones) {
  var op = opciones || {};
  var propuestas = [
    { id: clientIdDesdeHydration(cuerpo), origen: "__sc_hydration" },
    { id: clientIdDeTexto(cuerpo), origen: "HTML" },
  ];
  for (var i = 0; i < propuestas.length; i++) {
    if (!propuestas[i].id) continue;
    if (esElMismoIdMuerto(propuestas[i].id, op.idAnterior)) continue;
    if (
      !op.sinVerificar &&
      verificarClientId(propuestas[i].id) === "rechazado"
    ) {
      continue;
    }
    return propuestas[i];
  }
  return null;
}

// clientIdDeBundles es el último recurso: recorrer los scripts de la página.
// Antes era el PRIMER camino y por eso la fuente fallaba cuando SoundCloud
// renombraba sus chunks; ahora se usa solo si el bloque de arranque no dio un id
// usable. Se escanea completo (no solo los últimos): el id ha viajado en chunks
// distintos entre builds.
function clientIdDeBundles(cuerpo, opciones) {
  var op = opciones || {};
  var scriptMatches = cuerpo.match(
    /src="(https:\/\/a-v2\.sndcdn\.com\/assets\/[^"]+\.js)"/g,
  );
  if (!scriptMatches) {
    scriptMatches = cuerpo.match(
      /src="(https?:\/\/[^"]*sndcdn\.com[^"]*\.js)"/g,
    );
  }
  if (!scriptMatches) return "";

  for (var i = scriptMatches.length - 1; i >= 0; i--) {
    var srcMatch = scriptMatches[i].match(/src="([^"]+)"/);
    if (!srcMatch) continue;

    var bundleURL = srcMatch[1];
    log.debug(
      "[SC] Checking bundle:",
      bundleURL.substring(bundleURL.lastIndexOf("/") + 1),
    );

    var bundleBody = bajarTextoRecurso(bundleURL, "application/javascript,*/*");
    if (!bundleBody) continue;

    var candidato = clientIdDeTexto(bundleBody);
    if (!candidato) continue;
    if (esElMismoIdMuerto(candidato, op.idAnterior)) continue;
    if (!op.sinVerificar && verificarClientId(candidato) === "rechazado") {
      continue;
    }
    return candidato;
  }
  return "";
}

function fetchClientId(opciones) {
  var op = opciones || {};
  log.info("[SC] Fetching SoundCloud client_id...");

  var ultimoMotivo = "";
  for (var p = 0; p < PAGINAS_CLIENT_ID.length; p++) {
    var pagina = PAGINAS_CLIENT_ID[p];
    var cuerpo = bajarTextoRecurso(pagina);
    if (!cuerpo) {
      ultimoMotivo = "sin respuesta de " + pagina;
      continue;
    }

    // __sc_version dice si la página cambió. Si es la misma y ya tenemos id,
    // no se vuelve a rescatar: es el mismo dato de la vez pasada.
    var versionMatch = cuerpo.match(/__sc_version="(\d{10})"/);
    if (versionMatch) {
      if (versionMatch[1] === state.scVersion && state.clientId) {
        log.info("[SC] SoundCloud version unchanged, reusing cached client_id");
        return;
      }
      state.scVersion = versionMatch[1];
    }

    var candidato = candidatoClientId(cuerpo, op);
    if (candidato) {
      guardarClientId(candidato.id, candidato.origen);
      return;
    }

    var deBundle = clientIdDeBundles(cuerpo, op);
    if (deBundle) {
      guardarClientId(deBundle, "bundle JS");
      return;
    }

    ultimoMotivo = "la página " + pagina + " no publicó un client_id usable";
  }

  throw new Error(
    "Could not find SoundCloud client_id in page or JS bundles (" +
      ultimoMotivo +
      ")",
  );
}

function ensureClientId(opciones) {
  if (state.clientId && Date.now() < state.clientIdExpiry) {
    return;
  }
  // Parallel callers: only the first one actually fetches; the rest wait for
  // it (the scan is fast when it succeeds — ~1s — and a shared result beats
  // N duplicated scans). A recent failure backs off briefly so a prefetch
  // storm doesn't re-run the scan 8 times against the same broken page.
  if (state.clientIdBusy) {
    return;
  }
  if (Date.now() < state.clientIdNextRetry) {
    return;
  }
  state.clientIdBusy = true;
  try {
    fetchClientId(opciones);
  } finally {
    state.clientIdBusy = false;
    if (!state.clientId) {
      state.clientIdNextRetry = Date.now() + 30 * 1000;
    }
  }
}

// esFalloDeAutenticacion distingue un problema de AUTORIZACIÓN (401, o un
// client_id que no se puede renovar) de un "esta búsqueda no encontró nada".
//
// Por qué existe: customSearch se traga los errores y devuelve una lista
// vacía, así que Go nunca veía el 401 y no podía enfriar la fuente — cada
// canción del lote volvía a caminar SoundCloud con la misma caminata de
// peticiones condenadas. Un 401 no es "sin resultados": es la fuente entera
// sin poder servir, y tiene que llegar arriba para que el cooldown de Go la
// salte por un rato.
function esFalloDeAutenticacion(msg) {
  if (!msg) return false;
  var m = String(msg).toLowerCase();
  return (
    m.indexOf("http 401") !== -1 ||
    m.indexOf("unauthorized") !== -1 ||
    m.indexOf("client_id") !== -1
  );
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
    // OJO: el id anterior se guarda antes de anularlo. Antes se anulaba y se
    // llamaba a ensureClientId(), que puede volver sin hacer nada (backoff de
    // 30s o un refresh ya en vuelo) — la URL quedaba con "client_id=null" y la
    // petición se gastaba igual para recibir otro 401. Peor: si el re-escaneo
    // devolvía el MISMO id (SoundCloud sirve el mismo a todas sus variantes de
    // frontend), el reintento era un 401 garantizado. Ahora se reintenta SOLO
    // si hay un id nuevo; si no, se falla rápido y el cooldown de Go se encarga
    // de no volver a molestar a la fuente por cada canción del lote.
    var idAnterior = state.clientId;
    state.clientId = null;
    state.clientIdExpiry = 0;
    try {
      // sinVerificar: en este camino el reintento de abajo ES la verificación.
      // idAnterior: si el rescate devuelve el mismo id muerto, se descarta sin
      // gastar una petición en confirmarlo.
      ensureClientId({ idAnterior: idAnterior, sinVerificar: true });
    } catch (e) {
      // El rescate no encontró un id usable. Para el host esto NO es "sin
      // resultados", es la fuente sin poder servir: el marcador "HTTP 401" es
      // el que hace que Go la enfríe en vez de repetir la caminata por cada
      // canción del lote.
      throw new Error(
        "SoundCloud API failed after retry: HTTP 401 (client_id no renovable)",
      );
    }
    if (!state.clientId || state.clientId === idAnterior) {
      throw new Error(
        "SoundCloud API failed after retry: HTTP 401 (client_id no renovable)",
      );
    }
    // Retry once with the fresh id.
    sep = path.indexOf("?") === -1 ? "?" : "&";
    url = SC_API + "/" + path + sep + "client_id=" + state.clientId;
    if (extraParams) url += "&" + extraParams;
    response = http.get(url, {
      "User-Agent": utils.randomUserAgent(),
      Accept: "application/json",
    });
    if (!response || response.statusCode !== 200) {
      // El id nuevo tampoco sirvió: no se deja cacheado uno que ya falló.
      invalidarClientId();
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
    external_urls: playlist.permalink_url || "",
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
    external_urls: user.permalink_url || "",
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

// normalizarFiltro acepta singular y plural para que la app no devuelva vacío
// en las pestañas de canción/álbum/artista/playlist.
function normalizarFiltroSC(f) {
  f = String(f || "")
    .trim()
    .toLowerCase();
  if (!f || f === "all") return "";
  if (f === "song" || f === "track" || f === "tracks") return "tracks";
  if (f === "album" || f === "albums") return "albums";
  if (f === "artist" || f === "artists") return "artists";
  if (f === "playlist" || f === "playlists") return "playlists";
  return f;
}

function customSearch(query, options) {
  log.info("[SC] Searching:", query);

  var limit = (options && options.limit) || 20;
  var offset = (options && options.offset) || 0;
  var filter = normalizarFiltroSC((options && options.filter) || null) || null;
  if (limit <= 0 || limit > 50) limit = 50;

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
      // Un fallo de autorización se propaga: la fuente no puede servir y Go
      // tiene que enterarse para enfriarla (si no, se repite la caminata
      // completa por cada canción del lote). Los demás errores se siguen
      // tragando: son "esta búsqueda no encontró nada", que es normal.
      if (esFalloDeAutenticacion(e && e.message)) {
        throw e;
      }
      log.debug("[SC] Search for " + searchType + " failed:", e.message);
      continue;
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

function download(trackID, quality, outputPath, onProgress) {
  log.info("[SC] Downloading track:", trackID, "quality:", quality);

  var trackData = null;
  try {
    trackData = scGet("tracks/" + trackID);
  } catch (e) {
    return {
      success: false,
      error_message: "Could not fetch track data: " + e.message,
      error_type: "api_error",
    };
  }

  if (!trackData) {
    return {
      success: false,
      error_message: "Track not found: " + trackID,
      error_type: "api_error",
    };
  }

  var qualityParts = quality.split("_");
  var audioFormat = qualityParts[0] || "mp3";

  var downloadURL = null;
  var downloadError = "";
  var actualFormat = audioFormat;

  // ---- Primary: Direct SoundCloud stream ----
  if (onProgress) onProgress(0.1);

  var transcodings = (trackData.media && trackData.media.transcodings) || [];
  var trackAuth = trackData.track_authorization || "";

  if (transcodings.length > 0 && trackAuth) {
    // Pick the best transcoding matching requested format
    var bestTranscoding = pickTranscoding(transcodings, audioFormat);

    if (bestTranscoding) {
      try {
        // Fetch the actual stream URL from the transcoding endpoint
        var streamInfoUrl = bestTranscoding.url;
        var sep = streamInfoUrl.indexOf("?") === -1 ? "?" : "&";
        streamInfoUrl +=
          sep +
          "client_id=" +
          state.clientId +
          "&track_authorization=" +
          trackAuth;

        var streamResp = http.get(streamInfoUrl, {
          "User-Agent": utils.randomUserAgent(),
          Accept: "application/json",
        });

        if (streamResp && !streamResp.error && streamResp.statusCode === 200) {
          var streamData = JSON.parse(streamResp.body);
          if (streamData.url) {
            downloadURL = streamData.url;
            // Determine actual format from transcoding
            var mime =
              (bestTranscoding.format && bestTranscoding.format.mime_type) ||
              "";
            if (mime.indexOf("opus") !== -1) {
              actualFormat = "opus";
            } else if (
              mime.indexOf("mpeg") !== -1 ||
              mime.indexOf("mp3") !== -1
            ) {
              actualFormat = "mp3";
            } else if (mime.indexOf("ogg") !== -1) {
              actualFormat = "ogg";
            }
            log.info(
              "[SC] Got direct stream URL (format: " +
                actualFormat +
                ", protocol: " +
                ((bestTranscoding.format && bestTranscoding.format.protocol) ||
                  "?") +
                ")",
            );
          }
        } else {
          downloadError =
            "Stream URL fetch returned HTTP " +
            (streamResp ? streamResp.statusCode : "null");
          log.warn("[SC] " + downloadError);
        }
      } catch (e) {
        downloadError = "Stream URL fetch failed: " + e.message;
        log.warn("[SC] " + downloadError);
      }
    } else {
      log.warn("[SC] No suitable transcoding found for format: " + audioFormat);
    }
  } else {
    log.warn("[SC] No transcodings or track_authorization available");
  }

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
 * and progressive protocol. HLS URLs are playlists and are not suitable for
 * file.download as a direct audio file.
 */
function pickTranscoding(transcodings, preferFormat) {
  if (!transcodings || transcodings.length === 0) return null;

  // Score each transcoding
  var best = null;
  var bestScore = -1;

  for (var i = 0; i < transcodings.length; i++) {
    var t = transcodings[i];
    if (!t.url || !t.format) continue;
    // Skip snipped (preview) transcodings
    if (t.snipped) continue;

    var score = 0;
    var mime = t.format.mime_type || "";
    var protocol = t.format.protocol || "";

    if (protocol !== "progressive") continue;
    score += 50;

    // Match requested format
    if (preferFormat === "opus" && mime.indexOf("opus") !== -1) {
      score += 30;
    } else if (
      preferFormat === "mp3" &&
      (mime.indexOf("mpeg") !== -1 || mime.indexOf("mp3") !== -1)
    ) {
      score += 30;
    } else if (preferFormat === "ogg" && mime.indexOf("ogg") !== -1) {
      score += 20;
    }

    // Prefer higher quality tiers
    if (t.quality === "hq") {
      score += 10;
    } else if (t.quality === "sq") {
      score += 5;
    }

    if (score > bestScore) {
      bestScore = score;
      best = t;
    }
  }

  return best;
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
// HOME FEED
// ============================================

// ─────────────────────────────────────────────────────────────
// Qué se pide y por qué SOLO eso (medido a mano contra la API pública):
//   · /charts?kind=trending&genre=soundcloud:genres:all-music  → tracks
//     Es la ÚNICA combinación que responde con datos: kind=top y los géneros
//     concretos (reggaeton, latin, pop, hiphoprap...) devuelven {""} vacío con
//     el client_id público. Pedirlos solo gastaría peticiones para nada.
//   · /mixed-selections?kind=top → listas curadas de SoundCloud, cada selección
//     con su propio título ("Artists to watch out for", "Curated by
//     SoundCloud"...), así el feed se arma con lo que ellos publican.
//
// Las selecciones de tipo system-playlist se DESCARTAN: su id es un urn
// ("soundcloud:system-playlists:...") y el detalle se abre por permalink, no
// por id — servirlas en el feed daría un tap que no resuelve. Quedan las
// listas normales, cuyo id numérico es el que ya usa getPlaylist.
//
// El client_id lo resuelve scGet (con su caché y su reintento por 401), así que
// el feed no abre ningún camino de autenticación nuevo.
// ─────────────────────────────────────────────────────────────

var HOME_FEED_TTL_MS = 10 * 60 * 1000;
var HOME_FEED_MAX_POR_LISTA = 20;
var homeFeedCache = null;

// aItemFeedHome traduce un item del formato de la extensión al contrato del
// feed: acá se usa `item_type` interno y el feed espera `type`.
function aItemFeedHome(item, tipo) {
  if (!item || !item.id) return null;
  return {
    id: String(item.id || ""),
    uri: String(item.external_urls || ""),
    type: String(tipo || item.item_type || "track"),
    name: String(item.name || ""),
    artists: String(item.artists || ""),
    album_id: String(item.album_id || ""),
    album_name: String(item.album_name || ""),
    duration_ms: Number(item.duration_ms || 0),
    cover_url: String(item.cover_url || ""),
    isrc: String(item.isrc || ""),
    provider_id: "soundcloud",
  };
}

// tendenciasSoundCloud devuelve los tracks del chart de tendencias.
function tendenciasSoundCloud(limit) {
  var payload = scGet(
    "charts",
    "kind=trending&genre=soundcloud:genres:all-music&limit=" +
      encodeURIComponent(limit) +
      "&offset=0",
  );
  var coleccion = (payload && payload.collection) || [];
  var items = [];
  for (var i = 0; i < coleccion.length; i++) {
    // El chart envuelve cada track: {track: {...}, score: N}.
    var item = aItemFeedHome(
      formatTrack(coleccion[i] && coleccion[i].track),
      "track",
    );
    if (item && item.id) items.push(item);
  }
  return items;
}

// seleccionesSoundCloud devuelve las secciones curadas: una por selección.
function seleccionesSoundCloud(limit) {
  var payload = scGet(
    "mixed-selections",
    "kind=top&limit=" + encodeURIComponent(limit),
  );
  var selecciones = (payload && payload.collection) || [];
  var secciones = [];
  for (var s = 0; s < selecciones.length; s++) {
    var seleccion = selecciones[s] || {};
    var crudos = (seleccion.items && seleccion.items.collection) || [];
    var items = [];
    for (
      var i = 0;
      i < crudos.length && items.length < HOME_FEED_MAX_POR_LISTA;
      i++
    ) {
      var crudo = crudos[i] || {};
      // Solo listas con id usable (ver la nota de arriba sobre system-playlist).
      if (String(crudo.kind || "") !== "playlist" && !crudo.set_type) continue;
      var item = aItemFeedHome(
        formatPlaylistOrAlbum(crudo),
        String(crudo.set_type || "") === "album" ? "album" : "playlist",
      );
      if (item && item.id) items.push(item);
    }
    var titulo = String(seleccion.title || "").trim();
    if (titulo && items.length) {
      secciones.push({ uri: "", title: titulo, items: items });
    }
  }
  return secciones;
}

function getHomeFeed() {
  if (
    homeFeedCache &&
    Date.now() - homeFeedCache.createdAt < HOME_FEED_TTL_MS
  ) {
    return homeFeedCache.value;
  }

  try {
    var secciones = [];

    // Cada bloque es independiente: si el chart falla, las listas curadas
    // igual se devuelven (y al revés).
    try {
      var tendencias = tendenciasSoundCloud(HOME_FEED_MAX_POR_LISTA);
      if (tendencias.length) {
        secciones.push({ uri: "", title: "Tendencias", items: tendencias });
      }
    } catch (e) {
      log.warn("[SC] feed: tendencias no disponibles: " + e.message);
    }

    try {
      var curadas = seleccionesSoundCloud(4);
      for (var i = 0; i < curadas.length; i++) secciones.push(curadas[i]);
    } catch (e) {
      log.warn("[SC] feed: selecciones no disponibles: " + e.message);
    }

    var resultado;
    if (!secciones.length) {
      resultado = {
        success: false,
        error: "SoundCloud sin feed",
        sections: [],
      };
    } else {
      log.info("[SC] Home feed: " + secciones.length + " secciones");
      resultado = { success: true, greeting: "", sections: secciones };
    }
    homeFeedCache = { value: resultado, createdAt: Date.now() };
    return resultado;
  } catch (e) {
    log.error("[SC] getHomeFeed failed: " + String(e));
    return { success: false, error: String(e), sections: [] };
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
  getDownloadUrl: function () {
    return null;
  },
});

log.info("[SC] SoundCloud Extension loaded!");
