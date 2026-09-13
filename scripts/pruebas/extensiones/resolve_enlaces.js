// resolve_enlaces.js — verificador de la resolución de ENLACES compartidos:
// URL → extensión `handleUrl` → ítem listo para reproducir. Offline: stubea el
// borde HTTP, no toca la red.
//
// POR QUÉ EXISTE
// Pegar o compartir un enlace (Spotify/YouTube) no funcionaba, y por tres
// motivos que se tapaban entre sí:
//   1. Go nunca llamaba a `handleUrl` (no se leía `urlHandler` del manifest ni
//      existía el RPC), así que el enlace llegaba y moría ahí.
//   2. El polyfill de `URL` del sandbox goja no tenía `searchParams.has()`, y
//      las extensiones de YouTube empiezan con `u.searchParams.has("v")` →
//      TypeError atrapado → "no video ID found" para TODO enlace de YouTube.
//   3. Android no implementaba los canales nativos `share_intent`/`deep_link`.
//
// Este harness cubre la pieza 2 desde el lado de la extensión: que un enlace
// real de Spotify/YouTube se convierta en el ítem correcto. La pieza 1 (elegir
// la extensión por patrón + normalizar a ItemFeed) la cubre el test Go
// `internal/gobackend/url_resolve_test.go`, y el polyfill de `URL` lo cubre
// `internal/extensions/runtime_url_test.go` (ahí SÍ se rompe, porque acá corre
// el `URL` de Node, que es correcto). Los tres juntos son la cadena completa.
//
// OJO: los enlaces de prueba son los REALES que se usaron para reportar el bug,
// incluidos los parámetros `?si=` / `?feature=shared` que antes rompían el
// parseo, y variantes negativas (un enlace de Spotify NO debe resolverlo
// YouTube, y al revés).
//
// Cubre las 7 fuentes que resuelven enlaces: Spotify y YouTube en detalle, más
// Deezer, Tidal, Qobuz, Amazon y Apple Music (en Apple solo lo que sí es
// determinista offline: ver el bloque al final).
//
// Uso: node scripts/pruebas_extensiones/resolve_enlaces.js \
//        <spotify> <ytmusic> <deezer> <tidal> <qobuz> <amazon> <apple>
//
// AUTO-TEST DEL HARNESS (para comprobar que sirve de verdad):
//   SIN_SEARCHPARAMS_HAS=1 node ... resolve_enlaces.js <spotify> <ytmusic>
// quita `URLSearchParams.prototype.has` — o sea reproduce el bug ORIGINAL del
// polyfill de goja — y los casos de YouTube DEBEN fallar. Si con esa variable
// el harness pasa igual, el harness no está probando lo que dice probar.

const fs = require("fs");
const vm = require("vm");

if (process.env.SIN_SEARCHPARAMS_HAS) {
  delete URLSearchParams.prototype.has;
  console.log(
    "[auto-test] URLSearchParams.has ELIMINADO a propósito: los casos de YouTube deben fallar",
  );
}

const RUTAS = {
  spotify: process.argv[2],
  ytmusic: process.argv[3],
  deezer: process.argv[4],
  tidal: process.argv[5],
  qobuz: process.argv[6],
  amazon: process.argv[7],
  apple: process.argv[8],
};
const faltantes = Object.keys(RUTAS).filter((k) => !RUTAS[k]);
if (faltantes.length) {
  console.error("FALTAN las rutas de: " + faltantes.join(", "));
  process.exit(2);
}
const RUTA_SPOTIFY = RUTAS.spotify;
const RUTA_YTMUSIC = RUTAS.ytmusic;
const RUTA_DEEZER = RUTAS.deezer;
const RUTA_TIDAL = RUTAS.tidal;
const RUTA_QOBUZ = RUTAS.qobuz;
const RUTA_AMAZON = RUTAS.amazon;
const RUTA_APPLE = RUTAS.apple;

let fallos = 0;
const check = (nombre, ok, extra) => {
  console.log((ok ? "  ok    " : "  FALLA ") + nombre + (extra ? "  -> " + extra : ""));
  if (!ok) fallos++;
};

const ID_SPOTIFY = "3h5T5JypYU7huFiVYhv1dr";
const ISRC = "USUG12607940";
const ID_DEEZER = "4208859922";

