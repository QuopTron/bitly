import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../shared/models/feed_models.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/utils/responsive.dart';
import '../../../shared/theme/app_colors.dart';
import '../../../shared/constants/source_constants.dart';
import '../../../shared/widgets/glass_button.dart';import '../../../shared/widgets/glass_container.dart';
import 'feed_preview_header.dart';
import 'feed_preview_source_selector.dart';
import 'feed_preview_content.dart';
import '../../../../backend/rpc/backend_service.dart';
import '../../../../injection.dart';
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

  Map<String, String> get _availableSources {
    // Bubbles come ONLY from the sources the backend home feed actually
    // returned (has content). Removes duplicates and hides webjs sources
    // without getHomeFeed that would otherwise show an empty feed.
    final map = <String, String>{};
    for (final s in _sections) {
      final key = s.source;
      if (key.isEmpty || map.containsKey(key)) continue;
      map[key] = sourceDisplayName(key);
    }
    return map;
  }

  IconData _sourceIcon(String src) => sourceIcons[src] ?? Icons.music_video;

  @override
  void initState() {
    super.initState();
    _fetchFeed();
  }

  Future<void> _fetchFeed() async {
    if (!mounted) return;
    setState(() => _loading = true);
    try {
      final backend = sl<BackendService>();
      final sections = await backend.getHomeFeed();
      if (!mounted) return;
      setState(() { _sections = sections; _loading = false; });
      final avail = _availableSources;
      if (!avail.containsKey(_selectedSource) && avail.isNotEmpty) {
        _selectedSource = avail.keys.first;
      }
    } catch (_) {
      if (!mounted) return;
      setState(() { _sections = []; _loading = false; });
    }
  }

  String get _currentDisplayName => _availableSources[_selectedSource] ?? sourceDisplayName(_selectedSource);

  void _toggleLike(String id) {
    // No-op: preview only, no real action
  }

  void _startDownload(String id) {
    // No-op: preview only, no real action
  }

  void _showInfo(BuildContext context, FeedItem item) {
    // No-op: preview only, no real action
  }

  void _showMore(BuildContext context, FeedItem item) {
    // No-op: preview only, no real action
  }

  @override
  Widget build(BuildContext context) {
    final onBg = widget.isDark ? Colors.white : Colors.black;
    final glowColor = widget.isDark ? AppColors.greenBright : AppColors.greenMedium;
    final saving = widget.state.saving;
    final nextOk = widget.state.selectedMode != null && !saving;
    final r = widget.r;

    return Padding(
      key: const ValueKey('feedPreview'),
      padding: EdgeInsets.only(bottom: r.bottomPadding),
      child: Column(children: [
        SizedBox(height: r.spacingM),
        FeedPreviewHeader(onBg: onBg,
          title: widget.loc.setup.feedTutorialTitle, description: widget.loc.setup.feedTutorialDesc),
        SizedBox(height: r.spacingM),
        Expanded(
          child: GlassContainer(
            borderRadius: 16, borderColor: glowColor.withValues(alpha: 0.15),
            bgColor: onBg.withValues(alpha: 0.02),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              if (_availableSources.isNotEmpty)
                FeedPreviewSourceSelector(
                  selectedSource: _selectedSource,
                  availableSources: _availableSources,
                  sourceIcon: _sourceIcon,
                  onChanged: (v) => setState(() => _selectedSource = v),
                  onBg: onBg, glowColor: glowColor,
                ),
              Expanded(child: FeedPreviewContent(
                sections: _sections, loading: _loading,
                selectedSource: _selectedSource,
                currentDisplayName: _currentDisplayName,
                likedIds: const {},
                downloadStates: const {},
                onToggleLike: _toggleLike,
                onDownload: _startDownload,
                onShowInfo: _showInfo,
                onShowMore: _showMore,
                onBg: onBg, glowColor: glowColor,
                emptyLabel: widget.loc.setup.feedEmpty,
              )),
            ]),
          ),
        ),
        SizedBox(height: r.spacingM),
        _buttons(context, glowColor, nextOk, saving),
      ]),
    );
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

