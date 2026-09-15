// ─────────────────────────────────────────────────────────────
// settings_cache_selector.dart — Selector de límite de caché en MB (dropdown con opciones válidas según el plan).
// Se conecta con: settings_cache_section.dart + settings_cache_piezas.
// Parte del flujo: Ajustes → caché (selector de tamaño).
// ─────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';

import '../../../shared/utilidades/plataforma/responsive.dart';


// Selector de límite de caché en MB. `stats` trae el límite del plan y el
/// valor actual; `onSet` avisa cuando el usuario elige otro tamaño.
Widget cacheSizeSelector({
  required BuildContext context,
  required Responsive r,
  required Color onBg,
  required Color glowColor,
  required Map<String, dynamic> stats,
  required bool saving,
  required ValueChanged<int> onSet,
}) {
  final levelLimit = stats['level_limit_mb'] as int? ?? 200;
  final currentMb = stats['max_cache_mb'] as int? ?? 200;
  final options = cacheSizeOptions(levelLimit);
  // Si el valor guardado ya no está (p.ej. bajó el límite del plan), usamos
  // la opción válida más cercana para no romper el dropdown.
  final valorSeguro = options.contains(currentMb)
      ? currentMb
      : options.isEmpty
          ? 200
          : options.reduce(
              (a, b) => (a - currentMb).abs() <= (b - currentMb).abs() ? a : b,
            );

  final dropdownBg = Theme.of(context).brightness == Brightness.dark
      ? const Color(0xFF1A1A1A)
      : const Color(0xFFF5F5F5);

  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      // ignore: deprecated_member_use
      DropdownButtonFormField<int>(
        key: ValueKey('cache_mb_$valorSeguro'),
        initialValue: valorSeguro,
        dropdownColor: dropdownBg,
        items: options.map((mb) {
          final isMax = mb >= levelLimit;
          return DropdownMenuItem(
            value: mb,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '$mb MB',
                  style: TextStyle(
                    fontSize: r.subtitleSize - 1,
                    color: onBg,
                    fontWeight: mb == valorSeguro
                        ? FontWeight.w700
                        : FontWeight.normal,
                  ),
                ),
                if (isMax) ...[
                  const SizedBox(width: 6),
                  Icon(
                    Icons.star,
                    size: r.footerSize - 2,
                    color: glowColor.withValues(alpha: 0.7),
                  ),
                  const SizedBox(width: 3),
                  Text(
                    'máx',
                    style: TextStyle(fontSize: r.footerSize - 2, color: glowColor),
                  ),
                ],
              ],
            ),
          );
        }).toList(),
        onChanged: saving
            ? null
            : (v) {
                if (v != null && v != currentMb) onSet(v);
              },
        decoration: InputDecoration(
          isDense: true,
          contentPadding: EdgeInsets.symmetric(
            horizontal: r.spacingS,
            vertical: r.spacingXS,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: onBg.withValues(alpha: 0.15)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: onBg.withValues(alpha: 0.15)),
          ),
        ),
      ),
    ],
  );
}

/// Opciones de tamaño válidas según el límite del plan.
List<int> cacheSizeOptions(int limit) {
  const base = [50, 100, 200, 500];
  if (limit <= 200) {
    return base.where((v) => v <= limit).toList();
  }
  return [...base, 1000, 1500, 2048, 3072, 4096]
      .where((v) => v <= limit)
      .toList();
}

/// Etiqueta del nivel de plan (Free/Premium/Lifetime).
String userLevelLabel(String level) {
  switch (level) {
    case 'premium':
      return 'Premium';
    case 'lifetime':
      return 'Lifetime';
    default:
      return 'Free';
  }
}

/// Formatea bytes a KB/MB legibles.
String fmtBytes(int bytes) {
  if (bytes < 1024 * 1024) {
    return '${(bytes / 1024).toStringAsFixed(0)} KB';
  }
  return '${(bytes / 1024 / 1024).toStringAsFixed(1)} MB';
}
