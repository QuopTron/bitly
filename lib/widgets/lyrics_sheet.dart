import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bitly/models/lyrics.dart';
import 'package:bitly/providers/audio_player_provider.dart';
import 'package:bitly/providers/lyrics_provider.dart';
import 'package:bitly/services/biblioteca/portadas/cover_cache_manager.dart';
import 'package:bitly/services/núcleo/platform_bridge.dart';

class LyricsSheet extends ConsumerStatefulWidget {
  const LyricsSheet({super.key});

  @override
  ConsumerState<LyricsSheet> createState() => _LyricsSheetState();
}

class _LyricsSheetState extends ConsumerState<LyricsSheet> {
  Timer? _positionTimer;
  int? _currentLineIndex;
  double _currentLineProgress = 0.0;
  final _scrollController = ScrollController();
  double? _viewportHeight;
  bool _showTranslation = false;

  static const double _lineHeight = 56.0;
  static const double _lineHeightWithTranslation = 80.0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final lyricsState = ref.read(lyricsProvider);
      final playerState = ref.read(audioPlayerProvider);
      
      // Solo buscar si NO está cargada, NO está cargando Y NO está lista en audioPlayer
      if (lyricsState.response == null && 
          !lyricsState.isLoading && 
          !playerState.isLyricsReady) {
        ref.read(lyricsProvider.notifier).fetchForTrack(
          trackId: playerState.trackId ?? '',
          trackName: playerState.trackName ?? '',
          artistName: playerState.artistName ?? '',
          durationMs: playerState.duration.inMilliseconds,
        );
      }
      
