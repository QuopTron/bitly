import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/helpers/responsive.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/mode_card.dart';
import '../../../shared/widgets/glass_button.dart';
import '../../../shared/widgets/glass_container.dart';
import '../bloc/setup_bloc.dart';
import '../bloc/setup_event.dart';
import '../bloc/setup_state.dart';
import 'premium_code_card.dart';

class ModeSlide extends StatelessWidget {
  final SetupState state;
  final AppLocalizations loc;
  final Responsive r;
  final bool isDark;
  final void Function(String title, String message) showInfo;

  const ModeSlide({super.key, required this.state, required this.loc, required this.r, required this.isDark, required this.showInfo});

  @override
  Widget build(BuildContext context) {
    final onBg = isDark ? Colors.white : Colors.black;
    final glowColor = isDark ? AppColors.greenBright : AppColors.greenMedium;
    final trialExpired = state.hasExistingData == true && state.existingTrialExpired == true;
    return LayoutBuilder(builder: (context, constraints) {
      return SingleChildScrollView(
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: IntrinsicHeight(
            child: Padding(
              padding: EdgeInsets.only(bottom: r.bottomPadding + r.spacingS),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                const Spacer(),
                SizedBox(height: r.spacingXL),
                _icon(onBg),
                SizedBox(height: r.spacingS),
                Text(loc.setup.chooseMode, style: TextStyle(fontSize: r.titleSize, fontWeight: FontWeight.bold, color: onBg, letterSpacing: 1)),
                SizedBox(height: r.spacingM),
                if (trialExpired) _trialWarning(onBg, glowColor),
                _freeCard(context, glowColor),
                _premiumCard(context, glowColor),
                if (state.selectedMode == 'premium')
                  PremiumCodeCard(state: state, loc: loc, r: r, onBg: onBg, glowColor: glowColor),
                const Spacer(),
                _buttons(context, glowColor),
              ]),
            ),
          ),
        ),
      );
    });
  }

  Widget _buttons(BuildContext context, Color glowColor) {
    final nextOk = state.selectedMode != null && !(state.selectedMode == 'premium' && !state.codeValid) && !state.saving;
    final bloc = context.read<SetupBloc>();
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: r.spacingXL),
      child: SizedBox(
        height: r.continueButtonHeight,
        child: Row(children: [
          Expanded(child: GlassButton(label: loc.setup.back, onPressed: () => bloc.add(const PreviousSlide()), height: r.continueButtonHeight, accent: glowColor)),
          SizedBox(width: r.spacingM),
          Expanded(child: GlassButton(label: loc.setup.next, onPressed: nextOk ? () => bloc.add(const NextSlide()) : null, isLoading: state.saving, height: r.continueButtonHeight, accent: glowColor)),
        ]),
      ),
    );
  }

  Widget _icon(Color onBg) => Container(
    padding: EdgeInsets.all(r.spacingS),
    decoration: BoxDecoration(shape: BoxShape.circle, color: onBg.withValues(alpha: 0.04), border: Border.all(color: onBg.withValues(alpha: 0.08), width: 0.8)),
    child: Icon(Icons.app_settings_alt, size: r.titleSize * 1.1, color: onBg.withValues(alpha: 0.55)),
  );

  Widget _trialWarning(Color onBg, Color glowColor) => Padding(
    padding: EdgeInsets.symmetric(horizontal: r.spacingXL),
    child: GlassContainer(borderRadius: 12, borderColor: glowColor.withValues(alpha: 0.2), bgColor: glowColor.withValues(alpha: 0.06),
      padding: EdgeInsets.symmetric(horizontal: r.spacingM, vertical: r.spacingS),
      child: Row(children: [
        Icon(Icons.info_outline, color: glowColor, size: r.footerSize + 2),
        SizedBox(width: r.spacingS),
        Expanded(child: Text(loc.setup.trialExpired, style: TextStyle(fontSize: r.footerSize, color: glowColor))),
      ])),
  );

  Widget _freeCard(BuildContext context, Color glowColor) => ModeCard(
    title: loc.setup.free, subtitle: loc.setup.freeInfo, icon: Icons.music_note,
    iconColor: AppColors.greenBright,
    selected: state.selectedMode == 'free',
    onTap: () => context.read<SetupBloc>().add(const SelectMode('free')),
    onInfoTap: () => showInfo(loc.setup.free, loc.setup.freeDetailedInfo), glowColor: glowColor,
  );

  Widget _premiumCard(BuildContext context, Color glowColor) => ModeCard(
    title: loc.setup.premium, subtitle: loc.setup.premiumInfo, icon: Icons.verified,
    iconColor: glowColor, selected: state.selectedMode == 'premium',
    onTap: () => context.read<SetupBloc>().add(const SelectMode('premium')),
    onInfoTap: () => showInfo(loc.setup.premium, loc.setup.premiumDetailedInfo), glowColor: glowColor,
  );
}
