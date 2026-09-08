part of 'settings_sheet_new.dart';

class _SettingsSheetState extends State<SettingsSheet>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  int? _selectedTab; // null = profile/stats view, 0..3 = specific tab

  /// Real account tier read from the local premium DB (free/premium/lifetime),
  /// so the header + advanced settings never claim "Premium" for free users.
  PremiumStatus? _premium;

  Future<void> _loadPremium() async {
    try {
      final status = await sl<PremiumCache>().getPremiumStatus();
      if (mounted) setState(() => _premium = status);
    } catch (_) {}
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _bubbleTabs.length, vsync: this)
      ..addListener(() {
        if (mounted) setState(() {});
      });
    _loadPremium();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final r = Responsive(context);
    // LIVE theme: read from Theme.of instead of the frozen widget.isDark so
    // toggling dark/light inside the modal updates the sheet instantly.
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final onBg = AppColors.onSurface(isDark);
    final glowColor = isDark ? AppColors.greenBright : AppColors.greenMedium;
    final bg = AppColors.surface(isDark);

    return BlocBuilder<QueueCubit, QueueState>(
      builder: (context, queue) {
        final hasTrack = queue.hasCurrent;
        return _SongTintedBackground(
          key: ValueKey('settings-bg'),
          queue: queue,
          isDark: isDark,
          defaultBg: bg,
          child: _SettingsSheetBody(
            tabController: _tabController,
            selectedTab: _selectedTab,
            premium: _premium,
            username: widget.username,
            likedCount: widget.likedCount,
            downloadedCount: widget.downloadedCount,
            isDark: isDark,
            glowColor: glowColor,
            onBg: onBg,
            bg: bg,
            r: r,
            hasTrack: hasTrack,
            onThemeChanged: widget.onThemeChanged,
            onLanguageChanged: widget.onLanguageChanged,
            onPremiumChanged: _loadPremium,
            onTabTap: (i) {
              setState(() {
                if (_selectedTab == i) {
                  _selectedTab = null; // tap again -> back to profile
                } else {
                  _selectedTab = i;
                  _tabController.animateTo(i);
                }
              });
            },
          ),
        );
      },
    );
  }
}
