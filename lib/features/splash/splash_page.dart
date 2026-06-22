import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../core/localization/app_localizations.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/particle_background.dart';
import '../../core/helpers/responsive.dart';
import 'bloc/splash_bloc.dart';
import 'bloc/splash_event.dart';
import 'bloc/splash_state.dart';

class SplashPage extends StatefulWidget {
  const SplashPage({super.key});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _pulse;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);
    _pulse = Tween(begin: 0.3, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
    context.read<SplashBloc>().add(const CheckBackend());
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final r = Responsive(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? AppColors.bgDark : AppColors.bgLight;
    final onBg = isDark ? Colors.white : Colors.black;
    final glowColor = isDark ? AppColors.greenBright : AppColors.greenMedium;

    return Scaffold(
      backgroundColor: bgColor,
      body: BlocConsumer<SplashBloc, SplashState>(
        listener: (context, state) {
          if (state.status == SplashStatus.connected) {
            Future.delayed(const Duration(milliseconds: 2500), () {
              if (context.mounted) GoRouter.of(context).go('/setup');
            });
          }
        },
        builder: (context, state) {
          return Stack(
            children: [
              ParticleBackground(
                glowColor: glowColor,
                particleColor: onBg,
                particleCount: 30,
              ),
              Center(
                child: SingleChildScrollView(
                  child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AnimatedBuilder(
                      animation: _pulse,
                      builder: (context, child) {
                        final logo = isDark
                            ? 'assets/images/logoBitlyOscuro.png'
                            : 'assets/images/logoBitlyClaro.png';
                        return Container(
                          padding: EdgeInsets.all(r.circlePadding),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppColors.darkGreen.withValues(alpha: isDark ? 0.3 : 0.05),
                            border: Border.all(
                              color: glowColor.withValues(alpha: _pulse.value * 0.3),
                              width: 1.5,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: glowColor.withValues(alpha: _pulse.value * 0.25),
                                blurRadius: 60 * _pulse.value,
                                spreadRadius: 12 * _pulse.value,
                              ),
                            ],
                          ),
                          child: Image.asset(logo, height: r.logoSize, fit: BoxFit.contain),
                        );
                      },
                    ),
                    SizedBox(height: r.spacingL),
                    Text(
                      'BITLY',
                      style: TextStyle(
                        fontSize: r.titleSize,
                        fontWeight: FontWeight.bold,
                        color: onBg,
                        letterSpacing: 8,
                      ),
                    ),
                    if (state.status == SplashStatus.error) ...[
                      SizedBox(height: r.spacingXL),
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: r.spacingXL),
                        child: Text(
                          state.error ?? loc.splash.backendNotResponding,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: onBg.withValues(alpha: 0.65),
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
                          onPressed: () {
                            context.read<SplashBloc>().add(const CheckBackend());
                          },
                          child: Text(
                            loc.splash.retry,
                            style: TextStyle(
                              color: glowColor,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                ),
              ),
              Positioned(
                bottom: r.bottomPadding,
                left: 0,
                right: 0,
                child: Center(
                  child: Text(
                    'POWERED BY FLOX',
                    style: TextStyle(
                      fontSize: r.footerSize,
                      color: onBg.withValues(alpha: 0.4),
                      letterSpacing: 3,
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
