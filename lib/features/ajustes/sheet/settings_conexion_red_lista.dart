// ─────────────────────────────────────────────────────────────
// settings_conexion_red_lista.dart — PART de settings_sheet_new.dart: la
// lista de aparatos de la red local.
//
// Se armó aparte de la sección para que cada archivo haga una sola cosa: la
// sección pide las acciones, la lista decide cómo se ven (y se vuelve a
// pintar sola cada vez que aparece, se va o cambia un aparato).
//
// Se conecta con: settings_conexion_red.dart (la sección) +
// settings_conexion_red_fila.dart (cada aparato) + servicio_lan.
// Parte del flujo: Ajustes → Conexión → biblioteca en tu red.
// ─────────────────────────────────────────────────────────────

part of 'settings_sheet_new.dart';

/// Los aparatos que se ven ahora mismo en la red.
class _ListaPares extends StatelessWidget {
  final ServicioLan lan;

  /// Id del aparato con una operación en curso (null = ninguno).
  final String? ocupado;

  final Color glowColor;
  final Color onBg;
  final Responsive r;
  final Future<void> Function(ParLan) onVincular;
  final Future<void> Function(ParLan) onTraer;
  final Future<void> Function(ParLan) onOlvidar;

  const _ListaPares({
    required this.lan,
    required this.ocupado,
    required this.glowColor,
    required this.onBg,
    required this.r,
    required this.onVincular,
    required this.onTraer,
    required this.onOlvidar,
  });

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context).redConexion;
    return ValueListenableBuilder<List<ParLan>>(
      valueListenable: lan.pares,
      builder:
          (context, pares, _) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (pares.isEmpty)
                _AyudaSeccion(texto: loc.vacio, onBg: onBg, r: r),
              for (final par in pares)
                Padding(
                  padding: EdgeInsets.only(bottom: r.spacingS),
                  child: _FilaPar(
                    par: par,
                    ocupado: ocupado == par.id,
                    glowColor: glowColor,
                    onBg: onBg,
                    r: r,
                    onVincular: () => onVincular(par),
                    onTraer: () => onTraer(par),
                    onOlvidar: () => onOlvidar(par),
                  ),
                ),
            ],
          ),
    );
  }
}
