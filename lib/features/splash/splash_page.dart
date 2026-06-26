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
import 'widgets/pulsing_logo.dart';
import 'widgets/error_panel.dart';

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
      vsync: this, duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);
    _pulse = Tween(begin: 0.3, end: 1.0)
        .animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
    context.read<SplashBloc>().add(const CheckBackend());
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _onConnected() async {
    await Future.delayed(const Duration(milliseconds: 2500));
    if (!mounted) return;
    GoRouter.of(context).go('/setup');
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
          if (state.status == SplashStatus.connected) _onConnected();
        },
        builder: (context, state) {
          return Stack(
            children: [
              ParticleBackground(glowColor: glowColor, particleColor: onBg, particleCount: 30),
              Center(
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      PulsingLogo(pulse: _pulse, r: r, isDark: isDark),
                      SizedBox(height: r.spacingL),
                      Text('BITLY',
                          style: TextStyle(
                            fontSize: r.titleSize,
                            fontWeight: FontWeight.bold,
                            color: onBg,
                            letterSpacing: 8,
                          )),
                      if (state.status == SplashStatus.error)
                        ErrorPanel(state: state, loc: loc, r: r, isDark: isDark),
                    ],
                  ),
                ),
              ),
              Positioned(
                bottom: r.bottomPadding,
                left: 0,
                right: 0,
                child: Center(
                  child: Text('POWERED BY FLOX',
                      style: TextStyle(
                        fontSize: r.footerSize,
                        color: onBg.withValues(alpha: 0.4),
                        letterSpacing: 3,
                      )),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
