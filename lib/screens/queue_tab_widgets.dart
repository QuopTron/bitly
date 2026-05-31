part of 'queue_tab.dart';

class _QueueItemSliverRow extends ConsumerWidget {
  final String itemId;
  final ColorScheme colorScheme;
  final Widget Function(BuildContext, DownloadItem, ColorScheme) itemBuilder;

  const _QueueItemSliverRow({
    required this.itemId,
    required this.colorScheme,
    required this.itemBuilder,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final item = ref.watch(
      downloadQueueLookupProvider.select((lookup) => lookup.byItemId[itemId]),
    );
    if (item == null) {
      return const SizedBox.shrink();
    }

    return RepaintBoundary(child: itemBuilder(context, item, colorScheme));
  }
}

enum _MixedItemType { song, album, playlist, artist }

class _MixedLibraryItem {
  final String key;
  final DateTime addedAt;
  final _MixedItemType type;
  final Widget widget;

  const _MixedLibraryItem({
    required this.key,
    required this.addedAt,
    required this.type,
    required this.widget,
  });
}

class _SelectionActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onPressed;
  final ColorScheme colorScheme;

  const _SelectionActionButton({
    required this.icon,
    required this.label,
    required this.onPressed,
    required this.colorScheme,
  });

  @override
  Widget build(BuildContext context) {
    final isDisabled = onPressed == null;
    return Material(
      color: isDisabled
          ? colorScheme.surfaceContainerHighest.withValues(alpha: 0.5)
          : colorScheme.secondaryContainer,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 18,
                color: isDisabled
                    ? colorScheme.onSurfaceVariant.withValues(alpha: 0.5)
                    : colorScheme.onSecondaryContainer,
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: isDisabled
                        ? colorScheme.onSurfaceVariant.withValues(alpha: 0.5)
                        : colorScheme.onSecondaryContainer,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AnimatedOverlayBottomBar extends StatefulWidget {
  final Widget child;

  const _AnimatedOverlayBottomBar({required this.child});

  @override
  State<_AnimatedOverlayBottomBar> createState() =>
      _AnimatedOverlayBottomBarState();
}

class _AnimatedOverlayBottomBarState extends State<_AnimatedOverlayBottomBar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<Offset> _slideAnimation;
  late final Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 240),
    );
    final curve = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.08),
      end: Offset.zero,
    ).animate(curve);
    _fadeAnimation = Tween<double>(begin: 0, end: 1).animate(curve);
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: SlideTransition(position: _slideAnimation, child: widget.child),
    );
  }
}

class _CyclingArtistCard extends ConsumerStatefulWidget {
  final CollectionArtistEntry entry;

  const _CyclingArtistCard({required this.entry});

  @override
  _CyclingArtistCardState createState() => _CyclingArtistCardState();
}

class _CyclingArtistCardState extends ConsumerState<_CyclingArtistCard> {
  int _coverIndex = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  @override
  void didUpdateWidget(_CyclingArtistCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.entry.key != widget.entry.key || 
        oldWidget.entry.allCovers.length != widget.entry.allCovers.length) {
      _coverIndex = 0;
      _timer?.cancel();
      _startTimer();
    }
  }

  void _startTimer() {
    final coverCount = widget.entry.allCovers.length;
    if (coverCount <= 1) return;
    _timer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (mounted) {
        setState(() {
          _coverIndex = (_coverIndex + 1) % coverCount;
        });
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final coverUrlForTap = widget.entry.allCovers.isNotEmpty
        ? widget.entry.allCovers[_coverIndex % widget.entry.allCovers.length]
        : null;

    return ArtistCard(
      artistName: widget.entry.name,
      imageUrl: widget.entry.imageUrl,
      coverPath: widget.entry.coverPath,
      alternateCovers: widget.entry.alternateCovers,
      coverIndex: _coverIndex,
      isFavorite: true,
      onTap: () {
        final state = context.findAncestorStateOfType<_QueueTabState>();
        state?._navigateWithUnfocus(
          MaterialPageRoute(
            builder: (_) => ArtistScreen(
              artistId: 'builtin:${widget.entry.name.hashCode.abs()}',
              artistName: widget.entry.name,
              coverUrl: coverUrlForTap,
            ),
          ),
        );
      },
    );
  }
}

