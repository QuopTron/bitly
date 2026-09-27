// ─────────────────────────────────────────────────────────────
// update_sheet_acciones.dart — PART de update_modal.dart: notas de la release y botones de acción (descargar e instalar / ahora no) de la hoja de actualización.
// Se conecta con: update_modal.dart (misma library) + update_sheet_ui.
// Parte del flujo: Ajustes → Versión → actualización (acciones).
// ─────────────────────────────────────────────────────────────

part of '../base/update_modal.dart';

// Notas de la release (cuerpo del changelog).
Widget _notasActualizacion(
  _EstadoHojaActualizacion st,
  Responsive r,
  Color sobreFondo,
  Color borde,
) {
  return Padding(
    padding: EdgeInsets.symmetric(horizontal: r.spacingXL),
    child: Container(
      width: double.infinity,
      padding: EdgeInsets.all(r.spacingM),
      decoration: BoxDecoration(
        color: sobreFondo.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borde),
      ),
      child: Text(
        st.widget.info.body,
        style: TextStyle(
          fontSize: r.footerSize,
          color: sobreFondo.withValues(alpha: 0.7),
          height: 1.5,
        ),
        maxLines: 8,
        overflow: TextOverflow.ellipsis,
      ),
    ),
  );
}

/// Botón principal de la hoja, según en qué punto esté la actualización:
///
///   · bajando   → "Cancelar"
///   · ya bajada → "Instalar" (el APK está en disco y espera)
///   · al principio → "Descargar" (en Android, en segundo plano)
Widget _botonesActualizacion(
  _EstadoHojaActualizacion st,
  BuildContext context,
  Responsive r,
  Color apagado,
) {
  final u = AppLocalizations.of(context).update;
  final enAndroid = ActualizacionServicio.soportado;

  if (st._descargando) {
    return _botonAccion(
      r,
      onTap: st._cancelarDescarga,
      icono: Icons.close_rounded,
      texto: u.cancelar,
      color: apagado,
    );
  }

  final yaBajada = st._descargada;
  return Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      _botonAccion(
        r,
        // En Android: si ya está bajada, instala; si no, la deja bajando en
        // segundo plano. En escritorio se mantiene la descarga directa.
        onTap:
            yaBajada
                ? st._instalarLoBajado
                : (enAndroid ? st._descargarEnFondo : st._descargarEInstalar),
        icono:
            yaBajada ? Icons.install_mobile_rounded : Icons.download_rounded,
        texto: yaBajada ? u.instalar : u.descargar,
        color: ColoresApp.exito,
      ),
      // Ayuda corta: qué va a pasar al tocarlo. En Android explica que sigue
      // en segundo plano; con el APK ya bajado, que puede esperar.
      if (enAndroid) ...[
        SizedBox(height: r.spacingXS),
        Text(
          yaBajada ? u.instalalaCuandoQuieras : u.enSegundoPlano,
          style: TextStyle(
            fontSize: r.footerSize - 1,
            color: apagado.withValues(alpha: 0.7),
          ),
          textAlign: TextAlign.center,
        ),
      ],
      Padding(
        padding: EdgeInsets.fromLTRB(
          r.spacingXL,
          r.spacingS,
          r.spacingXL,
          r.spacingXL,
        ),
        child: SizedBox(
          width: double.infinity,
          height: 44,
          child: TextButton(
            onPressed: () => Navigator.of(context).pop(),
            style: TextButton.styleFrom(
              foregroundColor: apagado,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: Text(
              // Cerrar sin instalar: lo que ya se bajó queda igual, y la
              // notificación sigue ahí para instalarlo cuando quiera.
              u.ahoraNo,
              style: TextStyle(
                fontSize: r.footerSize,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ),
      ),
    ],
  );
}

/// Botón ancho de la hoja con ícono + texto.
Widget _botonAccion(
  Responsive r, {
  required VoidCallback onTap,
  required IconData icono,
  required String texto,
  required Color color,
}) {
  return Padding(
    padding: EdgeInsets.symmetric(horizontal: r.spacingXL),
    child: SizedBox(
      width: double.infinity,
      height: 48,
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          elevation: 0,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icono, size: 20),
            SizedBox(width: r.spacingS),
            Text(
              texto,
              style: TextStyle(
                fontSize: r.subtitleSize,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
