import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/helpers/responsive.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/glass_button.dart';
import '../bloc/setup_bloc.dart';
import '../bloc/setup_event.dart';
import '../bloc/setup_state.dart';
import 'account_info_card.dart';

class ReturningPrompt extends StatelessWidget {
  final SetupState state;
  final AppLocalizations loc;
  final Responsive r;
  final bool isDark;

  const ReturningPrompt({
    super.key,
    required this.state,
    required this.loc,
    required this.r,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final onBg = isDark ? Colors.white : Colors.black;
    final glowColor = isDark ? AppColors.greenBright : AppColors.greenMedium;

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: r.spacingXL),
      child: Column(
        children: [
          const Spacer(),
          _icon(onBg),
          SizedBox(height: r.spacingS),
          Text(loc.setup.existingAccount,
              style: TextStyle(fontSize: r.titleSize, fontWeight: FontWeight.bold, color: onBg, letterSpacing: 1)),
          SizedBox(height: r.spacingS),
          Text(loc.setup.returningUser, textAlign: TextAlign.center,
              style: TextStyle(fontSize: r.footerSize, color: onBg.withValues(alpha: 0.5))),
          SizedBox(height: r.spacingM),
          AccountInfoCard(state: state, loc: loc, r: r, onBg: onBg, glowColor: glowColor),
          SizedBox(height: r.spacingM),
          Text(loc.setup.startFresh, textAlign: TextAlign.center,
              style: TextStyle(fontSize: r.footerSize - 1, color: onBg.withValues(alpha: 0.4))),
          const Spacer(),
          GlassButton(
            label: loc.setup.yes,
            onPressed: () => context.read<SetupBloc>().add(const AcceptExistingData(true)),
            height: r.continueButtonHeight, accent: glowColor,
          ),
          SizedBox(height: r.spacingM),
          GlassButton(
            label: loc.setup.no,
            onPressed: () => context.read<SetupBloc>().add(const AcceptExistingData(false)),
            height: r.continueButtonHeight, accent: glowColor,
          ),
          SizedBox(height: r.spacingM),
        ],
      ),
    );
  }

  Widget _icon(Color onBg) {
    return Container(
      padding: EdgeInsets.all(r.spacingS),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: onBg.withValues(alpha: 0.04),
        border: Border.all(color: onBg.withValues(alpha: 0.08), width: 0.8),
      ),
      child: Icon(Icons.person_outline, size: r.titleSize * 1.5, color: onBg.withValues(alpha: 0.55)),
    );
  }
}
