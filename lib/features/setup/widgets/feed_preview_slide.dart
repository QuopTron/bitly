import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';
import '../../../core/models/feed_models.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/helpers/responsive.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/glass_button.dart';
import '../../../shared/widgets/glass_container.dart';
import '../../../shared/widgets/track_card.dart';
import '../../../shared/widgets/grid_card.dart';
import '../../../shared/widgets/download_indicator.dart';
import '../../../shared/widgets/song_info_modal.dart';
import '../../../shared/widgets/add_to_modal.dart';
import '../bloc/setup_bloc.dart';
import '../bloc/setup_event.dart';
import '../bloc/setup_state.dart';

class FeedPreviewSlide extends StatefulWidget {
  final SetupState state;
  final AppLocalizations loc;
  final Responsive r;
  final bool isDark;

  const FeedPreviewSlide({
    super.key,
    required this.state,
    required this.loc,
    required this.r,
    required this.isDark,
  });

  @override
  State<FeedPreviewSlide> createState() => _FeedPreviewSlideState();
}

class _FeedPreviewSlideState extends State<FeedPreviewSlide> {
  List<FeedSection> _sections = [];
  String _selectedSource = '';
  bool _loading = true;

  final Set<String> _likedIds = {};
  final Map<String, DownloadState> _downloadStates = {};
  final Map<String, double> _downloadProgress = {};
  final Map<String, Timer> _downloadTimers = {};

  static const _sourceIcons = <String, IconData>{
    'deezer': Icons.library_music,
    'apple-music': Icons.apple,
    'soundcloud': Icons.cloud_queue,
    'spotify-web': Icons.music_note,
    'pandora': Icons.radio,
    'amazon': Icons.shopping_bag,
    'qobuz-web': Icons.album,
    'tidal-web': Icons.waves,
    'ytmusic-spotiflac': Icons.play_circle_fill,
  };

  Map<String, String> get _availableSources {
    final map = <String, String>{};
    for (final s in _sections) {
      if (!map.containsKey(s.source)) {
        map[s.source] = s.displayName.isNotEmpty ? s.displayName : _formatId(s.source);
      }
    }
    return map;
  }

  static String _formatId(String id) => id
    .replaceAll('-', ' ').split(' ').map((w) => w.isNotEmpty ? '${w[0].toUpperCase()}${w.substring(1)}' : '').join(' ');

  IconData _sourceIcon(String src) => _sourceIcons[src] ?? Icons.music_video;

  @override
  void initState() { super.initState(); _fetchFeed(); }

  String get _locale => GetIt.instance<ValueNotifier<Locale>>().value.languageCode;

