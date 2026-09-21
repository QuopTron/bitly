// ─────────────────────────────────────────────────────────────
// settings_sheet_more_tab.dart — PART de settings_sheet_new.dart:
// pestaña Más de Ajustes.
//
// Quedó liviana a propósito: reportar un problema, entender la caché de
// streaming y ver la versión/actualizaciones. Todo lo que era cuenta
// (Premium, Google) se fue a la pestaña Cuenta, y lo que era fuente de
// música (Soulseek, biblioteca local) a Proveedores, así este tab deja de
// ser una lista larguísima de cosas sin relación.
//
// Se conecta con: settings_sheet_more_report.dart, settings_sheet_cache_card
// y settings_sheet_release_info.dart (misma library).
// Parte del flujo: Ajustes → Más.
// ─────────────────────────────────────────────────────────────

part of '../settings_sheet_new.dart';

class _MoreTab extends StatelessWidget {
  final Color glowColor;

  const _MoreTab({required this.glowColor});

  @override
  Widget build(BuildContext context) {
    final r = Responsive(context);
    final t = AppLocalizations.of(context).ajustes;

    return SingleChildScrollView(
      padding: EdgeInsets.all(r.spacingL),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(height: r.spacingS),
          // Mismo encabezado que Cuenta/Proveedores: título + bajada.
          _TituloApartado(
            titulo: t.mas,
            bajada: t.masAyuda,
            glowColor: glowColor,
          ),
          SizedBox(height: r.spacingL),
          // Report a bug / suggestion
          _ReportCardWidget(glowColor: glowColor),
          SizedBox(height: r.spacingM),
          // Streaming cache, explained
          _CacheExplainedCard(glowColor: glowColor),
          SizedBox(height: r.spacingM),
          _VersionInfoCard(
            glowColor: glowColor,
            onShowVersions: (ctx) => _abrirVersiones(ctx, glowColor),
          ),
        ],
      ),
    );
  }
}

/// Abre la hoja con la versión actual y todas las releases de GitHub.
/// `sobreHoja`: sale desde dentro de Ajustes y tapa esa hoja por completo.
Future<void> _abrirVersiones(BuildContext context, Color glowColor) {
  return mostrarHoja<void>(
    context: context,
    sobreHoja: true,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (_) => _VersionSheet(glowColor: glowColor),
  );
}
