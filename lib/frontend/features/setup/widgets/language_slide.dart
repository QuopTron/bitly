import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/utils/responsive.dart';
import '../../../shared/theme/app_colors.dart';
import '../../../shared/widgets/language_card.dart';
import '../../../shared/widgets/glass_button.dart';
import '../bloc/setup_bloc.dart';
import '../bloc/setup_event.dart';
import '../bloc/setup_state.dart';

class LanguageSlide extends StatelessWidget {
  final SetupState state;
  final AppLocalizations loc;
  final Responsive r;
  final bool isDark;

  const LanguageSlide({
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
      key: const ValueKey('language'),
      padding: EdgeInsets.only(bottom: r.bottomPadding),
      child: Column(
        children: [
          const Spacer(),
          _icon(onBg),
          SizedBox(height: r.spacingS),
          Text(loc.setup.selectLanguage,
              style: TextStyle(fontSize: r.titleSize, fontWeight: FontWeight.bold, color: onBg, letterSpacing: 1)),
          SizedBox(height: 2),
          Text(loc.setup.chooseLanguage,
              style: TextStyle(fontSize: r.footerSize, color: onBg.withValues(alpha: 0.5))),
          SizedBox(height: r.spacingL),
          LanguageCard(
            icon: Icons.language, iconColor: AppColors.greenBright,
            name: loc.setup.espanol, selected: state.selectedLocale == 'es',
            onTap: () => context.read<SetupBloc>().add(const SelectLanguage('es')),
            glowColor: glowColor,
          ),
          LanguageCard(
            icon: Icons.language, iconColor: AppColors.primary,
            name: loc.setup.english, selected: state.selectedLocale == 'en',
            onTap: () => context.read<SetupBloc>().add(const SelectLanguage('en')),
            glowColor: glowColor,
          ),
          const Spacer(),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: r.spacingXL),
            child: GlassButton(
              label: loc.setup.continueText,
              onPressed: () => context.read<SetupBloc>().add(const NextSlide()),
              height: r.continueButtonHeight,
              accent: glowColor,
            ),
          ),
          SizedBox(height: r.spacingS),
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
      child: Icon(Icons.language, size: r.titleSize * 1.1, color: onBg.withValues(alpha: 0.55)),
    );
  }
}


