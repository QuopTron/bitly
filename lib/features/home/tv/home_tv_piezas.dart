// ─────────────────────────────────────────────────────────────
// home_tv_piezas.dart — PART de home_tv.dart: la barra de navegación
// SUPERIOR de la tele y su miniplayer.
//
// Va aparte del shell para que cada archivo haga una sola cosa: home_tv decide
// qué sección se ve, este dibuja la navegación (ítems grandes, ícono + nombre,
// con el activo marcado) y la barra del miniplayer.
//
// Los tamaños son FIJOS a propósito: en TV la app se dibuja en un lienzo lógico
// de 1280 y se escala a la pantalla (ver vista_tv), así que 24 px de ícono
// miden lo mismo en cualquier televisor.
//
// Se conecta con: home_tv.dart (misma library) + cubit_cola + l10n.
// Parte del flujo: Home (variante TV).
// ─────────────────────────────────────────────────────────────

part of 'home_tv.dart';

/// Alto de la barra de navegación de TV.
const double _altoNavTv = 78;

/// Barra de navegación SUPERIOR de TV: logo y las tres secciones.
class _NavSuperiorTv extends StatelessWidget {
  final bool isDark;
  final int currentIndex;
  final ValueChanged<int> onTap;

  const _NavSuperiorTv({
    required this.isDark,
    required this.currentIndex,
    required this.onTap,
  });

  static const _icons = [
    Icons.search_rounded,
    Icons.home_rounded,
    Icons.grid_view_rounded,
  ];

  @override
  Widget build(BuildContext context) {
    final onBg = ColoresApp.enSuperficie(isDark);
    final pestanas = AppLocalizations.of(context).nav.pestanas;

    return Container(
      height: _altoNavTv,
      padding: const EdgeInsets.symmetric(horizontal: 26),
      color: ColoresApp.superficie(isDark).withValues(alpha: 0.5),
      child: Row(
        children: [
          Icon(Icons.music_note_rounded, color: onBg, size: 26),
          const SizedBox(width: 10),
          Text(
            'BITLY',
            style: TextStyle(
              color: onBg,
              fontSize: 19,
              fontWeight: FontWeight.bold,
              letterSpacing: 4,
            ),
          ),
          const SizedBox(width: 34),
          for (var i = 0; i < _icons.length; i++)
            _ItemNavTv(
              icono: _icons[i],
              texto: pestanas[i],
              seleccionado: currentIndex == i,
              isDark: isDark,
              onBg: onBg,
              onTap: () => onTap(i),
            ),
        ],
      ),
    );
  }
}

/// Un ítem de la navegación de TV. Marcado = fondo tenue + contorno + texto
/// en negrita: a metros, el color solo no alcanza para saber dónde estás.
class _ItemNavTv extends StatelessWidget {
  final IconData icono;
  final String texto;
  final bool seleccionado;
  final bool isDark;
  final Color onBg;
  final VoidCallback onTap;

  const _ItemNavTv({
    required this.icono,
    required this.texto,
    required this.seleccionado,
    required this.isDark,
    required this.onBg,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final acento = isDark ? ColoresApp.verdeBrillante : ColoresApp.verdeMedio;
    final color = seleccionado ? acento : onBg.withValues(alpha: 0.55);
    return Padding(
      padding: const EdgeInsets.only(right: 10),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          decoration: BoxDecoration(
            color: seleccionado ? acento.withValues(alpha: 0.16) : null,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color:
                  seleccionado
                      ? acento.withValues(alpha: 0.5)
                      : Colors.transparent,
              width: 1.2,
            ),
          ),
          child: Row(
            children: [
              Icon(icono, size: 24, color: color),
              const SizedBox(width: 10),
              Text(
                texto,
                style: TextStyle(
                  fontSize: 15.5,
                  fontWeight: seleccionado ? FontWeight.w700 : FontWeight.w500,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Miniplayer de TV: barra ancha al pie, SIN sombra (en una tele la sombra se
/// recompone en cada frame y a metros no se ve) y se oculta cuando no hay nada
/// sonando.
class _MiniplayerTv extends StatelessWidget {
  final Widget miniPlayer;

  const _MiniplayerTv({required this.miniPlayer});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<CubitCola, EstadoCola>(
      buildWhen:
          (prev, curr) =>
              prev.tieneActual != curr.tieneActual ||
              prev.actual?.id != curr.actual?.id,
      builder: (context, cola) {
        if (!cola.tieneActual) return const SizedBox.shrink();
        final esOscuro = Theme.of(context).brightness == Brightness.dark;
        final onBg = ColoresApp.enSuperficie(esOscuro);
        return Padding(
          padding: const EdgeInsets.fromLTRB(22, 4, 22, 16),
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: onBg.withValues(alpha: 0.10)),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: miniPlayer,
            ),
          ),
        );
      },
    );
  }
}
