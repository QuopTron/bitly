// ─────────────────────────────────────────────────────────────
// settings_cache_stats.dart — Bloque de estadísticas de la caché de
// streaming (uso, archivos, horas, hits y límite del plan) más el
// selector de límite en MB.
// Se conecta con: settings_cache_piezas + settings_cache_selector.
// Parte del flujo: Ajustes → Rendimiento/Descargas (caché).
// ─────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';

import '../../../../../l10n/app_localizations.dart';
import '../../../../../shared/utilidades/plataforma/responsive.dart';
import '../base/settings_cache_piezas.dart';
import '../piezas/settings_cache_selector.dart';

/// Bloque de estadísticas de caché + selector de tamaño.
Widget cacheStatsBlock({
  required BuildContext context,
  required Responsive r,
  required Color onBg,
  required Color glowColor,
  required Map<String, dynamic> stats,
  required bool saving,
  required ValueChanged<int> onSet,
}) {
  final c = AppLocalizations.of(context).cache;
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      statRowCache(
        Icons.download_done,
        '${fmtBytes(stats['total_size_bytes'] as int? ?? 0)} / '
        '${stats['max_cache_mb'] ?? '?'} MB',
        c.usados,
        onBg,
        r,
      ),
      SizedBox(height: r.spacingXS),
      statRowCache(
        Icons.folder_open,
        c.archivos(stats['file_count'] as int? ?? 0),
        c.enCache,
        onBg,
        r,
      ),
      SizedBox(height: r.spacingXS),
      statRowCache(
        Icons.access_time,
        '${stats['estimated_hours'] ?? 0} h',
        c.deAudio,
        onBg,
        r,
      ),
      SizedBox(height: r.spacingXS),
      statRowCache(
        Icons.thumb_up_alt_outlined,
        '${stats['hit_count'] ?? 0} hits',
        '• ${stats['miss_count'] ?? 0} misses',
        onBg,
        r,
      ),
      SizedBox(height: r.spacingXS),
      statRowCache(
        Icons.shield_outlined,
        '${userLevelLabel(stats['user_level'] as String? ?? 'free')} • '
        '${c.max} ${stats['level_limit_mb'] ?? 200} MB',
        c.limitePlan,
        onBg,
        r,
      ),
      SizedBox(height: r.spacingM),
      Text(
        c.limiteTitulo,
        style: TextStyle(
          fontSize: r.footerSize,
          color: onBg.withValues(alpha: 0.6),
        ),
      ),
      SizedBox(height: r.spacingXS),
      cacheSizeSelector(
        context: context,
        r: r,
        onBg: onBg,
        glowColor: glowColor,
        stats: stats,
        saving: saving,
        onSet: onSet,
      ),
      SizedBox(height: r.spacingXS),
      Row(
        children: [
          Icon(
            Icons.info_outline,
            size: r.footerSize - 1,
            color: onBg.withValues(alpha: 0.35),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              stats['level_limit_mb'] != null
                  ? c.planPermite(
                    '${stats['level_limit_mb']}',
                    userLevelLabel(stats['user_level'] as String? ?? 'free'),
                  )
                  : '',
              style: TextStyle(
                fontSize: r.footerSize - 2,
                color: onBg.withValues(alpha: 0.35),
              ),
            ),
          ),
        ],
      ),
    ],
  );
}