// ── Sandbox común ─────────────────────────────────────────────────────────
function sandboxBase(post, get) {
  const sandbox = {
    console,
    Date, Map, Set, JSON, Number, String, Boolean, Object, Array, Error,
    RegExp, Math, isNaN, isFinite, parseInt, parseFloat, setTimeout,
    encodeURIComponent, decodeURIComponent, atob, btoa,
    URL: require("url").URL,
    registerExtension: (api) => {
      sandbox.__api = api;
    },
    log: { info() {}, debug() {}, warn() {}, error() {} },
    utils: {
      randomUserAgent: () => "UA-de-prueba",
      sha256: () => "hash",
      isDownloadCancelled: () => false,
    },
    file: {},
    http: { post: post || (() => ({ statusCode: 404, body: "{}" })), get },
  };
  sandbox.globalThis = sandbox;
  vm.createContext(sandbox);
  return sandbox;
}

// ═══════════════ SPOTIFY ═══════════════
console.log("\n=== SPOTIFY: enlace real -> track ===");

const pedidosSpotify = [];
const sinAtender = [];

// Stub del borde HTTP. Se atiende por endpoint:
//  - pathfinder  -> GraphQL getTrack (identidad: nombre, artistas, álbum, cover)
//  - spclient    -> metadata (de ahí sale el ISRC: la extensión lo extrae con
//                   una regex sobre el cuerpo, así que alcanza con un cuerpo
//                   que lo contenga)
//  - api.deezer  -> track por ISRC (id cross-proveedor + álbum para el match)
// La autenticación NO se stubea: se precargan los tokens en clientState, que es
// justo lo que hace que initialize/ensureInitialized no salga a la red.
const spotifyPost = (url, body) => {
  pedidosSpotify.push("POST " + url);
  if (url.indexOf("api-partner.spotify.com") !== -1) {
    return {
      statusCode: 200,
      body: JSON.stringify({
        data: {
          trackUnion: {
            name: "BbY WOW",
            firstArtist: { items: [{ name: "KAROL G" }] },
            otherArtists: { items: [{ name: "Judeline" }, { name: "rusowsky" }] },
            albumOfTrack: {
              name: "NO ME ARREPIENTO DE SENTIR TANTO",
              id: "albumDePrueba000000000",
              uri: "spotify:album:albumDePrueba000000000",
              date: { year: 2026, month: 6, day: 12 },
              coverArt: {
                sources: [
                  { url: "https://i.scdn.co/image/coverGrande", width: 640, height: 640 },
                ],
              },
            },
            duration: { totalMilliseconds: 213573 },
          },
        },
      }),
    };
  }
  sinAtender.push("POST " + url);
  return { statusCode: 404, body: "{}" };
};

const spotifyGet = (url, headers) => {
  pedidosSpotify.push("GET " + url.split("?")[0]);
  if (url.indexOf("spclient.wg.spotify.com/metadata") !== -1) {
    // El ISRC se extrae con /isrc[\x00-\x1f]+([A-Za-z0-9]{12})/ sobre el cuerpo.
    return { statusCode: 200, body: "isrc\u0000" + ISRC };
  }
  if (url.indexOf("api.deezer.com/track/isrc:") !== -1) {
    return {
      statusCode: 200,
      body: JSON.stringify({
        id: Number(ID_DEEZER),
        title: "BbY WOW",
        duration: 214,
        isrc: ISRC,
        artist: { name: "KAROL G" },
        album: { title: "NO ME ARREPIENTO DE SENTIR TANTO", cover_xl: "https://e-cdns-images.dzcdn.net/cover" },
      }),
    };
  }
  if (url.indexOf("open.spotify.com") !== -1) {
    sinAtender.push("GET " + url.split("?")[0]);
    return { statusCode: 200, body: "<html></html>", headers: {} };
  }
  sinAtender.push("GET " + url.split("?")[0]);
  return { statusCode: 404, body: "{}" };
};

