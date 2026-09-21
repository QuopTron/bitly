// ─────────────────────────────────────────────────────────────
// reproductor_fiesta.dart — El motor de audio que usa el INVITADO del modo
// fiesta (uno propio, para no mezclarlo con el reproductor de la app).
//
// Se elige por import condicional, igual que en el reproductor: nativo
// (media_kit/mpv) donde existe, y en el navegador devuelve null — la PWA no
// puede ser invitada porque no hay mini-servidor ni sockets en una pestaña.
//
// Se conecta con: servicio_fiesta_invitado.dart (lo pide) + las dos
// implementaciones de abajo.
// Parte del flujo: reproductor → modo fiesta → unirme.
// ─────────────────────────────────────────────────────────────

export 'reproductor_fiesta_nativo.dart'
    if (dart.library.js_interop) 'reproductor_fiesta_web.dart';
