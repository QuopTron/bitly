part of 'settings_sheet_new.dart';

/// Bottom-sheet modal de activación de Premium: input del código,
/// validación contra el backend Go y confirmación visual al activar.
class _PremiumActivationSheet extends StatefulWidget {
  final Color glowColor;
  final Future<void> Function() onPremiumChanged;

  const _PremiumActivationSheet({
    required this.glowColor,
    required this.onPremiumChanged,
  });

  @override
  State<_PremiumActivationSheet> createState() =>
      _PremiumActivationSheetState();
}

class _PremiumActivationSheetState extends State<_PremiumActivationSheet> {
  final _controller = TextEditingController();
  var _sending = false;
  var _activated = false;
  String? _errorMsg;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _activate() async {
    final code = _controller.text.trim();
    setState(() {
      _sending = true;
      _errorMsg = null;
    });
    if (code.isEmpty) {
      setState(() {
        _sending = false;
        _errorMsg = 'Ingresa un codigo valido';
      });
      return;
    }
    final err = await sl<BackendService>().validatePremiumCode(code);
    if (err != null) {
      if (!mounted) return;
      setState(() {
        _sending = false;
        _errorMsg = err;
      });
      return;
    }
    await sl<PremiumCache>().activatePremium(code);
    await widget.onPremiumChanged();
    if (!mounted) return;
    setState(() {
      _activated = true;
      _sending = false;
    });
    await Future.delayed(const Duration(milliseconds: 800));
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final onBg = AppColors.onSurface(isDark);
    final bg = AppColors.surface(isDark);
    final glow = widget.glowColor;
    final r = Responsive(context);

    return Container(
      height: MediaQuery.of(context).size.height * 0.4,
      margin: EdgeInsets.only(top: r.spacingXL * 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.45 : 0.18),
            blurRadius: 30,
            offset: const Offset(0, -6),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        child: Column(
          children: [
            SizedBox(height: r.spacingM),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: onBg.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            SizedBox(height: r.spacingL),
            _PremiumSheetHeader(glowColor: glow, onBg: onBg, r: r),
            SizedBox(height: r.spacingL),
            _PremiumCodeForm(
              controller: _controller,
              sending: _sending,
              activated: _activated,
              errorMsg: _errorMsg,
              glowColor: glow,
              onBg: onBg,
              r: r,
              onActivate: _activate,
            ),
            SizedBox(height: r.bottomPadding),
          ],
        ),
      ),
    );
  }
}