{
  const sb = sandboxBase(spotifyPost, spotifyGet);
  vm.runInContext(
    fs.readFileSync(RUTA_SPOTIFY, "utf8") +
      "\n;globalThis.__t = { get clientState() { return clientState; } };\n",
    sb,
  );
  const api = sb.__api;
  if (!api || typeof api.handleUrl !== "function") {
    console.error("FALLA: spotify-web no expone handleUrl");
    process.exit(1);
  }

  // Sesión ya válida: evita los endpoints de token/cookies (no es lo que se
  // prueba acá) y deja el camino enfocado en URL -> ítem.
  const expira = Date.now() + 60 * 60 * 1000;
  sb.__t.clientState.accessToken = "token-de-prueba";
  sb.__t.clientState.accessTokenExpiry = expira;
  sb.__t.clientState.clientToken = "client-token-de-prueba";
  sb.__t.clientState.clientTokenExpiry = expira;
  sb.__t.clientState.clientID = "client-id-de-prueba";
  sb.__t.clientState.deviceID = "device-de-prueba";

  // El enlace REAL reportado, con el `?si=` que antes rompía el parseo.
  const res = api.handleUrl("https://open.spotify.com/track/" + ID_SPOTIFY + "?si=f1d4f0f8ba624400");

  check("devuelve success", !!(res && res.success === true), JSON.stringify(res).slice(0, 160));
  check("el tipo es track", !!(res && res.type === "track"), res && res.type);
  const t = (res && res.track) || {};
  check("el id es el del enlace (ignora el ?si=)", t.id === ID_SPOTIFY, String(t.id));
  check("trae nombre", t.name === "BbY WOW", String(t.name));
  check(
    "trae los artistas",
    /KAROL G/.test(String(t.artists || "")),
    String(t.artists),
  );
  check("trae duración", Number(t.duration_ms) === 213573, String(t.duration_ms));
  check(
    "trae el ISRC (la descarga lo necesita para resolver en otra fuente)",
    String(t.isrc || "").toUpperCase() === ISRC,
    String(t.isrc),
  );
  check(
    "trae el id de Deezer (id cross-proveedor para el stream)",
    String(t.deezer_id || "") === ID_DEEZER,
    String(t.deezer_id),
  );
  check(
    "trae carátula",
    /^https:\/\//.test(String(t.cover_url || "")),
    String(t.cover_url),
  );

  const malo = api.handleUrl("https://example.com/track/" + ID_SPOTIFY);
  check(
    "un enlace que NO es de Spotify no resuelve",
    !malo || malo.success === false,
    JSON.stringify(malo).slice(0, 120),
  );
}

// ═══════════════ YOUTUBE ═══════════════
console.log("\n=== YOUTUBE: enlaces reales -> track ===");

// Para un video, handleUrl NO necesita red: extrae el id y devuelve el ítem con
// placeholders (el backend de Go completa la metadata con getTrack). Por eso el
// `fetch` se deja fallando: no debe hacer falta para resolver el enlace.
const yt = sandboxBase(
  () => ({ statusCode: 404, body: "{}" }),
  () => ({ statusCode: 404, body: "{}" }),
);
yt.fetch = () => {
  throw new Error("sin red en el harness");
};
vm.runInContext(fs.readFileSync(RUTA_YTMUSIC, "utf8"), yt, { filename: RUTA_YTMUSIC });
const ytApi = yt.__api;
if (!ytApi || typeof ytApi.handleUrl !== "function") {
  console.error("FALLA: ytmusic-spotiflac no expone handleUrl");
  process.exit(1);
}

// Los enlaces REALES reportados (con ?si= y ?feature=shared, que son los que
// antes no resolvían) + las otras formas que el manifest declara.
const casosYt = [
  ["youtu.be con ?si=", "https://youtu.be/zriaybLwatM?si=JXtvlVgsWpr6lnIy", "zriaybLwatM"],
  ["youtu.be con ?feature=shared", "https://youtu.be/IA0uSub1xy4?feature=shared", "IA0uSub1xy4"],
  ["youtu.be pelado", "https://youtu.be/dQw4w9WgXcQ", "dQw4w9WgXcQ"],
  ["watch?v= con &list=", "https://www.youtube.com/watch?v=dQw4w9WgXcQ&list=PL1234567890", "dQw4w9WgXcQ"],
  ["music.youtube con v=", "https://music.youtube.com/watch?v=kJQP7kiw5Fk", "kJQP7kiw5Fk"],
];

for (const [nombre, url, idEsperado] of casosYt) {
  let res = null;
  let error = null;
  try {
    res = ytApi.handleUrl(url);
  } catch (e) {
    error = e;
  }
  const id = res && res.track ? res.track.id : null;
  check(
    nombre + " -> track " + idEsperado,
    !error && !!res && res.type === "track" && id === idEsperado,
    error ? "excepcion: " + error.message : JSON.stringify({ type: res && res.type, id: id }),
  );
}

