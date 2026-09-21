// ─────────────────────────────────────────────────────────────
// modal_cola_fondo.dart — PART de modal_cola.dart: fondo del modal de
// la cola. La carátula desenfocada con su velo (o el color dominante en
// modo Spotify) la pinta FondoReactivoPortada, compartido con el
// karaoke, la hoja de playlist y "agregar a".
// El video en vivo no lo pinta este archivo: lo maneja la hoja (y ahí el
// velo se aplica aparte, porque el video no trae el suyo).
// Se conecta con: modal_cola.dart (misma library) + fondo reactivo.
// Parte del flujo: reproductor (modal de cola, fondo).
// ─────────────────────────────────────────────────────────────

part of '../base/hoja/modal_cola.dart';

/// Fondo de carátula del modal de cola (mismo diseño que el resto).
Widget _fondoCaratulaCola(String? caratula, bool esOscuro) =>
    FondoReactivoPortada(caratula: caratula, esOscuro: esOscuro, radio: 26);
