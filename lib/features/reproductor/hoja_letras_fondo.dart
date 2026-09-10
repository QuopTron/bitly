// ─────────────────────────────────────────────────────────────
// hoja_letras_fondo.dart — PART de hoja_letras.dart: fondo del
// modal de letras — carátula desenfocada con el sigma según el
// perfil de rendimiento.
// Se conecta con: hoja_letras.dart (misma library) + imagen_portada
// + perfil_rendimiento.
// Parte del flujo: reproductor (letras, fondo).
// ─────────────────────────────────────────────────────────────

part of 'hoja_letras.dart';

/// Carátula desenfocada que llena el fondo del modal.
Widget _fondoCaratula(String? caratula, bool esOscuro) {
  if (caratula == null || caratula.isEmpty) {
    return const SizedBox.shrink();
  }
  final perfil = sl<ValueNotifier<PerfilRendimiento>>().value;
  return ClipRRect(
    borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
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