// Negativos: un enlace de Spotify no debe resolverlo YouTube.
{
  let res = null;
  let error = null;
  try {
    res = ytApi.handleUrl("https://open.spotify.com/track/" + ID_SPOTIFY + "?si=f1d4f0f8ba624400");
  } catch (e) {
    error = e;
  }
  check(
    "un enlace de Spotify NO lo resuelve YouTube",
    !error && !res,
    error ? "excepcion: " + error.message : JSON.stringify(res),
  );
}

if (sinAtender.length) {
  console.log("\n  (endpoints no atendidos por el stub, revisar si es un cambio de API)");
  sinAtender.slice(0, 5).forEach((u) => console.log("    " + u));
}

// ═══════════════ RESTO DE LAS FUENTES ═══════════════
// Cada extensión resuelve el enlace pidiendo SU API de metadata. El stub
// responde con la forma REAL de esa API (Deezer api.deezer.com, Tidal
// tidal.com/v1, Qobuz widget público), que es justo lo que se rompe cuando el
// proveedor cambia de endpoint o de campos.
//
// Amazon es distinto: el track se arma SIN red (id + nombre placeholder), así
// que se verifica tal cual; y su path de álbum devuelve null a propósito (no
// promete lo que no puede resolver).
//
// Apple Music queda FUERA del camino feliz a propósito: su handleUrl necesita
// un developer token sacado de su HTML/JS, así que offline no es determinista.
// Se verifica lo que sí es un contrato: que no reclame URLs ajenas y que
// devuelva un error explícito (no un ítem inventado) cuando no puede resolver.

console.log("\n=== DEEZER / TIDAL / QOBUZ / AMAZON / APPLE ===");

const ID_TIDAL = "12345678";
const ID_QOBUZ = "abc123def456";
const ID_AMAZON = "B01N4ND1T2";
const ISRC_GENERICO = "USUM72112345";
const COVER = "https://e-cdns-images.dzcdn.net/images/cover/xyz/500x500.jpg";

function cargarFuente(ruta, respuesta) {
  const pedidos = [];
  const sb = sandboxBase(
    (url) => {
      pedidos.push("POST " + url);
      return respuesta(url);
    },
    (url) => {
      pedidos.push("GET " + url);
      return respuesta(url);
    },
  );
  sb.fetch = () => {
    throw new Error("sin red en el harness");
  };
  vm.runInContext(fs.readFileSync(ruta, "utf8"), sb, { filename: ruta });
  return { api: sb.__api, pedidos };
}

function jsonResp(obj) {
  return { statusCode: 200, body: JSON.stringify(obj) };
}

// Resuelve y devuelve el ítem, o el error, sin tirar el harness abajo.
function resuelve(api, url) {
  try {
    return { res: api.handleUrl(url) };
  } catch (e) {
    return { res: null, error: e };
  }
}