  Future<void> _fetchFeed() async {
    if (!mounted) return;
    setState(() => _loading = true);
    try {
      final backend = context.read<SetupBloc>().backend;
      final sections = await backend.getHomeFeed(locale: _locale);
      if (!mounted) return;
      setState(() {
        _sections = sections;
        final avail = _availableSources;
        if (!avail.containsKey(_selectedSource) && avail.isNotEmpty) {
          _selectedSource = avail.keys.first;
        }
      });
    } catch (e) {
      if (!mounted) return;
      debugPrint('[feed_preview] getHomeFeed error: $e');
      setState(() => _sections = []);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<FeedSection> get _filteredSections =>
    _selectedSource.isEmpty ? _sections : _sections.where((s) => s.source == _selectedSource).toList();

  String get _currentDisplayName =>
    _availableSources[_selectedSource] ?? _formatId(_selectedSource);

  void _toggleLike(String id) {
    setState(() {
      if (_likedIds.contains(id)) {
        _likedIds.remove(id);
      } else {
        _likedIds.add(id);
      }
    });
  }

  void _startDownload(String id) {
    if (_downloadStates[id] == DownloadState.inProgress) return;
    setState(() {
      _downloadStates[id] = DownloadState.inProgress;
      _downloadProgress[id] = 0.0;
    });
    const totalSteps = 30;
    const interval = Duration(milliseconds: 100);
    var step = 0;
    _downloadTimers[id]?.cancel();
    _downloadTimers[id] = Timer.periodic(interval, (timer) {
      step++;
      final progress = (step / totalSteps).clamp(0.0, 1.0);
      if (!mounted) { timer.cancel(); return; }
      setState(() => _downloadProgress[id] = progress);
      if (step >= totalSteps) {
        timer.cancel();
        if (!mounted) return;
        setState(() => _downloadStates[id] = DownloadState.completed);
        Future.delayed(const Duration(seconds: 2), () {
          if (!mounted) return;
          setState(() {
            _downloadStates.remove(id);
            _downloadProgress.remove(id);
          });
        });
      }
    });
  }

  void _showInfo(BuildContext context, FeedItem item) => showSongInfoModal(context, item);
  void _showMore(BuildContext context, FeedItem item) => showAddToModal(context, item);

  @override
  void dispose() {
    for (final t in _downloadTimers.values) {
      t.cancel();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final onBg = widget.isDark ? Colors.white : Colors.black;
    final glowColor = widget.isDark ? AppColors.greenBright : AppColors.greenMedium;
    final saving = widget.state.saving;
    final nextOk = widget.state.selectedMode != null && !saving;
    return Padding(
      key: const ValueKey('feedPreview'),
      padding: EdgeInsets.only(bottom: widget.r.bottomPadding),
      child: Column(children: [
        SizedBox(height: widget.r.spacingM),
        _header(onBg),
        SizedBox(height: widget.r.spacingM),
        Expanded(
          child: GlassContainer(
            borderRadius: 16,
            borderColor: glowColor.withValues(alpha: 0.15),
            bgColor: onBg.withValues(alpha: 0.02),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              if (_availableSources.isNotEmpty)
                _sourceSelector(onBg, glowColor),
              Expanded(child: _feedContent(onBg, glowColor)),
            ]),
          ),
        ),
        SizedBox(height: widget.r.spacingM),
        _buttons(context, glowColor, nextOk, saving),
      ]),
    );
  }

  Widget _header(Color onBg) {
    return Column(mainAxisSize: MainAxisSize.min, children: [
      SizedBox(height: widget.r.spacingS),
      Container(
        padding: EdgeInsets.all(widget.r.spacingS),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: onBg.withValues(alpha: 0.04),
          border: Border.all(color: onBg.withValues(alpha: 0.08), width: 0.8),
        ),
        child: Icon(Icons.home_outlined, size: widget.r.titleSize * 1.1, color: onBg.withValues(alpha: 0.55)),
      ),
      SizedBox(height: widget.r.spacingS),
      Text(widget.loc.setup.feedTutorialTitle,
        style: TextStyle(fontSize: widget.r.titleSize, fontWeight: FontWeight.bold, color: onBg, letterSpacing: 1)),
      SizedBox(height: 2),
      Padding(
        padding: EdgeInsets.symmetric(horizontal: widget.r.spacingXL),
        child: Text(widget.loc.setup.feedTutorialDesc,
          style: TextStyle(fontSize: widget.r.footerSize, color: onBg.withValues(alpha: 0.5)),
          textAlign: TextAlign.center),
      ),
    ]);
  }

