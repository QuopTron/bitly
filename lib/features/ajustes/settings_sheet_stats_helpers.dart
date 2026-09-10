part of 'settings_sheet_new.dart';

/// Encabezado de sección del perfil: ícono + etiqueta con el color de acento.
Widget _sectionHeader(
  IconData icon,
  String label,
  Color glow,
  Color onBg,
  Responsive r,
) {
  return Row(
    children: [
      Icon(icon, size: r.subtitleSize, color: glow),
      SizedBox(width: r.spacingS),
      Text(
        label,
        style: TextStyle(
          fontSize: r.subtitleSize,
          fontWeight: FontWeight.w700,
          color: onBg,
        ),
      ),
    ],
  );
}

/// Grid responsive de tarjetas de estadísticas (2 columnas).
Widget _statsGrid(List<Widget> children, BuildContext context, Responsive r) {
  return Wrap(
    spacing: r.spacingS,
    runSpacing: r.spacingS,
    children:
        children
            .map(
              (c) => SizedBox(
                width:
                    (MediaQuery.of(context).size.width -
                        r.spacingL * 2 -
                        r.spacingS) /
                    2,
                child: c,
              ),
            )
            .toList(),
  );
}

/// Tarjeta individual de estadística: ícono, valor grande y etiqueta.
Widget _statCard(
  IconData icon,
  String label,
  String value,
  Color glow,
  Color onBg,
  Responsive r,
) {
  return Container(
    padding: EdgeInsets.all(r.spacingM),
    decoration: BoxDecoration(
      color: onBg.withValues(alpha: 0.04),
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: glow.withValues(alpha: 0.2)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: r.footerSize + 2, color: glow),
        SizedBox(height: r.spacingXS),
        Text(
          value,
          style: TextStyle(
            fontSize: r.titleSize,
            fontWeight: FontWeight.w800,
            color: onBg,
          ),
        ),
        SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(
            fontSize: r.footerSize - 2,
            color: onBg.withValues(alpha: 0.5),
          ),
        ),
      ],
    ),
  );
}
