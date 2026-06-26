import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/helpers/responsive.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/glass_button.dart';
import '../../../shared/widgets/glass_container.dart';
import '../bloc/setup_bloc.dart';
import '../bloc/setup_event.dart';
import '../bloc/setup_state.dart';

class NotificationSlide extends StatefulWidget {
  final SetupState state;
  final AppLocalizations loc;
  final Responsive r;
  final bool isDark;

  const NotificationSlide({
    super.key,
    required this.state,
    required this.loc,
    required this.r,
    required this.isDark,
  });

  @override
  State<NotificationSlide> createState() => _NotificationSlideState();
}

class _NotificationSlideState extends State<NotificationSlide> {
  bool _notificationDone = false;
  bool _notificationGranted = false;
  bool _storageDone = false;
  bool _storageGranted = false;
  bool _requesting = false;

  bool get _allDone => _notificationDone && _storageDone;

  Future<void> _requestAll() async {
    if (_requesting) return;
    setState(() => _requesting = true);

    if (!_notificationDone) {
      final n = await Permission.notification.request();
      if (mounted) {
        setState(() {
          _notificationDone = true;
          _notificationGranted = n.isGranted;
        });
      }
    }

    if (!_storageDone && mounted) {
      final s = await Permission.storage.request();
      if (mounted) {
        setState(() {
          _storageDone = true;
          _storageGranted = s.isGranted;
        });
      }
    }

    if (mounted) setState(() => _requesting = false);
  }

  void _proceed() {
    context.read<SetupBloc>().add(const CompleteSetup());
  }

  @override
  Widget build(BuildContext context) {
    final onBg = widget.isDark ? Colors.white : Colors.black;
    final glowColor = widget.isDark ? AppColors.greenBright : AppColors.greenMedium;
    final saving = widget.state.saving;

    return Padding(
      padding: EdgeInsets.only(bottom: widget.r.bottomPadding),
      child: Column(children: [
        const Spacer(),
        SizedBox(height: widget.r.spacingXL),
        _icon(onBg),
        SizedBox(height: widget.r.spacingS),
        Text(widget.loc.setup.notificationTitle,
          style: TextStyle(fontSize: widget.r.titleSize, fontWeight: FontWeight.bold, color: onBg, letterSpacing: 1)),
        SizedBox(height: widget.r.spacingM),
        _permCards(onBg, glowColor),
        const Spacer(),
        _actions(onBg, glowColor, saving),
        SizedBox(height: widget.r.spacingM),
      ]),
    );
  }

  Widget _icon(Color onBg) => Container(
    padding: EdgeInsets.all(widget.r.spacingS),
    decoration: BoxDecoration(shape: BoxShape.circle, color: onBg.withValues(alpha: 0.04), border: Border.all(color: onBg.withValues(alpha: 0.08), width: 0.8)),
    child: Icon(Icons.notifications_outlined, size: widget.r.titleSize * 1.1, color: onBg.withValues(alpha: 0.55)),
  );

  Widget _permCards(Color onBg, Color glowColor) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: widget.r.spacingXL),
      child: GlassContainer(
        borderRadius: 14,
        borderColor: glowColor.withValues(alpha: 0.15),
        bgColor: onBg.withValues(alpha: 0.02),
        padding: EdgeInsets.all(widget.r.spacingM),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          _permRow(Icons.notifications_active, widget.loc.setup.notificationDesc, _notificationDone, _notificationGranted, glowColor, onBg),
          SizedBox(height: widget.r.spacingM),
          _permRow(Icons.storage, widget.loc.setup.storageDesc, _storageDone, _storageGranted, glowColor, onBg),
        ]),
      ),
    );
  }

  Widget _permRow(IconData icon, String desc, bool done, bool granted, Color glowColor, Color onBg) {
    return Row(children: [
      Icon(icon, size: widget.r.subtitleSize + 2, color: granted ? glowColor : onBg.withValues(alpha: 0.4)),
      SizedBox(width: widget.r.spacingS),
      Expanded(child: Text(desc,
        style: TextStyle(fontSize: widget.r.footerSize, color: done && !granted
            ? Colors.redAccent.withValues(alpha: 0.7)
            : onBg.withValues(alpha: 0.65)))),
      if (done) Icon(granted ? Icons.check_circle : Icons.cancel,
        size: widget.r.footerSize + 2,
        color: granted ? glowColor : Colors.redAccent.withValues(alpha: 0.6)),
    ]);
  }

  Widget _actions(Color onBg, Color glowColor, bool saving) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: widget.r.spacingXL),
      child: Column(children: [
        GlassButton(
          label: _allDone ? widget.loc.setup.continueText : widget.loc.setup.notificationActivate,
          onPressed: saving ? null : () async {
            if (!_allDone) await _requestAll();
            if (mounted) _proceed();
          },
          isLoading: _requesting || saving,
          height: widget.r.continueButtonHeight,
          accent: glowColor,
        ),
        if (!_allDone) ...[
          SizedBox(height: widget.r.spacingM),
          GlassButton(
            label: widget.loc.setup.notificationSkip,
            onPressed: saving ? null : _proceed,
            height: widget.r.continueButtonHeight,
            accent: glowColor,
          ),
        ],
      ]),
    );
  }
}
