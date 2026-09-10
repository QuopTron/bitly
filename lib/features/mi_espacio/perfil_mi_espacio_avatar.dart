// ─────────────────────────────────────────────────────────────
// perfil_mi_espacio_avatar.dart — PART de perfil_mi_espacio.dart:
// la fila del avatar del perfil — círculo con gradiente, nombre
// de usuario, contadores (canciones/playlists), insignia de
// canciones amadas y botón de ajustes (abre la hoja de tema/
// idioma).
// Se conecta con: perfil_mi_espacio.dart (misma library) +
// perfil_hoja_ajustes + l10n + responsive.
// Parte del flujo: Home → Mi Espacio (fila del avatar).
// ─────────────────────────────────────────────────────────────

part of 'perfil_mi_espacio.dart';

/// Fila del avatar: círculo con gradiente, nombre, contadores y ajustes.
Widget _filaAvatar(PerfilMiEspacio p, BuildContext context) {
  final loc = AppLocalizations.of(context);
  final r = Responsive(context);
  final tamanoAvatar = r.titleSize * 2.2;
  final nombreMostrado =
      p.username.isNotEmpty ? p.username : loc.setup.miSpaceGuest;

  return Row(
    children: [
      Container(
        width: tamanoAvatar,
        height: tamanoAvatar,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
            colors: [
              p.colorBrillo.withValues(alpha: 0.35),
              p.colorBrillo.withValues(alpha: 0.1),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          border: Border.all(
            color: p.colorBrillo.withValues(alpha: 0.45),
            width: 2,
          ),
          boxShadow: [
            BoxShadow(
              color: p.colorBrillo.withValues(alpha: 0.25),
              blurRadius: 14,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Icon(
          Icons.person,
          size: tamanoAvatar * 0.45,
          color: p.onBg.withValues(alpha: 0.5),
        ),
      ),
      SizedBox(width: r.spacingM),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              nombreMostrado,
              style: TextStyle(
                fontSize: r.subtitleSize,
                fontWeight: FontWeight.w600,
                color: p.onBg,
              ),
            ),
            SizedBox(height: 2),
            Text(
              '${p.cancionesAmadas} ${loc.setup.miSpaceSongCount}  •  '
              '${p.playlistsCount} ${loc.setup.miSpacePlaylistCount}',
              style: TextStyle(
                fontSize: r.footerSize - 1,
                color: p.onBg.withValues(alpha: 0.4),
              ),
            ),
          ],
        ),
      ),
      if (p.cancionesAmadas > 0)
        Container(
          padding: EdgeInsets.symmetric(horizontal: r.spacingS, vertical: 4),
          decoration: BoxDecoration(
            color: p.colorBrillo.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.favorite,
                size: r.footerSize,
                color: p.colorBrillo,
              ),
              SizedBox(width: 4),
              Text(
                '${p.cancionesAmadas}',
                style: TextStyle(
                  fontSize: r.footerSize - 1,
                  fontWeight: FontWeight.w600,
                  color: p.colorBrillo,
                ),
              ),
            ],
          ),
        ),
      if (p.onTemaCambiado != null)
        GestureDetector(
          onTap: () => showSettingsSheet(
            context,
            username: p.username,
            isDark: Theme.of(context).brightness == Brightness.dark,
            onThemeChanged: p.onTemaCambiado!,
            onLanguageChanged: p.onIdiomaCambiado ?? () {},
            likedCount: '${p.cancionesAmadas}',
            downloadedCount: '${p.descargadosCount}',
          ),
          child: Padding(
            padding: EdgeInsets.only(left: r.spacingS),
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: p.onBg.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                Icons.settings,
                size: r.footerSize + 2,
                color: p.onBg.withValues(alpha: 0.5),
              ),
            ),
          ),
        ),
    ],
  );
}