      if (lyricsState.response != null && lyricsState.response!.isSynced) {
        _startPositionTracking();
      }
    });
  }

  @override
  void dispose() {
    _positionTimer?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  void _startPositionTracking() {
    _positionTimer?.cancel();
    _positionTimer = Timer.periodic(const Duration(milliseconds: 50), (_) {
      if (!mounted) return;
      final lyricsState = ref.read(lyricsProvider);
      final lines = lyricsState.response?.lines ?? [];
      if (lines.isEmpty) return;

      final pos = ref.read(audioPlayerProvider).position.inMilliseconds;

      var idx = -1;
      for (var i = 0; i < lines.length; i++) {
        if (pos >= lines[i].startTimeMs && pos < lines[i].endTimeMs) {
          idx = i;
          break;
        }
      }
      if (idx == -1 && lines.isNotEmpty && pos >= lines.last.endTimeMs) {
        idx = lines.length - 1;
      }

      double progress = 0.0;
      if (idx >= 0 && idx < lines.length) {
        final line = lines[idx];
        final lineDuration = line.endTimeMs - line.startTimeMs;
        if (lineDuration > 0) {
          progress = ((pos - line.startTimeMs) / lineDuration).clamp(0.0, 1.0);
        }
      }

      if (idx != _currentLineIndex || progress != _currentLineProgress) {
        setState(() {
          _currentLineIndex = idx;
          _currentLineProgress = progress;
        });
        if (idx >= 0) _centerLine(idx);
      }
    });
  }

  void _centerLine(int index) {
    if (!_scrollController.hasClients || _viewportHeight == null) return;
    final itemH = _showTranslation ? _lineHeightWithTranslation : _lineHeight;
    final offset = index * itemH - (_viewportHeight! / 2 - itemH / 2);
    if (offset != _scrollController.offset) {
      _scrollController.animateTo(
        offset.clamp(0.0, _scrollController.position.maxScrollExtent),
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeOutCubic,
      );
    }
  }

  static const _supportedLanguages = {
    'es': 'Español',
    'en': 'English',
    'fr': 'Français',
    'de': 'Deutsch',
    'it': 'Italiano',
    'pt': 'Português',
    'ja': '日本語',
    'ko': '한국어',
    'zh': '中文',
    'ar': 'العربية',
    'ru': 'Русский',
    'hi': 'हिन्दी',
    'tl': 'Filipino',
    'vi': 'Tiếng Việt',
    'th': 'ไทย',
    'id': 'Bahasa Indonesia',
  };

  Future<void> _doTranslate(String language) async {
    if (!mounted) return;
    final lyricsState = ref.read(lyricsProvider);
    if (lyricsState.translation == null && !lyricsState.isTranslating) {
      await PlatformBridge.setTranslationLanguage(language);
      ref.read(lyricsProvider.notifier).fetchTranslation(language: language);
    }
  }

  Future<void> _ensureLanguageAndTranslate() async {
    final saved = await PlatformBridge.getTranslationLanguage();
    if (saved.isNotEmpty && _supportedLanguages.containsKey(saved)) {
      await _doTranslate(saved);
      return;
    }
    if (!mounted) return;
    final selected = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _LanguagePickerSheet(languages: _supportedLanguages),
    );
    if (selected != null && mounted) {
      await _doTranslate(selected);
    }
  }

  void _toggleTranslation() {
    if (_showTranslation) {
      setState(() => _showTranslation = false);
      return;
    }
    setState(() => _showTranslation = true);
    final lyricsState = ref.read(lyricsProvider);
    if (lyricsState.translation == null && !lyricsState.isTranslating) {
      _ensureLanguageAndTranslate();
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final playerState = ref.watch(audioPlayerProvider);
    final lyricsState = ref.watch(lyricsProvider);
    final lines = lyricsState.response?.lines ?? [];

    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      decoration: BoxDecoration(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      clipBehavior: Clip.hardEdge,
      child: Stack(
        children: [
          _buildGlassBackground(playerState.coverUrl, colorScheme),
          Column(
            children: [
              _buildDragHandle(colorScheme),
              _buildHeader(colorScheme, playerState, lyricsState),
              Expanded(
                child: _buildBody(colorScheme, lines, lyricsState),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildGlassBackground(String? coverUrl, ColorScheme colorScheme) {
    Widget? coverWidget;
    if (coverUrl != null && coverUrl.isNotEmpty) {
      if (coverUrl.startsWith('http://') || coverUrl.startsWith('https://')) {
        coverWidget = CachedNetworkImage(
          imageUrl: coverUrl,
          fit: BoxFit.cover,
          memCacheWidth: 300,
          cacheManager: CoverCacheManager.instance,
          errorWidget: (_, _, _) => const SizedBox.shrink(),
        );
      } else {
        final localPath = coverUrl.startsWith('file://') ? coverUrl.substring(7) : coverUrl;
        coverWidget = Image.file(File(localPath), fit: BoxFit.cover,
          errorBuilder: (_, _, _) => const SizedBox.shrink(),
        );
      }
    }

    return Stack(
      children: [
        if (coverWidget != null)
          Positioned.fill(child: coverWidget),
        Positioned.fill(
          child: ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            child: BackdropFilter(
              filter: ui.ImageFilter.blur(sigmaX: 40, sigmaY: 40),
              child: Container(color: Colors.transparent),
            ),
          ),
        ),
        Positioned.fill(
          child: Container(color: colorScheme.surface.withValues(alpha: 0.80)),
        ),
        Positioned.fill(
          child: Container(
            decoration: BoxDecoration(
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.06),
                width: 0.5,
              ),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDragHandle(ColorScheme colorScheme) {
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Center(
        child: Container(
          width: 36, height: 4,
          decoration: BoxDecoration(
            color: colorScheme.onSurfaceVariant.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(ColorScheme colorScheme, AudioPlayerState playerState, LyricsState lyricsState) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.25),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.06),
          width: 0.5,
        ),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Container(
              width: 44, height: 44,
              color: colorScheme.primaryContainer,
              child: playerState.coverUrl != null
                  ? (playerState.coverUrl!.startsWith('http')
                      ? CachedNetworkImage(
                          imageUrl: playerState.coverUrl!,
                          fit: BoxFit.cover,
                          cacheManager: CoverCacheManager.instance,
                          errorWidget: (_, _, _) => Icon(Icons.music_note, size: 20, color: colorScheme.onPrimaryContainer),
                        )
                      : Image.file(
                          File(playerState.coverUrl!.startsWith('file://') ? playerState.coverUrl!.substring(7) : playerState.coverUrl!),
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => Icon(Icons.music_note, size: 20, color: colorScheme.onPrimaryContainer),
                        ))
                  : Icon(Icons.music_note, size: 20, color: colorScheme.onPrimaryContainer),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  playerState.trackName ?? '',
                  style: TextStyle(
                    fontSize: 15, fontWeight: FontWeight.bold,
                    color: colorScheme.onSurface,
                  ),
                  maxLines: 1, overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  playerState.artistName ?? '',
                  style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant),
                  maxLines: 1, overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          _buildSourceBadge(lyricsState, colorScheme),
          const SizedBox(width: 4),
          _buildTranslationButton(lyricsState, colorScheme),
        ],
      ),
    );
  }

  Widget _buildSourceBadge(LyricsState lyricsState, ColorScheme colorScheme) {
    if (lyricsState.response == null) return const SizedBox.shrink();
    final label = lyricsState.response!.source.isNotEmpty
        ? lyricsState.response!.source.toUpperCase()
        : lyricsState.response!.isSynced ? 'SYNC' : 'LYRICS';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: colorScheme.tertiaryContainer.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 9, fontWeight: FontWeight.w700,
          color: colorScheme.onTertiaryContainer,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildTranslationButton(LyricsState lyricsState, ColorScheme colorScheme) {
    if (lyricsState.response?.isSynced != true) return const SizedBox.shrink();

    if (lyricsState.translation != null) {
      return GestureDetector(
        onTap: _toggleTranslation,
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: _showTranslation
                ? colorScheme.primary.withValues(alpha: 0.2)
                : colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: _showTranslation
                  ? colorScheme.primary.withValues(alpha: 0.3)
                  : Colors.transparent,
              width: 0.5,
            ),
          ),
          child: Text(
            _showTranslation ? 'ES' : 'EN',
            style: TextStyle(
              fontSize: 11, fontWeight: FontWeight.w700,
              color: _showTranslation ? colorScheme.primary : colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      );
    }

    if (lyricsState.isTranslating) {
      return SizedBox(
        width: 20, height: 20,
        child: CircularProgressIndicator(strokeWidth: 2, color: colorScheme.primary),
      );
    }

    return GestureDetector(
      onTap: _toggleTranslation,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: colorScheme.primary.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(Icons.translate, size: 16, color: colorScheme.primary),
      ),
    );
  }

  Widget _buildBody(ColorScheme colorScheme, List<LyricsLine> lines, LyricsState lyricsState) {
    if (lyricsState.isLoading) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 28, height: 28,
              child: CircularProgressIndicator(strokeWidth: 3, color: colorScheme.primary),
            ),
            const SizedBox(height: 12),
            Text('Cargando letras...',
                style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 13)),
          ],
        ),
      );
    }

    if (lyricsState.error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 40, color: colorScheme.error.withValues(alpha: 0.7)),
            const SizedBox(height: 8),
            Text('No se pudieron cargar las letras',
                style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 13)),
            const SizedBox(height: 16),
            TextButton(
              onPressed: () {
                final p = ref.read(audioPlayerProvider);
                final lyricsNotifier = ref.read(lyricsProvider.notifier);
                Future(() {
                  lyricsNotifier.fetchForTrack(
                    trackId: p.trackId ?? '',
                    trackName: p.trackName ?? '',
                    artistName: p.artistName ?? '',
                    durationMs: p.duration.inMilliseconds,
                  );
                });
              },
              child: const Text('Reintentar'),
            ),
          ],
        ),
      );
    }

    if (lines.isEmpty && !lyricsState.isLoading) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.lyrics_outlined, size: 48, color: colorScheme.onSurfaceVariant.withValues(alpha: 0.3)),
            const SizedBox(height: 8),
            Text('Sin letras disponibles',
                style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 13)),
          ],
        ),
      );
    }

    final isSynced = lyricsState.response?.isSynced ?? false;
    final translationLines = _showTranslation ? lyricsState.translation?.lines ?? [] : null;

    if (!isSynced) {
      return SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        child: SelectableText(
          lines.map((l) => l.words).join('\n'),
          style: TextStyle(fontSize: 15, height: 1.7, color: colorScheme.onSurface),
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        if (_viewportHeight == null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) setState(() => _viewportHeight = constraints.maxHeight);
          });
        }
        return ListView.builder(
          controller: _scrollController,
          padding: const EdgeInsets.symmetric(vertical: 8),
          itemExtent: _showTranslation ? _lineHeightWithTranslation : _lineHeight,
          itemCount: lines.length,
          itemBuilder: (context, index) {
            final line = lines[index];
            final isCurrent = index == _currentLineIndex;
            final isPast = _currentLineIndex != null && index < _currentLineIndex!;

            return _buildLyricsItem(
              line: line,
              index: index,
              isCurrent: isCurrent,
              isPast: isPast,
              progress: isCurrent ? _currentLineProgress : (isPast ? 1.0 : 0.0),
              colorScheme: colorScheme,
              translation: translationLines != null && index < translationLines.length
                  ? translationLines[index].words
                  : null,
            );
          },
        );
      },
    );
  }

  Widget _buildLyricsItem({
    required LyricsLine line,
    required int index,
    required bool isCurrent,
    required bool isPast,
    required double progress,
    required ColorScheme colorScheme,
    String? translation,
  }) {
    final baseFontSize = isCurrent ? 20.0 : 15.0;
    final baseFontWeight = isCurrent ? FontWeight.bold : FontWeight.normal;
    final baseColor = isPast
        ? colorScheme.onSurface.withValues(alpha: 0.30)
        : colorScheme.onSurface.withValues(alpha: 0.60);

    if (isCurrent) {
      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
        decoration: BoxDecoration(
          color: colorScheme.primary.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: colorScheme.primary.withValues(alpha: 0.12),
            width: 0.5,
          ),
        ),
        child: Padding(
          padding: EdgeInsets.only(
            top: _showTranslation ? 8 : 12,
            left: 20,
            right: 20,
            bottom: _showTranslation ? 4 : 12,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (progress > 0)
                Expanded(
                  child: _buildKaraokeLine(line.words, progress, baseFontSize, baseFontWeight, colorScheme),
                )
              else
                Expanded(
                  child: Text(
                    line.words,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: baseFontSize,
                      fontWeight: baseFontWeight,
                      color: colorScheme.primary,
                    ),
                  ),
                ),
              if (translation != null)
                Expanded(
                  child: Text(
                    translation,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w400,
                      color: colorScheme.onSurface.withValues(alpha: 0.55),
                    ),
                  ),
                ),
            ],
          ),
        ),
      );
    }

    return Padding(
      padding: EdgeInsets.only(
        top: _showTranslation ? 8 : 12,
        left: 24,
        right: 24,
        bottom: _showTranslation ? 4 : 12,
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Expanded(
            child: Text(
              line.words,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: baseFontSize,
                fontWeight: baseFontWeight,
                color: baseColor,
              ),
            ),
          ),
          if (translation != null)
            Expanded(
              child: Text(
                translation,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w400,
                  color: colorScheme.onSurface.withValues(alpha: 0.50),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildKaraokeLine(String words, double progress, double fontSize, FontWeight fontWeight, ColorScheme colorScheme) {
    final filledColor = colorScheme.primary;
    final unfilledColor = colorScheme.onSurface.withValues(alpha: 0.65);

    return ShaderMask(
      blendMode: BlendMode.srcIn,
      shaderCallback: (bounds) {
        return LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [
            filledColor,
            filledColor,
            unfilledColor,
            unfilledColor,
          ],
          stops: [
            0.0,
            progress,
            (progress + 0.001).clamp(0.0, 1.0),
            1.0,
          ],
        ).createShader(bounds);
      },
      child: Text(
        words,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: fontSize,
          fontWeight: fontWeight,
          color: Colors.white,
        ),
      ),
    );
  }
}

