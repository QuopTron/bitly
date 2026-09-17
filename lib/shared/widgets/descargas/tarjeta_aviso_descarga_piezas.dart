// ─────────────────────────────────────────────────────────────
// tarjeta_aviso_descarga_piezas.dart — PART de
// tarjeta_aviso_descarga.dart: textos del aviso (título, mensaje y
// motivo), la cruz de cierre y el botón de acción. Reciben la
// tarjeta para leer sus campos y el sistema de escala para que todo
// siga el DPI del dispositivo.
// Se conecta con: tarjeta_aviso_descarga.dart (misma library).
// Parte del flujo: descargas → avisos al usuario.
// ─────────────────────────────────────────────────────────────

part of 'tarjeta_aviso_descarga.dart';

/// Columna de textos: título, mensaje y motivo técnico (si los hay).
Widget _textosAviso(
  TarjetaAvisoDescarga t,
  Responsive r,
  bool oscuro,
  Color onBg,
) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    mainAxisSize: MainAxisSize.min,
    children: [
      Text(
        t.titulo,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: r.subtitleSize,
          height: 1.2,
          fontWeight: FontWeight.w600,
          color: onBg,
        ),
      ),
      if (t.mensaje != null && t.mensaje!.isNotEmpty) ...[
        const SizedBox(height: 2),
        Text(
          t.mensaje!,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: r.footerSize,
            height: 1.25,
            color: ColoresApp.enSuperficieApagado(oscuro),
          ),
        ),
      ],
      if (t.motivo != null && t.motivo!.isNotEmpty) ...[
        const SizedBox(height: 4),
        Text(
          t.motivo!,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: r.footerSize - 3,
            height: 1.2,
            color: ColoresApp.enSuperficieTenue(oscuro),
          ),
        ),
      ],
    ],
  );
}

/// Cruz de cierre, chica y con área táctil suficiente.
Widget _cerrarAviso(TarjetaAvisoDescarga t, Responsive r, Color onBg) =>
    InkWell(
      onTap: t.onCerrar,
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: Icon(
          Icons.close,
          size: r.footerSize,
          color: onBg.withValues(alpha: 0.4),
        ),
      ),
    );

/// Botón de acción: el destacado va con el acento, el resto en gris.
Widget _botonAviso(
  TarjetaAvisoDescarga t,
  Responsive r,
  AccionAvisoDescarga a,
  Color onBg,
) {
  final color = a.destacada ? t.acento : onBg.withValues(alpha: 0.7);
  return InkWell(
    onTap: a.onTap,
    borderRadius: BorderRadius.circular(10),
    child: Container(
      padding: EdgeInsets.symmetric(
        horizontal: r.spacingM,
        vertical: r.spacingXS + 2,
      ),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        color: a.destacada
            ? t.acento.withValues(alpha: 0.16)
            : onBg.withValues(alpha: 0.06),
      ),
      child: Text(
        a.texto,
        style: TextStyle(
          fontSize: r.footerSize,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    ),
  );
}
