import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/utils/responsive.dart';
import '../../../shared/theme/app_colors.dart';
import '../../../shared/widgets/glass_container.dart';
import '../../../shared/widgets/glass_button.dart';
import '../bloc/setup_state.dart';

class ThankYouSlide extends StatefulWidget {
  final SetupState state;
  final AppLocalizations loc;
  final Responsive r;
  final bool isDark;

  const ThankYouSlide({
    super.key,
    required this.state,
    required this.loc,
    required this.r,
    required this.isDark,
  });

  @override
  State<ThankYouSlide> createState() => _ThankYouSlideState();
}

class _ThankYouSlideState extends State<ThankYouSlide> {
  Timer? _timer;
  int _secondsLeft = 30;
  bool _showSkip = false;
  bool _navigating = false;

  @override
  void initState() {
    super.initState();
    if (!widget.state.saving) {
      _startTimer();
    }
  }

  @override
  void didUpdateWidget(covariant ThankYouSlide oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.state.saving && oldWidget.state.saving && _timer == null) {
      _startTimer();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) { timer.cancel(); return; }
      setState(() => _secondsLeft--);
      if (_secondsLeft == 25 && mounted) setState(() => _showSkip = true);
      if (_secondsLeft <= 0 && mounted) _goHome();
    });
  }

  void _goHome() {
    if (_navigating) return;
    _navigating = true;
    _timer?.cancel();
    GoRouter.of(context).go('/home');
  }

  @override
  Widget build(BuildContext context) {
    final onBg = widget.isDark ? Colors.white : Colors.black;
    final glowColor = widget.isDark ? AppColors.greenBright : AppColors.greenMedium;

    if (widget.state.saving) {
      return Padding(
        padding: EdgeInsets.only(bottom: widget.r.bottomPadding),
        child: Column(children: [
          const Spacer(),
          _icon(onBg, glowColor),
          SizedBox(height: widget.r.spacingL),
          Text(widget.loc.setup.thankYouTitle,
            style: TextStyle(fontSize: widget.r.titleSize + 2, fontWeight: FontWeight.bold, color: onBg, letterSpacing: 1)),
          SizedBox(height: widget.r.spacingM),
          _loader(glowColor),
          const Spacer(),
        ]),
      );
    }

    return Padding(
      padding: EdgeInsets.only(bottom: widget.r.bottomPadding),
      child: Column(children: [
        const Spacer(),
        _icon(onBg, glowColor),
        SizedBox(height: widget.r.spacingL),
        Text(widget.loc.setup.thankYouTitle,
          style: TextStyle(fontSize: widget.r.titleSize + 2, fontWeight: FontWeight.bold, color: onBg, letterSpacing: 1)),
        SizedBox(height: widget.r.spacingS),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: widget.r.spacingXL),
          child: Text(widget.loc.setup.thankYouMessage,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: widget.r.footerSize, color: onBg.withValues(alpha: 0.5))),
        ),
        SizedBox(height: widget.r.spacingXL),
        _countdown(onBg, glowColor),
        const Spacer(),
        if (_showSkip) Padding(
          padding: EdgeInsets.symmetric(horizontal: widget.r.spacingXL),
          child: GlassButton(
            label: widget.loc.setup.thankYouSkip,
            onPressed: _goHome,
            height: widget.r.continueButtonHeight,
            accent: glowColor,
          ),
        ),
        SizedBox(height: widget.r.spacingM),
      ]),
    );
  }

  Widget _icon(Color onBg, Color glowColor) {
    return Container(
      padding: EdgeInsets.all(widget.r.spacingM),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: [glowColor.withValues(alpha: 0.2), glowColor.withValues(alpha: 0.05)],
          begin: Alignment.topLeft, end: Alignment.bottomRight,
        ),
        border: Border.all(color: glowColor.withValues(alpha: 0.3), width: 1.5),
        boxShadow: [BoxShadow(color: glowColor.withValues(alpha: 0.15), blurRadius: 20, offset: const Offset(0, 4))],
      ),
      child: Icon(Icons.headphones, size: widget.r.titleSize * 1.4, color: glowColor),
    );
  }

  Widget _loader(Color glowColor) {
    return GlassContainer(
      borderRadius: 14,
      borderColor: glowColor.withValues(alpha: 0.1),
      bgColor: glowColor.withValues(alpha: 0.04),
      padding: EdgeInsets.symmetric(horizontal: widget.r.spacingXL, vertical: widget.r.spacingM),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        SizedBox(
          width: widget.r.footerSize + 4,
          height: widget.r.footerSize + 4,
          child: CircularProgressIndicator(strokeWidth: 2, color: glowColor),
        ),
        SizedBox(width: widget.r.spacingM),
        Text(widget.loc.setup.completingSetup,
          style: TextStyle(fontSize: widget.r.footerSize, color: glowColor.withValues(alpha: 0.7))),
      ]),
    );
  }

  Widget _countdown(Color onBg, Color glowColor) {
    final progress = _secondsLeft / 30;
    return Column(mainAxisSize: MainAxisSize.min, children: [
      SizedBox(
        width: widget.r.titleSize * 3,
        height: widget.r.titleSize * 3,
        child: Stack(alignment: Alignment.center, children: [
          SizedBox(
            width: widget.r.titleSize * 3,
            height: widget.r.titleSize * 3,
            child: CircularProgressIndicator(
              value: progress,
              strokeWidth: 3,
              backgroundColor: onBg.withValues(alpha: 0.06),
              color: glowColor,
            ),
          ),
          Column(mainAxisSize: MainAxisSize.min, children: [
            Text('$_secondsLeft',
              style: TextStyle(fontSize: widget.r.titleSize + 4, fontWeight: FontWeight.bold, color: glowColor)),
            Text(widget.loc.setup.secondsAbbrev,
              style: TextStyle(fontSize: widget.r.footerSize, color: onBg.withValues(alpha: 0.4))),
          ]),
        ]),
      ),
      SizedBox(height: widget.r.spacingS),
      Text(widget.loc.setup.thankYouStarting,
        style: TextStyle(fontSize: widget.r.footerSize, color: onBg.withValues(alpha: 0.4))),
    ]);
  }
}

