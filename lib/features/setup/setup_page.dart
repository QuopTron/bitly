import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../core/localization/app_localizations.dart';
import '../../core/theme/app_colors.dart';
import '../../core/helpers/responsive.dart';
import 'bloc/setup_bloc.dart';
import 'bloc/setup_event.dart';
import 'bloc/setup_state.dart';
import '../../shared/widgets/language_card.dart';

class SetupPage extends StatelessWidget {
  const SetupPage({super.key});

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final r = Responsive(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? AppColors.bgDark : AppColors.bgLight;
    final onBg = isDark ? Colors.white : Colors.black;

    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.only(top: r.topPadding),
          child: BlocBuilder<SetupBloc, SetupState>(
            builder: (context, state) {
              return Column(
                children: [
                  Container(
                    padding: EdgeInsets.all(r.spacingM),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: onBg.withValues(alpha: 0.04),
                      border: Border.all(
                        color: onBg.withValues(alpha: 0.15),
                        width: 1,
                      ),
                    ),
                    child: Icon(
                      Icons.language,
                      size: r.titleSize,
                      color: onBg.withValues(alpha: 0.7),
                    ),
                  ),
                  SizedBox(height: r.spacingM),
                  Text(
                    loc.setup.selectLanguage,
                    style: TextStyle(
                      fontSize: r.titleSize,
                      fontWeight: FontWeight.bold,
                      color: onBg,
                    ),
                  ),
                  SizedBox(height: r.spacingS),
                  Text(
                    loc.setup.chooseLanguage,
                    style: TextStyle(
                      fontSize: r.subtitleSize,
                      color: onBg.withValues(alpha: 0.65),
                    ),
                  ),
                  SizedBox(height: r.spacingXL),
                  LanguageCard(
                    icon: Icons.language,
                    iconColor: AppColors.greenBright,
                    name: loc.setup.espanol,
                    selected: state.selectedLocale == 'es',
                    onTap: () {
                      context.read<SetupBloc>().add(const SelectLanguage('es'));
                    },
                  ),
                  LanguageCard(
                    icon: Icons.language,
                    iconColor: AppColors.primary,
                    name: loc.setup.english,
                    selected: state.selectedLocale == 'en',
                    onTap: () {
                      context.read<SetupBloc>().add(const SelectLanguage('en'));
                    },
                  ),
                  const Spacer(),
                  Padding(
                    padding: EdgeInsets.all(r.spacingXL),
                    child: SizedBox(
                      width: double.infinity,
                      height: r.continueButtonHeight,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: onBg.withValues(alpha: 0.08),
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(24),
                            side: BorderSide(
                              color: onBg.withValues(alpha: 0.2),
                            ),
                          ),
                        ),
                        onPressed: state.saving
                            ? null
                            : () => context
                                .read<SetupBloc>()
                                .add(const CompleteSetup()),
                        child: state.saving
                            ? SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: onBg.withValues(alpha: 0.7),
                                ),
                              )
                            : Text(
                                loc.setup.continueText,
                                style: TextStyle(
                                  fontSize: r.subtitleSize,
                                  color: onBg.withValues(alpha: 0.8),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
