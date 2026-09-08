part of 'settings_sheet_new.dart';

class _MoreTab extends StatefulWidget {
  final Color glowColor;
  final PremiumStatus? premium;
  final Future<void> Function() onPremiumChanged;
  const _MoreTab({
    required this.glowColor,
    this.premium,
    required this.onPremiumChanged,
  });
  @override
  State<_MoreTab> createState() => _MoreTabState();
}

class _MoreTabState extends State<_MoreTab> {
  String? _trialRemaining;

  @override
  void initState() {
    super.initState();
    _loadTrialRemaining();
  }

  Future<void> _loadTrialRemaining() async {
    try {
      final setup = await sl<SettingsCache>().loadSetupData();
      if (setup != null &&
          setup.mode == 'free' &&
          setup.trialExpiresAt != null) {
        final expires = DateTime.tryParse(setup.trialExpiresAt!);
        if (expires != null) {
          final diff = expires.difference(DateTime.now());
          if (diff.isNegative) {
            if (mounted) setState(() => _trialRemaining = 'EXPIRADO');
          } else {
            final h = diff.inHours;
            final m = (diff.inMinutes % 60);
            if (mounted)
              setState(() => _trialRemaining = '${h}h ${m}m restantes');
          }
        }
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final r = Responsive(context);

    return SingleChildScrollView(
      padding: EdgeInsets.all(r.spacingL),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(height: r.spacingS),
          // Premium status + activation
          _PremiumCardWidget(
            glowColor: widget.glowColor,
            premium: widget.premium,
            trialRemaining: _trialRemaining,
            onPremiumChanged: widget.onPremiumChanged,
          ),
          SizedBox(height: r.spacingM),
          // Google connection
          _GoogleConnectionCard(glowColor: widget.glowColor),
          SizedBox(height: r.spacingM),
          // Report a bug / suggestion
          _ReportCardWidget(glowColor: widget.glowColor),
          SizedBox(height: r.spacingM),
          // Streaming cache, explained
          _CacheExplainedCard(glowColor: widget.glowColor),
          SizedBox(height: r.spacingM),
          _VersionInfoCard(
            glowColor: widget.glowColor,
            onShowVersions: _showVersionSheet,
          ),
        ],
      ),
    );
  }

  /// Opens a bottom sheet that fetches current version + all GitHub releases
  /// and shows them as a clean list with the latest highlighted.
  Future<void> _showVersionSheet(BuildContext context) async {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _VersionSheet(glowColor: widget.glowColor),
    );
  }
}