class _LanguagePickerSheet extends StatelessWidget {
  final Map<String, String> languages;

  const _LanguagePickerSheet({required this.languages});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      height: MediaQuery.of(context).size.height * 0.5,
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 12),
          Container(
            width: 36, height: 4,
            decoration: BoxDecoration(
              color: colorScheme.onSurfaceVariant.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
            child: Text(
              'Selecciona idioma de traducción',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: colorScheme.onSurface),
            ),
          ),
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: languages.length,
              separatorBuilder: (_, __) => Divider(height: 1, color: colorScheme.outlineVariant.withValues(alpha: 0.3)),
              itemBuilder: (_, i) {
                final entry = languages.entries.elementAt(i);
                return ListTile(
                  leading: Text(
                    entry.key.toUpperCase(),
                    style: TextStyle(fontWeight: FontWeight.w700, color: colorScheme.primary, fontSize: 13),
                  ),
                  title: Text(entry.value, style: TextStyle(color: colorScheme.onSurface)),
                  trailing: const Icon(Icons.chevron_right, size: 20),
                  onTap: () => Navigator.pop(context, entry.key),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

void showLyricsSheet(BuildContext context) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    isDismissible: true,
    enableDrag: true,
    constraints: BoxConstraints(
      maxWidth: MediaQuery.of(context).size.width * 0.95, // 95% width for lyrics
    ),
    builder: (_) => const LyricsSheet(),
  );
}
