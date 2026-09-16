// PART de modal_cola.dart: estado vacío de la cola (cuando todavía no hay
// ninguna canción en reproducción).

part of 'modal_cola.dart';

Widget _estadoVacioCola(Responsive r, Color colorBrillo, Color fg) {
  return Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.queue_music, size: 56, color: fg.withValues(alpha: 0.2)),
        const SizedBox(height: 12),
        Text(
          'Cola vacía',
          style: TextStyle(
              fontSize: r.subtitleSize,
              fontWeight: FontWeight.w600,
              color: fg),
        ),
        const SizedBox(height: 4),
        Text(
          'Reproduce una canción para empezar',
          style: TextStyle(
              fontSize: r.footerSize, color: fg.withValues(alpha: 0.5)),
        ),
      ],
    ),
  );
}
