// ─────────────────────────────────────────────────────────────
// modal_cola_fondo.dart — PART de modal_cola.dart: fondo del modal
// de cola — carátula desenfocada con el sigma según el perfil de
// rendimiento (el video en vivo lo maneja ReproductorVideoFondo).
// Se conecta con: modal_cola.dart (misma library) + imagen_portada
// + perfil_rendimiento.
// Parte del flujo: reproductor (modal de cola, fondo).
// ─────────────────────────────────────────────────────────────

part of 'modal_cola.dart';

/// Carátula desenfocada que llena el fondo del modal de cola.
Widget _fondoCaratulaCola(String? caratula, bool esOscuro) {
  if (caratula == null || caratula.isEmpty) {
    return const SizedBox.shrink();
  }
  final perfil = sl<ValueNotifier<PerfilRendimiento>>().value;
  return ClipRRect(
    child: ImageFiltered(
      imageFilter: ImageFilter.blur(
        sigmaX: perfil.sigmaDesenfoque,
        sigmaY: perfil.sigmaDesenfoque,
      ),
      child: Transform.scale(
        scale: 1.3,
        child: imagenDesdeUrl(
          caratula,
          ajuste: BoxFit.cover,
          ancho: 512,
          alto: double.infinity,
        ),
      ),
    ),
  );
}