// ─────────────────────────────────────────────────────────────
// hoja_letras_fondo.dart — PART de hoja_letras.dart: fondo del modal
// karaoke. La carátula desenfocada con su velo (o el color dominante
// en modo Spotify) la pinta FondoReactivoPortada, el mismo widget que
// usan la cola, la hoja de playlist y "agregar a": antes cada modal
// tenía su copia del fondo y del velo.
// Se conecta con: hoja_letras.dart (misma library) + fondo reactivo.
// Parte del flujo: reproductor (letras, fondo).
// ─────────────────────────────────────────────────────────────

part of 'hoja_letras.dart';

/// Fondo del modal de letras (mismo diseño que el resto de los modales).
/// El velo es un poco más claro que en la cola para que la letra respire.
Widget _fondoCaratula(String? caratula, bool esOscuro) => FondoReactivoPortada(
  caratula: caratula,
  esOscuro: esOscuro,
  radio: 26,
  veloOscuro: 0.68,
  veloClaro: 0.50,
);
