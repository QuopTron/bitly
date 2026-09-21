// ─────────────────────────────────────────────────────────────
// settings_sheet_proveedores_tab.dart — PART de settings_sheet_new.dart:
// pestaña Proveedores de Ajustes.
//
// Agrupa de dónde sale la música: el catálogo sin invitación (Soulseek,
// que se crea solo con tu nombre) y tu propia biblioteca importada. Son
// las dos fuentes que el usuario agrega, por eso van juntas y separadas
// del resto.
//
// Se conecta con: settings_sheet_soulseek_card.dart y
// settings_sheet_biblioteca_local.dart (misma library).
// Parte del flujo: Ajustes → Proveedores.
// ─────────────────────────────────────────────────────────────

part of 'settings_sheet_new.dart';

class _ProveedoresTab extends StatelessWidget {
  final Color glowColor;

  const _ProveedoresTab({required this.glowColor});

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
          _TituloApartado(
            titulo: t.proveedores,
            bajada: t.proveedoresAyuda,
            glowColor: glowColor,
          ),
          SizedBox(height: r.spacingL),
          // Soulseek: cuenta propia en un click (nombre + Siguiente) para el
          // catálogo en FLAC que no pide invitación, pago ni datos.
          _SoulseekCard(glowColor: glowColor),
          SizedBox(height: r.spacingM),
          // Música propia del usuario (importación local + dedupe por ISRC)
          _BibliotecaLocalCard(glowColor: glowColor),
        ],
      ),
    );
  }
}
