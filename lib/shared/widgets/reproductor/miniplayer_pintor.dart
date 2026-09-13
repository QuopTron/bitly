// ─────────────────────────────────────────────────────────────
// miniplayer_pintor.dart — PART de miniplayer.dart: pintor de la
// barra de progreso — track inactivo, track activo con gradiente,
// glow difuminado detrás del pulgar y el pulgar con punto interior.
// Se conecta con: miniplayer.dart (misma library).
// Parte del flujo: reproducción (pintura de la barra).
// ─────────────────────────────────────────────────────────────

part of 'miniplayer.dart';

/// Pintor de la barra de progreso con glow y pulgar.
class _PintorBarraProgreso extends CustomPainter {
  final double progreso;
  final double pulgarX;
  final double radioPulgar;
  final double radioGlow;
  final double altoTrack;
  final Color colorActivo;
  final Color colorInactivo;
  final Color colorPulgar;
  final Color colorGlow;

  _PintorBarraProgreso({
    required this.progreso,
    required this.pulgarX,
    required this.radioPulgar,
    required this.radioGlow,
    required this.altoTrack,
    required this.colorActivo,
    required this.colorInactivo,
    required this.colorPulgar,
    required this.colorGlow,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final centroY = size.height / 2;
    final topeTrack = centroY - altoTrack / 2;
    final rectTrack = RRect.fromLTRBXY(
        0, topeTrack, size.width, topeTrack + altoTrack, 2, 2);

    // Track inactivo.
    final pincelInactivo = Paint()..color = colorInactivo;
    canvas.drawRRect(rectTrack, pincelInactivo);

    // Track activo con gradiente.
    if (progreso > 0) {
      final pincelActivo = Paint()
        ..shader = LinearGradient(
          colors: [colorActivo, colorActivo.withValues(alpha: 0.4)],
        ).createShader(Rect.fromLTWH(0, 0, pulgarX, size.height));
      canvas.drawRRect(
        RRect.fromLTRBXY(0, topeTrack, pulgarX, topeTrack + altoTrack, 2, 2),
        pincelActivo,
      );
    }

    // Glow detrás del pulgar.
    if (radioGlow > 0) {
      final pincelGlow = Paint()
        ..color = colorGlow.withValues(alpha: 0.25)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, radioGlow);
      canvas.drawCircle(
          Offset(pulgarX, centroY), radioPulgar + radioGlow * 0.5, pincelGlow);
    }

    // Pulgar con punto interior.
    final pincelPulgar = Paint()..color = colorPulgar;
    canvas.drawCircle(Offset(pulgarX, centroY), radioPulgar, pincelPulgar);
    final pincelInterior = Paint()..color = colorInactivo.withValues(alpha: 0.4);
    canvas.drawCircle(
        Offset(pulgarX, centroY), radioPulgar * 0.35, pincelInterior);
  }

  @override
  bool shouldRepaint(_PintorBarraProgreso old) => true;
}