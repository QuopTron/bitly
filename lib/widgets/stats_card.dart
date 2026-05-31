import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bitly/providers/download_queue_provider.dart';
import 'package:bitly/providers/stats_provider.dart';
import 'package:bitly/utils/logger.dart';

final _log = AppLogger('StatsCard');

int _levelForXp(int xp) {
  if (xp >= 10000) return 10;
  if (xp >= 5000) return 9;
  if (xp >= 2500) return 8;
  if (xp >= 1000) return 7;
  if (xp >= 500) return 6;
  if (xp >= 250) return 5;
  if (xp >= 100) return 4;
  if (xp >= 50) return 3;
  if (xp >= 10) return 2;
  return 1;
}

int _xpForLevel(int level) {
  const thresholds = [0, 1, 10, 50, 100, 250, 500, 1000, 2500, 5000, 10000];
  if (level >= thresholds.length) return thresholds.last;
  return thresholds[level - 1];
}

int _nextLevelXp(int level) => _xpForLevel(level + 1);

String _levelEmoji(int level) {
  const emojis = [
    '🎧', '📀', '💿', '🌟', '🔥',
    '🚀', '💫', '🌈', '⭐', '🏆',
  ];
  return emojis[(level - 1).clamp(0, emojis.length - 1)];
}

Color _levelColor(int level, ColorScheme cs) {
  if (level >= 10) return Colors.purple;
  if (level >= 7) return Colors.amber;
  if (level >= 4) return Colors.orange;
  return cs.onSurfaceVariant;
}

