// ─────────────────────────────────────────────────────────────
// settings_sheet_sheet_state.dart — PART de settings_sheet_new.dart: estado del SettingsSheet —
// TabController, pestaña activa, premium y seguimiento del tutorial.
// Se conecta con: settings_sheet_new.dart (misma library) + tutorial.
// Parte del flujo: Ajustes (estado de la hoja).
// ─────────────────────────────────────────────────────────────

part of '../../settings_sheet_new.dart';

class _SettingsSheetState extends State<SettingsSheet>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  /// Pestaña activa. Arranca en la PRIMERA burbuja (Apariencia): el usuario
  /// abre Ajustes para tocar algo, no para mirar un tablero de estadísticas.
  /// null = vista de perfil/estadísticas (a la que se llega destildando una
  /// burbuja, no al abrir).
  int? _selectedTab = 0;

  /// Real account tier read from the local premium DB (free/premium/lifetime),
  /// so the header + advanced settings never claim "Premium" for free users.
  EstadoPremium? _premium;

  Future<void> _loadPremium() async {
    try {
      final status = await sl<CachePremium>().getEstadoPremium();
      if (mounted) setState(() => _premium = status);
    } catch (e) {
      debugPrint("[Feature] $e");
    }
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: cantidadPestanasAjustes,
      vsync: this,
      initialIndex: _selectedTab ?? 0,
    )..addListener(() {
      if (mounted) setState(() {});
    });
    _loadPremium();
    // Cuenta los regalos del cofre de diseños una vez al abrir: así el
    // mininumerito de la burbuja de Apariencia ya sale con el número real.
    AparienciaHelper.refrescarRegalos();
    _refrescarNovedadesConexion();
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

  /// Cuenta las novedades de Conexión al abrir la hoja: el mininumerito de
  /// esa burbuja tiene que salir con el número real, antes de que el usuario
  /// entre a la pestaña. Es best-effort: si falla, deja el número como está.
  Future<void> _refrescarNovedadesConexion() async {
    try {
      final servicio = sl<ServicioConexion>();
      if (!servicio.cargado) await servicio.cargar();
      if (!mounted) return;
      novedadesConexion.value = servicio.novedadesNuevas;
    } catch (e) {
      debugPrint('[Conexion] no se pudo contar las novedades: $e');
    }
  }

  /// Se para en la pestaña que pide el paso actual del tutorial.
  void _seguirTutorial() {
    final pedida = widget.tutorial?.pestanaAjustesActual;
    if (!mounted || pedida == null || pedida == _selectedTab) return;
    if (pedida < 0 || pedida >= cantidadPestanasAjustes) return;
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
