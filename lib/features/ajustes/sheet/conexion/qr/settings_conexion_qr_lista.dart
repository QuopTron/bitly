// ─────────────────────────────────────────────────────────────
// settings_conexion_qr_lista.dart — PART de settings_sheet_new.dart: la lista
// de aparatos ya vistos en la red que todavía NO están vinculados.
//
// Es el punto de partida del camino sin cámara: el otro aparato ya se anunció
// solo por difusión, así que no hace falta escanear nada — se lo toca y se
// escribe el código que muestra su pantalla.
//
// Se conecta con: settings_conexion_qr_codigo_manual.dart (la usa).
// Parte del flujo: Ajustes → Conexión → vincular con QR.
// ─────────────────────────────────────────────────────────────

part of '../../settings_sheet_new.dart';

/// Los aparatos detectados en la red que todavía no están vinculados.
class _ListaParesCodigo extends StatelessWidget {
  final ServicioLan lan;
  final ParLan? elegido;
  final void Function(ParLan) onElegir;
  final Color onBg;
  final Color glowColor;
  final Responsive r;

  const _ListaParesCodigo({
    required this.lan,
    required this.elegido,
    required this.onElegir,
    required this.onBg,
    required this.glowColor,
    required this.r,
  });

  @override
  Widget build(BuildContext context) {
    final candidatos = lan.pares.value
        .where((p) => !p.vinculado && p.host.isNotEmpty)
        .toList(growable: false);
    if (candidatos.isEmpty) {
      return _AyudaSeccion(
        texto: AppLocalizations.of(context).redConexion.vacio,
        onBg: onBg,
        r: r,
      );
    }
    return Wrap(
      spacing: r.spacingXS,
      runSpacing: r.spacingXS,
      children: [
        for (final p in candidatos)
          ChoiceChip(
            label: Text(p.nombre.isEmpty ? p.host : p.nombre),
            selected: elegido?.id == p.id,
            onSelected: (_) => onElegir(p),
          ),
      ],
    );
  }
}