// ── Deezer ────────────────────────────────────────────────────────────────
{
  const idTrack = 3135556;
  const idAlbum = 119606;
  const { api } = cargarFuente(RUTA_DEEZER, (url) => {
    if (url.indexOf("/track/" + idTrack) !== -1) {
      return jsonResp({
        id: idTrack,
        readable: true,
        title: "Harder, Better, Faster, Stronger",
        duration: 224,
        isrc: ISRC_GENERICO,
        track_position: 1,
        disk_number: 1,
        artist: { id: 27, name: "Daft Punk" },
        album: { id: idAlbum, title: "Discovery", cover_xl: COVER },
      });
    }
    // La tracklist NO viene en el objeto del álbum: Deezer la sirve en
    // /album/<id>/tracks. Si ese endpoint no se atiende, el álbum resuelve sin
    // pistas — que es exactamente lo que rompe una descarga de álbum.
    if (url.indexOf("/album/" + idAlbum + "/tracks") !== -1) {
      return jsonResp({
        data: [
          {
            id: idTrack,
            title: "Harder, Better, Faster, Stronger",
            duration: 224,
            isrc: ISRC_GENERICO,
            track_position: 1,
            disk_number: 1,
            artist: { id: 27, name: "Daft Punk" },
          },
        ],
      });
    }
    if (url.indexOf("/album/" + idAlbum) !== -1) {
      return jsonResp({
        id: idAlbum,
        title: "Discovery",
        cover_xl: COVER,
        nb_tracks: 1,
        artist: { id: 27, name: "Daft Punk" },
      });
    }
    return { statusCode: 404, body: "{}" };
  });

  // Convención de ids (la usa la normalización de Go): el id del ítem va
  // namespaced ("deezer:3135556") y el id "crudo" del proveedor va aparte
  // ("deezer_id") para las llamadas cross-proveedor.
  //
  // Ojo: solo spotify-web devuelve `success`. Deezer/Tidal/Qobuz anuncian el
  // resultado con `type` (y un `track`/`album` no nulo) — por eso la aserción no
  // exige `success` acá; la normalización de Go tolera las dos formas.
  const t = resuelve(api, "https://www.deezer.com/track/" + idTrack);
  const item = t.res || {};
  check(
    "deezer track -> track deezer:" + idTrack,
    item.type === "track" &&
      !!item.track &&
      String(item.track.id) === "deezer:" + idTrack,
    JSON.stringify({ type: item.type, id: item.track && item.track.id }),
  );
  check(
    "deezer track trae el id crudo del proveedor (deezer_id)",
    String(item.track && item.track.deezer_id) === "" + idTrack,
    String(item.track && item.track.deezer_id),
  );
  check(
    "deezer track trae ISRC",
    String((item.track && item.track.isrc) || "").toUpperCase() === ISRC_GENERICO,
    String(item.track && item.track.isrc),
  );

  const a = resuelve(api, "https://www.deezer.com/album/" + idAlbum);
  const album = a.res || {};
  check(
    "deezer album -> album deezer:" + idAlbum + " con nombre",
    album.type === "album" &&
      String((album.album || {}).id) === "deezer:" + idAlbum &&
      album.name === "Discovery",
    JSON.stringify({ type: album.type, id: (album.album || {}).id, name: album.name }),
  );
  check(
    "deezer album trae su tracklist (se pide en /album/<id>/tracks)",
    Array.isArray(album.tracks) && album.tracks.length === 1 && !!album.tracks[0].isrc,
    "tracks=" + (album.tracks || []).length,
  );
}

// ── Tidal ─────────────────────────────────────────────────────────────────
{
  const { api } = cargarFuente(RUTA_TIDAL, (url) => {
    if (url.indexOf("/v1/tracks/" + ID_TIDAL) !== -1) {
      return jsonResp({
        id: Number(ID_TIDAL),
        title: "Harder, Better, Faster, Stronger",
        duration: 224,
        isrc: ISRC_GENERICO,
        trackNumber: 1,
        volumeNumber: 1,
        artist: { id: 1, name: "Daft Punk" },
        artists: [{ id: 1, name: "Daft Punk" }],
        album: { id: 999, title: "Discovery", cover: "abc-cover-id", numberOfTracks: 1 },
      });
    }
    return { statusCode: 404, body: "{}" };
  });

  const t = resuelve(api, "https://tidal.com/browse/track/" + ID_TIDAL);
  const item = t.res || {};
  check(
    "tidal track -> track tidal:" + ID_TIDAL,
    item.type === "track" && !!item.track && String(item.track.id) === "tidal:" + ID_TIDAL,
    JSON.stringify(item.track && item.track.id),
  );
  check(
    "tidal track trae el id crudo del proveedor (tidal_id)",
    String(item.track && item.track.tidal_id) === ID_TIDAL,
    String(item.track && item.track.tidal_id),
  );
  check(
    "tidal track trae nombre (no el placeholder vacío)",
    !!(item.track && String(item.track.name || "").trim().length),
    String(item.track && item.track.name),
  );
  check(
    "tidal track trae ISRC",
    String((item.track && item.track.isrc) || "").toUpperCase() === ISRC_GENERICO,
    String(item.track && item.track.isrc),
  );
}

