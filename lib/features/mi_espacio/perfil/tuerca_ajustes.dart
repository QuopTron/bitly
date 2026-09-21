// ─────────────────────────────────────────────────────────────
// tuerca_ajustes.dart — PART de perfil_mi_espacio.dart: el botón de la
// tuerca que abre Ajustes, con el MININUMERITO de notificaciones.
//
// El número sale de notificaciones_tuerca y junta lo que hay para ver: los
// regalos del cofre, las novedades de Conexión y la actualización de la app.
// El color cuenta QUÉ es: dorado si hay un premio, verde si es la versión
// nueva. Se ve igual en celular, PC y TV porque el tamaño sale del
// [Responsive].
//
// Se conecta con: perfil_mi_espacio.dart (misma library) +
// notificaciones_tuerca + colores_app.
// Parte del flujo: Mi Espacio → tuerca → Ajustes.
// ─────────────────────────────────────────────────────────────

part of 'perfil_mi_espacio.dart';

/// Botón de Ajustes con el aviso de lo que hay sin ver.
class _TuercaAjustes extends StatelessWidget {
  final Color onBg;
  final Responsive r;
  final VoidCallback onTap;

  const _TuercaAjustes({
    required this.onBg,
    required this.r,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: EdgeInsets.only(left: r.spacingS),
        child: SizedBox(
          width: 36,
          height: 36,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: onBg.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.settings,
                  size: r.footerSize + 2,
                  color: onBg.withValues(alpha: 0.5),
                ),
              ),
              Positioned(top: -4, right: -4, child: _numerito(context)),
            ],
          ),
        ),
      ),
    );
  }

  /// El mininumerito: aparece solo cuando hay algo y cambia de color según
  /// sea un premio (dorado) o la versión nueva (verde).
  Widget _numerito(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: notificacionesTuerca,
      builder:
          (context, total, _) => ValueListenableBuilder<bool>(
            valueListenable: hayPremio,
            builder: (context, premio, _) {
              if (total <= 0) return const SizedBox.shrink();
              // Dorado si hay premio; verde si solo es la versión nueva.
              final color =
                  premio
                      ? ColoresApp.advertencia
                      : (Theme.of(context).brightness == Brightness.dark
                          ? ColoresApp.verdeBrillante
                          : ColoresApp.verdeMedio);
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                constraints: const BoxConstraints(minWidth: 16),
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: ColoresApp.enSuperficie(false),
                    width: 1,
                  ),
                ),
                child: Text(
                  total > 9 ? '9+' : '$total',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    // El verde de este tema es casi blanco: el número va oscuro.
                    color: ColoresApp.verdeProfundo,
                  ),
                ),
              );
            },
          ),
    );
  }
}
