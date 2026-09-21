// ─────────────────────────────────────────────────────────────
// reproductor_fiesta_web.dart — Implementación del motor del invitado en el
// NAVEGADOR: no hay ninguna.
//
// La PWA no puede ser invitada de una fiesta: las pestañas no abren el
// mini-servidor de la red local ni escuchan la difusión, así que no hay a
// quién pedirle el audio. Devuelve null y la hoja de fiesta explica que hace
// falta la app instalada.
//
// Se conecta con: reproductor_fiesta.dart (lo elige por plataforma).
// Parte del flujo: reproductor → modo fiesta → unirme.
// ─────────────────────────────────────────────────────────────

import '../../../audio/base/reproductor_audio.dart';

/// En web no hay motor de fiesta: la pestaña no participa del vínculo de red.
ReproductorAudio? crearReproductorFiesta() => null;
