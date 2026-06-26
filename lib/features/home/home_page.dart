import 'package:flutter/material.dart';
import '../../core/localization/app_localizations.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/particle_background.dart';
import 'widgets/floating_navbar.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final onBg = isDark ? Colors.white : Colors.black;
    final glowColor = isDark ? AppColors.greenBright : AppColors.greenMedium;

    return Scaffold(
      backgroundColor: isDark ? AppColors.bgDark : AppColors.bgLight,
      body: Stack(
        children: [
          ParticleBackground(
            glowColor: glowColor, particleColor: glowColor, particleCount: 15),
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.headphones, size: 64, color: glowColor.withValues(alpha: 0.3)),
                SizedBox(height: 16),
                Text(loc.setup.homePreviewTitle,
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: onBg, letterSpacing: 1)),
                SizedBox(height: 8),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 48),
                  child: Text(loc.setup.homePreviewDesc,
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 14, color: onBg.withValues(alpha: 0.5))),
                ),
              ],
            ),
          ),
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Center(child: FloatingNavbar(isDark: isDark)),
          ),
        ],
      ),
    );
  }
}
