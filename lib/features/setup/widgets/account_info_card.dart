import 'package:flutter/material.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/helpers/responsive.dart';
import '../../../shared/widgets/glass_container.dart';
import '../bloc/setup_state.dart';

class AccountInfoCard extends StatelessWidget {
  final SetupState state;
  final AppLocalizations loc;
  final Responsive r;
  final Color onBg;
  final Color glowColor;

  const AccountInfoCard({
    super.key,
    required this.state,
    required this.loc,
    required this.r,
    required this.onBg,
    required this.glowColor,
  });

  @override
  Widget build(BuildContext context) {
    return GlassContainer(
      borderRadius: 14,
      borderColor: onBg.withValues(alpha: 0.08),
      bgColor: onBg.withValues(alpha: 0.02),
      margin: EdgeInsets.symmetric(horizontal: r.spacingXL),
      padding: EdgeInsets.all(r.spacingM),
      child: Column(
        children: [
          _row(Icons.language, state.existingLocale == 'es' ? loc.setup.espanol : loc.setup.english),
          if ((state.existingUsername ?? '').isNotEmpty) ...[
            SizedBox(height: r.spacingXS),
            _row(Icons.person, state.existingUsername!),
          ],
          SizedBox(height: r.spacingXS),
          _row(
            state.existingMode == 'free' ? Icons.music_note : Icons.verified,
            '${state.existingMode == 'free' ? loc.setup.free : loc.setup.premium} — ${state.existingMode == 'free' ? loc.setup.freeInfo : loc.setup.premiumInfo}',
          ),
          SizedBox(height: r.spacingXS),
          if (state.existingTrialExpired)
            _row(Icons.warning_amber, loc.setup.trialExpired, color: glowColor)
          else if (state.existingMode == 'free')
            _row(Icons.timer_outlined, loc.setup.trialActive, color: glowColor),
        ],
      ),
    );
  }

  Widget _row(IconData icon, String text, {Color? color}) {
    final c = color ?? onBg;
    return Row(
      children: [
        Icon(icon, size: r.footerSize + 4, color: c),
        SizedBox(width: r.spacingS),
        Expanded(child: Text(text, style: TextStyle(fontSize: r.footerSize + 1, color: c))),
      ],
    );
  }
}
