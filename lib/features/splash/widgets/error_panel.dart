import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/helpers/responsive.dart';
import '../../../core/theme/app_colors.dart';
import '../bloc/splash_bloc.dart';
import '../bloc/splash_event.dart';
import '../bloc/splash_state.dart';

class ErrorPanel extends StatelessWidget {
  final SplashState state;
  final AppLocalizations loc;
  final Responsive r;
  final bool isDark;

  const ErrorPanel({
    super.key,
    required this.state,
    required this.loc,
    required this.r,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final glowColor =
        isDark ? AppColors.greenBright : AppColors.greenMedium;

    return Column(
      children: [
        SizedBox(height: r.spacingXL),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: r.spacingXL),
          child: Text(
            state.error ?? loc.splash.backendNotResponding,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.65),
              fontSize: r.subtitleSize,
            ),
          ),
        ),
        SizedBox(height: r.spacingM),
        SizedBox(
          height: r.retryButtonHeight,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: glowColor.withValues(alpha: 0.15),
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(22),
                side: BorderSide(color: glowColor.withValues(alpha: 0.4)),
              ),
            ),
            onPressed: () => context.read<SplashBloc>().add(const CheckBackend()),
            child: Text(
              loc.splash.retry,
              style: TextStyle(color: glowColor, fontWeight: FontWeight.w600),
            ),
          ),
        ),
      ],
    );
  }
}
