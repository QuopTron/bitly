import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/helpers/responsive.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/glass_button.dart';
import '../../../shared/widgets/glass_container.dart';
import '../bloc/setup_bloc.dart';
import '../bloc/setup_event.dart';
import '../bloc/setup_state.dart';
import 'username_field.dart';

class UsernameSlide extends StatelessWidget {
  final SetupState state;
  final AppLocalizations loc;
  final Responsive r;
  final bool isDark;
  final TextEditingController controller;

  const UsernameSlide({
    super.key,
    required this.state,
    required this.loc,
    required this.r,
    required this.isDark,
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    final onBg = isDark ? Colors.white : Colors.black;
    final glowColor = isDark ? AppColors.greenBright : AppColors.greenMedium;
    final hasExisting = state.hasExistingData == true &&
        state.continueWithExisting == false &&
        (state.existingUsername ?? '').isNotEmpty;

    return Padding(
      key: const ValueKey('username'),
      padding: EdgeInsets.only(bottom: r.bottomPadding),
      child: Column(
        children: [
          const Spacer(),
          _icon(onBg),
          SizedBox(height: r.spacingS),
          Text(loc.setup.chooseUsername,
              style: TextStyle(fontSize: r.titleSize, fontWeight: FontWeight.bold, color: onBg, letterSpacing: 1)),
          SizedBox(height: 2),
          Text(loc.setup.usernameSubtitle,
              style: TextStyle(fontSize: r.footerSize, color: onBg.withValues(alpha: 0.5))),
          SizedBox(height: r.spacingL),
          if (hasExisting) Padding(
            padding: EdgeInsets.symmetric(horizontal: r.spacingXL),
            child: _existingBanner(onBg, glowColor),
          ),
          SizedBox(height: hasExisting ? r.spacingM : 0),
          UsernameField(state: state, loc: loc, r: r, onBg: onBg, glowColor: glowColor, controller: controller),
          const Spacer(),
          _buttons(context, glowColor),
          SizedBox(height: r.spacingS),
        ],
      ),
    );
  }

  Widget _buttons(BuildContext context, Color glowColor) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: r.spacingXL),
      child: SizedBox(
        height: r.continueButtonHeight,
        child: Row(
          children: [
            Expanded(child: GlassButton(
              label: loc.setup.back,
              onPressed: () => context.read<SetupBloc>().add(const PreviousSlide()),
              height: r.continueButtonHeight, accent: glowColor,
            )),
            SizedBox(width: r.spacingM),
            Expanded(child: GlassButton(
              label: loc.setup.next,
              onPressed: state.username.trim().isNotEmpty
                  ? () => context.read<SetupBloc>().add(const NextSlide())
                  : null,
              height: r.continueButtonHeight, accent: glowColor,
            )),
          ],
        ),
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
      child: Icon(Icons.person_outline, size: r.titleSize * 1.1, color: onBg.withValues(alpha: 0.55)),
    );
  }

  Widget _existingBanner(Color onBg, Color glowColor) {
    return GlassContainer(
      borderRadius: 12,
      borderColor: glowColor.withValues(alpha: 0.2),
      bgColor: glowColor.withValues(alpha: 0.06),
      padding: EdgeInsets.symmetric(horizontal: r.spacingM, vertical: r.spacingS),
      child: Row(
        children: [
          Icon(Icons.info_outline, color: glowColor, size: r.footerSize + 2),
          SizedBox(width: r.spacingS),
          Expanded(child: Text(
            '${loc.setup.previousNameWas} "${state.existingUsername}"',
            style: TextStyle(fontSize: r.footerSize, color: glowColor),
          )),
        ],
      ),
    );
  }
}