class StatsCard extends ConsumerWidget {
  const StatsCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final statsAsync = ref.watch(achievementProgressProvider);
    final unlockedAsync = ref.watch(unlockedSecretsProvider);
    final topArtistAsync = ref.watch(topArtistsProvider);
    final downloadCount = ref.watch(
      downloadQueueProvider.select((s) => s.completedCount),
    );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: statsAsync.when(
        data: (stats) {
          final unlocked = unlockedAsync.asData?.value ?? <String>{};
          return _buildContent(
            context, colorScheme, stats, topArtistAsync, downloadCount, unlocked,
          );
        },
        loading: () => const SizedBox(
          height: 100,
          child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
        ),
        error: (e, _) {
          _log.w('Stats error: $e');
          return const SizedBox.shrink();
        },
      ),
    );
  }

  Widget _buildContent(
    BuildContext context,
    ColorScheme colorScheme,
    Map<String, int> stats,
    AsyncValue<List<Map<String, dynamic>>> topArtistAsync,
    int downloadCount,
    Set<String> unlockedSecrets,
  ) {
    final totalPlays = stats['totalPlays'] ?? 0;
    final uniqueTracks = stats['uniqueTracks'] ?? 0;
    final uniqueAlbums = stats['uniqueAlbums'] ?? 0;
    final uniqueArtists = stats['uniqueArtists'] ?? 0;
    final maxTrackPlays = stats['maxTrackPlays'] ?? 0;
    final totalDays = stats['totalDays'] ?? 0;
    final level = _levelForXp(totalPlays);
    final nextXp = _nextLevelXp(level);
    final currentLevelXp = _xpForLevel(level);
    final progress = nextXp > currentLevelXp
        ? (totalPlays - currentLevelXp) / (nextXp - currentLevelXp)
        : 1.0;

    String? topArtistName;
    int? topArtistPlays;
    final topArtistData = topArtistAsync.asData?.value;
    if (topArtistData != null && topArtistData.isNotEmpty) {
      final entry = topArtistData.first;
      topArtistName = entry['artist_name'] as String?;
      topArtistPlays = entry['play_count'] as int?;
    }

    final achievements = _calculateAchievements(
      totalPlays, uniqueTracks, uniqueAlbums, uniqueArtists,
      maxTrackPlays, totalDays, downloadCount, unlockedSecrets,
    );

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withAlpha(80),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (totalPlays == 0) ...[
            Row(
              children: [
                Text('🎧', style: TextStyle(fontSize: 20)),
                const SizedBox(width: 8),
                Text(
                  'Nivel 1',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: colorScheme.onSurface,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(Icons.info_outline, size: 14, color: colorScheme.onSurfaceVariant),
                const SizedBox(width: 6),
                Text(
                  'Reproduce tu primera canción para subir de nivel',
                  style: TextStyle(fontSize: 13, color: colorScheme.onSurfaceVariant),
                ),
              ],
            ),
          ] else ...[
            // Level header
            Row(
              children: [
                Text(_levelEmoji(level), style: TextStyle(fontSize: 24)),
                const SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Nivel $level',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: _levelColor(level, colorScheme),
                      ),
                    ),
                    if (level < 10)
                      Text(
                        '$totalPlays XP · ${_formatNumber(totalPlays)} reproducciones',
                        style: TextStyle(fontSize: 11, color: colorScheme.onSurfaceVariant),
                      )
                    else
                      Text(
                        '🏆 Leyenda · ${_formatNumber(totalPlays)} reproducciones',
                        style: TextStyle(fontSize: 11, color: Colors.purple[200]),
                      ),
                  ],
                ),
              ],
            ),
            // XP progress bar
            if (level < 10) ...[
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: progress.clamp(0.0, 1.0),
                  backgroundColor: colorScheme.surfaceContainerHighest,
                  valueColor: AlwaysStoppedAnimation(_levelColor(level, colorScheme)),
                  minHeight: 6,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${_formatNumber(totalPlays)} / ${_formatNumber(nextXp)} XP para nivel ${level + 1}',
                style: TextStyle(fontSize: 9, color: colorScheme.onSurfaceVariant),
              ),
            ],
            const SizedBox(height: 14),
            // Stats grid
            Row(
              children: [
                _StatBadge(emoji: '▶️', label: _formatNumber(totalPlays), sub: 'Reproducciones'),
                _StatBadge(emoji: '🎵', label: _formatNumber(uniqueTracks), sub: 'Canciones'),
                _StatBadge(emoji: '💿', label: _formatNumber(uniqueAlbums), sub: 'Álbumes'),
                _StatBadge(emoji: '🎤', label: _formatNumber(uniqueArtists), sub: 'Artistas'),
                _StatBadge(emoji: '⬇️', label: _formatNumber(downloadCount), sub: 'Descargas'),
              ],
            ),
            // Most played artist
            if (topArtistName != null) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: colorScheme.primary.withAlpha(20),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('🎧', style: TextStyle(fontSize: 16)),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        'Artista + escuchado: $topArtistName',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: colorScheme.onSurface),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (topArtistPlays != null) ...[
                      const SizedBox(width: 4),
                      Text(
                        '(${_formatNumber(topArtistPlays)})',
                        style: TextStyle(fontSize: 10, color: colorScheme.onSurfaceVariant),
                      ),
                    ],
                  ],
                ),
              ),
            ],
            // Achievements
            if (achievements.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                '🏅 Logros',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: achievements.map((a) => _AchievementChip(achievement: a)).toList(),
              ),
            ],
          ],
        ],
      ),
    );
  }

  String _formatNumber(int n) {
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}k';
    return n.toString();
  }

  List<_Achievement> _calculateAchievements(
    int totalPlays,
    int uniqueTracks,
    int uniqueAlbums,
    int uniqueArtists,
    int maxTrackPlays,
    int totalDays,
    int downloadCount,
    Set<String> unlockedSecrets,
  ) {
    final achievements = <_Achievement>[];

    if (totalPlays >= 1) achievements.add(_Achievement('Primera Escucha', '🎧'));
    if (totalPlays >= 10) achievements.add(_Achievement('10 Reproducciones', '💎'));
    if (totalPlays >= 50) achievements.add(_Achievement('50 Reproducciones', '🌟'));
    if (totalPlays >= 100) achievements.add(_Achievement('100 Reproducciones', '👑'));
    if (totalPlays >= 250) achievements.add(_Achievement('250 Reproducciones', '🔥'));
    if (totalPlays >= 500) achievements.add(_Achievement('500 Reproducciones', '🚀'));
    if (totalPlays >= 1000) achievements.add(_Achievement('1,000 Reproducciones', '💫'));
    if (totalPlays >= 2500) achievements.add(_Achievement('2,500 Reproducciones', '🌈'));
    if (totalPlays >= 5000) achievements.add(_Achievement('5,000 Reproducciones', '⭐'));
    if (totalPlays >= 10000) achievements.add(_Achievement('10,000 Reproducciones', '🏆'));

    if (uniqueAlbums >= 5) achievements.add(_Achievement('5 Álbumes', '📀'));
    if (uniqueAlbums >= 25) achievements.add(_Achievement('25 Álbumes', '💿'));
    if (uniqueAlbums >= 100) achievements.add(_Achievement('100 Álbumes', '🎵'));

    if (uniqueArtists >= 5) achievements.add(_Achievement('5 Artistas', '🎤'));
    if (uniqueArtists >= 25) achievements.add(_Achievement('25 Artistas', '🎸'));
    if (uniqueArtists >= 100) achievements.add(_Achievement('100 Artistas', '🎼'));

    if (uniqueTracks >= 10) achievements.add(_Achievement('10 Canciones', '📚'));
    if (uniqueTracks >= 50) achievements.add(_Achievement('50 Canciones', '📖'));
    if (uniqueTracks >= 200) achievements.add(_Achievement('200 Canciones', '📕'));

    if (maxTrackPlays >= 5) achievements.add(_Achievement('5× Misma Canción', '❤️'));
    if (maxTrackPlays >= 20) achievements.add(_Achievement('20× Misma Canción', '💕'));
    if (maxTrackPlays >= 100) achievements.add(_Achievement('100× Misma Canción', '💖'));

    if (totalDays >= 3) achievements.add(_Achievement('3 Días', '📅'));
    if (totalDays >= 15) achievements.add(_Achievement('15 Días', '📅'));
    if (totalDays >= 60) achievements.add(_Achievement('60 Días', '📅'));

    if (downloadCount >= 1) achievements.add(_Achievement('1 Descarga', '⬇️'));
    if (downloadCount >= 10) achievements.add(_Achievement('10 Descargas', '⬇️'));
    if (downloadCount >= 50) achievements.add(_Achievement('50 Descargas', '📦'));
    if (downloadCount >= 100) achievements.add(_Achievement('100 Descargas', '📦'));

    // Secret achievements (hidden until unlocked)
    if (unlockedSecrets.contains('night_owl')) achievements.add(_Achievement('Búho Nocturno', '🦉'));
    if (unlockedSecrets.contains('night_rider')) achievements.add(_Achievement('Jinete Nocturno', '🌙'));
    if (unlockedSecrets.contains('album_marathon_5')) achievements.add(_Achievement('Maratón de Álbum (5)', '📀'));
    if (unlockedSecrets.contains('album_marathon_10')) achievements.add(_Achievement('Maratón de Álbum (10)', '💿'));

    return achievements;
  }
}

class _StatBadge extends StatelessWidget {
  final String emoji;
  final String label;
  final String sub;

  const _StatBadge({required this.emoji, required this.label, required this.sub});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Expanded(
      child: Column(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 16)),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: cs.onSurface),
          ),
          Text(
            sub,
            style: TextStyle(fontSize: 8, color: cs.onSurfaceVariant),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

class _Achievement {
  final String name;
  final String emoji;

  const _Achievement(this.name, this.emoji);
}

class _AchievementChip extends StatelessWidget {
  final _Achievement achievement;

  const _AchievementChip({required this.achievement});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: cs.primary.withAlpha(20),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cs.primary.withAlpha(38)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(achievement.emoji, style: const TextStyle(fontSize: 12)),
          const SizedBox(width: 4),
          Text(
            achievement.name,
            style: TextStyle(fontSize: 10, fontWeight: FontWeight.w500, color: cs.onSurface),
          ),
        ],
      ),
    );
  }
}