// ── Qobuz ─────────────────────────────────────────────────────────────────
{
  const { api } = cargarFuente(RUTA_QOBUZ, (url) => {
    if (url.indexOf("widget/getTrackById") !== -1) {
      return jsonResp({
        id: 19512574,
        title: "Harder, Better, Faster, Stronger",
        duration: 224,
        isrc: ISRC_GENERICO,
        track_number: 1,
        media_number: 1,
        performer: { id: 123, name: "Daft Punk" },
        album: { id: ID_QOBUZ, title: "Discovery", image: { large: COVER } },
      });
    }
    if (url.indexOf("widget/getAlbumById") !== -1) {
      return jsonResp({
        id: ID_QOBUZ,
        title: "Discovery",
        upc: "0190296611916",
        tracks_count: 1,
        artist: { id: 123, name: "Daft Punk" },
        image: { large: COVER },
        tracks: {
          items: [
            {
              id: 19512574,
              title: "Harder, Better, Faster, Stronger",
              duration: 224,
              isrc: ISRC_GENERICO,
              track_number: 1,
              media_number: 1,
              performer: { id: 123, name: "Daft Punk" },
            },
          ],
        },
      });
    }
    return { statusCode: 404, body: "{}" };
  });

  const t = resuelve(api, "https://play.qobuz.com/track/19512574");
  const item = t.res || {};
  check(
    "qobuz track -> track qobuz:19512574",
    item.type === "track" &&
      !!item.track &&
      String(item.track.id) === "qobuz:19512574",
    JSON.stringify({ type: item.type, id: item.track && item.track.id }),
  );
  check(
    "qobuz track trae ISRC",
    String((item.track && item.track.isrc) || "").toUpperCase() === ISRC_GENERICO,
    String(item.track && item.track.isrc),
  );

  const a = resuelve(api, "https://play.qobuz.com/album/" + ID_QOBUZ);
  const album = a.res || {};
  check(
    "qobuz album -> album qobuz:" + ID_QOBUZ + " con su tracklist",
    album.type === "album" &&
      String((album.album || {}).id) === "qobuz:" + ID_QOBUZ &&
      Array.isArray(album.tracks) &&
      album.tracks.length === 1,
    JSON.stringify({
      type: album.type,
      id: (album.album || {}).id,
      tracks: (album.tracks || []).length,
    }),
  );
  check(
    "qobuz album trae el UPC (se usa para resolver en otras fuentes)",
    String((album.album || {}).upc) === "0190296611916",
    String((album.album || {}).upc),
  );
}

// ── Amazon ────────────────────────────────────────────────────────────────
{
  const { api, pedidos } = cargarFuente(RUTA_AMAZON, () => ({ statusCode: 404, body: "{}" }));

  // El track se arma sin red: id del ASIN + nombre placeholder (el backend de
  // Go lo completa después con getTrack).
  const t = resuelve(api, "https://music.amazon.com/tracks/" + ID_AMAZON);
  const item = t.res || {};
  check(
    "amazon track -> track " + ID_AMAZON + " (sin pedir red)",
    item.type === "track" && String(item.track && item.track.id) === ID_AMAZON,
    JSON.stringify(item).slice(0, 150),
  );
  check("amazon track no hizo ningún pedido HTTP", pedidos.length === 0, String(pedidos.length));

  const a = resuelve(api, "https://music.amazon.com/albums/" + ID_AMAZON);
  check(
    "amazon album NO se promete: devuelve null",
    !a.res,
    JSON.stringify(a.res).slice(0, 120),
  );
}

// ── Apple Music ───────────────────────────────────────────────────────────
{
  const { api } = cargarFuente(RUTA_APPLE, () => ({ statusCode: 404, body: "{}" }));

  const ajena = resuelve(api, "https://open.spotify.com/track/" + ID_SPOTIFY);
  check(
    "apple no reclama un enlace que no es suyo",
    !ajena.res || ajena.res.success === false,
    JSON.stringify(ajena.res).slice(0, 120),
  );

  // Sin poder sacar el developer token de su HTML, debe fallar EXPLÍCITAMENTE
  // (success:false + error). Un ítem inventado sería peor: la app lo abriría
  // vacío en vez de pasar al siguiente proveedor.
  const propia = resuelve(api, "https://music.apple.com/us/album/album-name/1440833098?i=1440833151");
  const r = propia.res || {};
  check(
    "apple: sin su token falla explícito (no devuelve un ítem vacío)",
    !r.type && (r.success === false || r.error),
    JSON.stringify(r).slice(0, 150),
  );
}

if (fallos) console.log("\n" + fallos + " FALLA(S)");
process.exit(fallos === 0 ? 0 : 1);
