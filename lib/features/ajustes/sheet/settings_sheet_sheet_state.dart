// ─────────────────────────────────────────────────────────────
// settings_sheet_sheet_state.dart — PART de settings_sheet_new.dart: estado del SettingsSheet —
// TabController, pestaña activa, premium y seguimiento del tutorial.
// Se conecta con: settings_sheet_new.dart (misma library) + tutorial.
// Parte del flujo: Ajustes (estado de la hoja).
// ─────────────────────────────────────────────────────────────

part of 'settings_sheet_new.dart';

class _SettingsSheetState extends State<SettingsSheet>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  int? _selectedTab; // null = profile/stats view, 0..3 = specific tab

  /// Real account tier read from the local premium DB (free/premium/lifetime),
  /// so the header + advanced settings never claim "Premium" for free users.
  EstadoPremium? _premium;

  Future<void> _loadPremium() async {
    try {
      final status = await sl<CachePremium>().getEstadoPremium();
      if (mounted) setState(() => _premium = status);
    } catch (e) { debugPrint("[Feature] $e"); }
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _bubbleTabs.length, vsync: this)
      ..addListener(() {
        if (mounted) setState(() {});
      });
    _loadPremium();
    // Si el tutorial abrió la hoja, la hoja lo sigue: cada paso pide una
    // pestaña y acá se cambia sola, para que el usuario vea dónde está
    // cada cosa en vez de tener que buscarla.
    widget.tutorial?.addListener(_seguirTutorial);
    _seguirTutorial();
  }

  @override
  void dispose() {
    widget.tutorial?.removeListener(_seguirTutorial);
    _tabController.dispose();
    super.dispose();
  }

  /// Se para en la pestaña que pide el paso actual del tutorial.
  void _seguirTutorial() {
    final pedida = widget.tutorial?.pestanaAjustesActual;
    if (!mounted || pedida == null || pedida == _selectedTab) return;
    if (pedida < 0 || pedida >= _bubbleTabs.length) return;
    setState(() {
      _selectedTab = pedida;
      _tabController.animateTo(pedida);
    });
  }

  @override
  Widget build(BuildContext context) {
    final r = Responsive(context);
    // LIVE theme: read from Theme.of instead of the frozen widget.isDark so
    // toggling dark/light inside the modal updates the sheet instantly.
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final onBg = ColoresApp.enSuperficie(isDark);
    final glowColor =
        isDark ? ColoresApp.verdeBrillante : ColoresApp.verdeMedio;
    final bg = ColoresApp.superficie(isDark);

    return BlocBuilder<CubitCola, EstadoCola>(
      builder: (context, queue) {
        final hasTrack = queue.tieneActual;
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
            onStyleChanged: (estilo) {
              EstiloHelper.cambiar(context, estilo);
              if (mounted) setState(() {});
            },
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
