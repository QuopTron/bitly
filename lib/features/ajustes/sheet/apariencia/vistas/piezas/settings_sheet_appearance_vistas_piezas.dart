// ─────────────────────────────────────────────────────────────
// settings_sheet_appearance_vistas_piezas.dart — PART de settings_sheet_new.dart:
// la tira de vistas del bloque "Diseño por vista".
//
// Son deliberadamente tontas (reciben todo por parámetro y no leen
// preferencias): quién tiene el estado es la tarjeta, y así la tira se puede
// mirar —y probar— sin montar toda la hoja.
//
// Se conecta con: settings_sheet_appearance_vistas.dart (la tarjeta que la usa)
// + vista_app.dart (las vistas).
// Parte del flujo: Ajustes → Apariencia → Vistas.
// ─────────────────────────────────────────────────────────────

part of '../../../settings_sheet_new.dart';

/// Tira de burbujas: qué pantalla se está editando.
///
/// La que ya tiene diseño propio lleva un punto de color: de un vistazo se ve
/// qué se tocó sin entrar una por una.
class _TiraVistas extends StatelessWidget {
  final VistaApp seleccionada;
  final Set<VistaApp> personalizadas;
  final StringsVistas t;
  final Responsive r;
  final Color onBg;
  final Color glowColor;
  final ValueChanged<VistaApp> onElegir;

  const _TiraVistas({
    required this.seleccionada,
    required this.personalizadas,
    required this.t,
    required this.r,
    required this.onBg,
    required this.glowColor,
    required this.onElegir,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: r.spacingXS,
      runSpacing: r.spacingXS,
      children: [
        for (final v in VistaApp.values)
          _VistasChip(
            texto: t.nombre(v.clave),
            seleccionado: v == seleccionada,
            marcada: personalizadas.contains(v),
            r: r,
            onBg: onBg,
            glowColor: glowColor,
            onTap: () => onElegir(v),
          ),
      ],
    );
  }
}

/// Una PALETA del cofre como opción, con su muestra grande.
///
/// Es más ancha que una burbuja a propósito: el color se elige MIRANDO, y una
/// muestra chica al lado del nombre no deja comparar dos paletas. Abajo del
/// nombre va el estado con el mismo vocabulario que el cofre ("En uso", "Usar")
/// o, si todavía no se abrió, CÓMO se abre: un candado sin motivo parece un
/// error de la app.
class _TilePaleta extends StatelessWidget {
  /// Colores de la paleta. Vacía = la opción "el cover": las cards toman el
  /// color de su carátula, que es lo de siempre.
  final List<Color> colores;
  final String texto;

  /// Qué dice abajo del nombre ("En uso", "Usar" o cómo se abre).
  final String estado;
  final bool seleccionado;

  /// ¿Ya se puede usar? Las bloqueadas no se tocan y van con candado.
  final bool abierto;
  final Responsive r;
  final Color onBg;
  final Color glowColor;
  final VoidCallback onTap;

  const _TilePaleta({
    required this.colores,
    required this.texto,
    required this.estado,
    required this.seleccionado,
    required this.abierto,
    required this.r,
    required this.onBg,
    required this.glowColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      // Una paleta bloqueada no se toca: elegirla la pondría en uso sin haberla
      // abierto, o sea un candado que no sirve para nada.
      onTap:
          abierto
              ? () {
                Haptico.tap();
                onTap();
              }
              : null,
      child: Opacity(
        opacity: abierto ? 1 : 0.55,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          width: r.spacingL * 3.4,
          padding: EdgeInsets.all(r.spacingXS + 2),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color:
                seleccionado
                    ? glowColor.withValues(alpha: 0.14)
                    : onBg.withValues(alpha: 0.04),
            border: Border.all(
              color:
                  seleccionado
                      ? glowColor.withValues(alpha: 0.55)
                      : onBg.withValues(alpha: 0.10),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // La muestra: el gradiente real de la paleta, tal como va a teñir.
              Container(
                height: r.spacingL,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  gradient:
                      colores.isEmpty
                          ? null
                          : LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: colores,
                          ),
                  color: colores.isEmpty ? onBg.withValues(alpha: 0.10) : null,
                  border: Border.all(color: onBg.withValues(alpha: 0.12)),
                ),
                child:
                    colores.isEmpty
                        ? Icon(
                          Icons.image_outlined,
                          size: r.footerSize + 2,
                          color: onBg.withValues(alpha: 0.55),
                        )
                        : null,
              ),
              SizedBox(height: r.spacingXS),
              Text(
                texto,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: r.footerSize - 1,
                  fontWeight: seleccionado ? FontWeight.w700 : FontWeight.w500,
                  color: seleccionado ? onBg : onBg.withValues(alpha: 0.65),
                ),
              ),
              Row(
                children: [
                  if (!abierto) ...[
                    Icon(
                      Icons.lock_outline_rounded,
                      size: r.footerSize - 2,
                      color: onBg.withValues(alpha: 0.5),
                    ),
                    SizedBox(width: 2),
                  ],
                  Expanded(
                    child: Text(
                      estado,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: r.footerSize - 3,
                        fontWeight:
                            seleccionado ? FontWeight.w700 : FontWeight.w500,
                        color:
                            seleccionado
                                ? glowColor
                                : onBg.withValues(alpha: 0.45),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Una burbuja de la tira de vistas.
class _VistasChip extends StatelessWidget {
  final String texto;
  final bool seleccionado;

  /// ¿Esta vista ya tiene algo propio? (dibuja el punto).
  final bool marcada;
  final Responsive r;
  final Color onBg;
  final Color glowColor;
  final VoidCallback onTap;

  const _VistasChip({
    required this.texto,
    required this.seleccionado,
    required this.marcada,
    required this.r,
    required this.onBg,
    required this.glowColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        Haptico.tap();
        onTap();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: EdgeInsets.symmetric(
          horizontal: r.spacingS,
          vertical: r.spacingXS + 2,
        ),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(999),
          color:
              seleccionado
                  ? glowColor.withValues(alpha: 0.16)
                  : onBg.withValues(alpha: 0.04),
          border: Border.all(
            color:
                seleccionado
                    ? glowColor.withValues(alpha: 0.55)
                    : onBg.withValues(alpha: 0.10),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (marcada) ...[
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: glowColor,
                ),
              ),
              SizedBox(width: r.spacingXS),
            ],
            Text(
              texto,
              style: TextStyle(
                fontSize: r.footerSize - 1,
                fontWeight: seleccionado ? FontWeight.w700 : FontWeight.w500,
                color: seleccionado ? onBg : onBg.withValues(alpha: 0.65),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