  Widget _sourceSelector(Color onBg, Color glowColor) {
    if (_availableSources.isEmpty) return const SizedBox.shrink();
    return GlassContainer(
      borderRadius: 10,
      borderColor: onBg.withValues(alpha: 0.08),
      margin: EdgeInsets.fromLTRB(widget.r.spacingS, widget.r.spacingS, widget.r.spacingS, 0),
      padding: EdgeInsets.symmetric(horizontal: widget.r.spacingM, vertical: widget.r.spacingXS),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.swap_horiz, size: widget.r.footerSize + 2, color: onBg.withValues(alpha: 0.4)),
          SizedBox(width: widget.r.spacingS),
          _dropdown(onBg, glowColor),
        ],
      ),
    );
  }

  Widget _dropdown(Color onBg, Color glowColor) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: widget.r.spacingS),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        color: onBg.withValues(alpha: 0.05),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _selectedSource,
          dropdownColor: isDark ? const Color(0xFF1A1A1A) : Colors.white,
          style: TextStyle(fontSize: widget.r.footerSize, color: onBg, fontWeight: FontWeight.w500),
          icon: Icon(Icons.keyboard_arrow_down, size: widget.r.footerSize + 4, color: onBg.withValues(alpha: 0.5)),
          items: _availableSources.entries.map((e) => DropdownMenuItem(
            value: e.key,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(_sourceIcon(e.key), size: widget.r.footerSize, color: glowColor.withValues(alpha: 0.7)),
                SizedBox(width: widget.r.spacingS),
                Text(e.value, style: TextStyle(color: onBg)),
              ],
            ),
          )).toList(),
          onChanged: (v) { if (v != null) setState(() => _selectedSource = v); },
        ),
      ),
    );
  }

  Widget _feedContent(Color onBg, Color glowColor) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    final sections = _filteredSections;
    final hasContent = sections.isNotEmpty && sections.any((s) => s.items.isNotEmpty);
    if (!hasContent) {
      return Center(
        child: Padding(
          padding: EdgeInsets.all(widget.r.spacingXL),
          child: Text(widget.loc.setup.feedEmpty,
            style: TextStyle(fontSize: widget.r.footerSize, color: onBg.withValues(alpha: 0.4))),
        ),
      );
    }
    return ListView(
      padding: EdgeInsets.all(widget.r.spacingS),
      children: [
        if (_currentDisplayName.isNotEmpty && sections.any((s) => s.items.isNotEmpty))
          Padding(
            padding: EdgeInsets.only(left: widget.r.spacingXS, bottom: widget.r.spacingS),
            child: Row(children: [
              Icon(Icons.wifi_tethering, size: widget.r.footerSize, color: glowColor.withValues(alpha: 0.6)),
              SizedBox(width: widget.r.spacingXS),
              Text(_currentDisplayName,
                style: TextStyle(fontSize: widget.r.footerSize, fontWeight: FontWeight.w600,
                  color: glowColor.withValues(alpha: 0.7))),
            ]),
          ),
        ..._buildTrackCards(onBg, glowColor),
        ..._buildGridCards(onBg, glowColor),
      ],
    );
  }

  List<Widget> _buildTrackCards(Color onBg, Color glowColor) {
    final ts = _filteredSections.where((s) => s.items.any((i) => i.type == 'track')).toList();
    final ws = <Widget>[];
    for (final section in ts) {
      final tracks = section.items.where((i) => i.type == 'track').take(10).toList();
      if (tracks.isEmpty) continue;
      if (section.title.isNotEmpty && ts.length > 1) {
        ws.add(Padding(
          padding: EdgeInsets.only(left: widget.r.spacingXS, top: widget.r.spacingXS, bottom: widget.r.spacingXS),
          child: Text(section.title,
            style: TextStyle(fontSize: widget.r.subtitleSize, fontWeight: FontWeight.w600, color: onBg))));
      }
      for (final item in tracks) {
        final id = 'track_${item.id}_${item.source}';
        ws.add(TrackCard(
          title: item.name, subtitle: item.artists ?? '', coverUrl: item.coverUrl,
          isLiked: _likedIds.contains(id), onLike: () => _toggleLike(id),
          downloadState: _downloadStates[id] ?? DownloadState.none,
          downloadProgress: _downloadProgress[id] ?? 0.0,
          onDownload: () => _startDownload(id),
          onInfo: () => _showInfo(context, item),
          onMore: () => _showMore(context, item),
        ));
      }
    }
    return ws;
  }

  List<Widget> _buildGridCards(Color onBg, Color glowColor) {
    return _filteredSections.where((s) => s.items.any((i) => i.type != 'track'))
      .map((s) => Padding(
        padding: EdgeInsets.only(bottom: widget.r.spacingM),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
          Padding(padding: EdgeInsets.only(left: widget.r.spacingXS, bottom: widget.r.spacingXS),
            child: Text(s.title,
              style: TextStyle(fontSize: widget.r.subtitleSize, fontWeight: FontWeight.w600, color: onBg))),
          LayoutBuilder(
            builder: (context, constraints) {
              final avail = constraints.maxWidth - 2 * widget.r.spacingS;
              final crossAxisCount = avail > 700 ? 4 : avail > 340 ? 3 : 2;
              final gap = widget.r.spacingXS;
              final cardWidth = (avail - (crossAxisCount - 1) * gap) / crossAxisCount;

              return Padding(
                padding: EdgeInsets.symmetric(horizontal: widget.r.spacingS),
                child: Wrap(
                  spacing: gap,
                  runSpacing: widget.r.spacingXS,
                  children: s.items.where((i) => i.type != 'track').map((i) {
                    final id = '${i.type}_${i.id}_${i.source}';
                    return SizedBox(
                      width: cardWidth,
                      child: GridCard(
                        type: i.type, title: i.name, subtitle: i.artists ?? '', coverUrl: i.coverUrl,
                        isLiked: _likedIds.contains(id), onLike: () => _toggleLike(id),
                        downloadState: _downloadStates[id] ?? DownloadState.none,
                        downloadProgress: _downloadProgress[id] ?? 0.0,
                        onDownload: () => _startDownload(id),
                        onMore: () => _showMore(context, i),
                      ),
                    );
                  }).toList()),
                );
            },
          ),
        ]),
      )).toList();
  }

  Widget _buttons(BuildContext context, Color glowColor, bool nextOk, bool saving) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: widget.r.spacingXL),
      child: SizedBox(
        height: widget.r.continueButtonHeight,
        child: Row(children: [
          Expanded(child: GlassButton(
            label: widget.loc.setup.back,
            onPressed: () => context.read<SetupBloc>().add(const PreviousSlide()),
            height: widget.r.continueButtonHeight, accent: glowColor)),
          SizedBox(width: widget.r.spacingM),
          Expanded(child: GlassButton(
            label: widget.loc.setup.continueText,
            onPressed: nextOk ? () => context.read<SetupBloc>().add(const NextSlide()) : null,
            isLoading: saving, height: widget.r.continueButtonHeight, accent: glowColor)),
        ]),
      ),
    );
  }
}
