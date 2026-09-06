import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../l10n/app_localizations.dart';
import '../../shared/theme/app_colors.dart';
import '../../shared/utils/responsive.dart';
import '../../shared/widgets/particle_background.dart';
import 'bloc/setup_bloc.dart';
import 'bloc/setup_event.dart';
import 'bloc/setup_state.dart';
import 'widgets/returning_prompt.dart';
import 'widgets/language_slide.dart';
import 'widgets/username_slide.dart';
import 'widgets/google_signin_slide.dart';
import 'widgets/mode_slide.dart';
import 'widgets/storage_folder_slide.dart';
import 'widgets/notification_slide.dart';
import 'widgets/verification_slide.dart';
import 'widgets/thank_you_slide.dart';


class SetupPage extends StatefulWidget {
  const SetupPage({super.key});

  @override
  State<SetupPage> createState() => _SetupPageState();
}

class _SetupPageState extends State<SetupPage> {
  final TextEditingController _usernameController = TextEditingController();

  @override
  void initState() {
    super.initState();
    context.read<SetupBloc>().add(const CheckExistingData());
  }

  @override
  void dispose() {
    _usernameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final r = Responsive(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? AppColors.bgDark : AppColors.bgLight;
    final glowColor = isDark ? AppColors.greenBright : AppColors.greenMedium;

    return Scaffold(
      backgroundColor: bgColor,
      body: Stack(
        children: [
          ParticleBackground(glowColor: glowColor, particleColor: glowColor, particleCount: 8),
          SafeArea(
            child: Padding(
              padding: EdgeInsets.only(top: r.topPadding),
              child: BlocConsumer<SetupBloc, SetupState>(
                listener: (context, state) {
                  if (state.step == SetupStep.username && _usernameController.text != state.username) {
                    _usernameController.text = state.username;
                  }
                },
                builder: (context, state) {
                  return LayoutBuilder(
                    builder: (context, constraints) {
                      final maxW = constraints.maxWidth > 600 ? 560.0 : constraints.maxWidth;
                      return Center(
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 400),
                          switchInCurve: Curves.easeInOut,
                          switchOutCurve: Curves.easeInOut,
                          transitionBuilder: (child, animation) =>
                              FadeTransition(opacity: animation, child: child),
                          child: SizedBox(
                            key: ValueKey(state.step),
                            width: maxW,
                            child: _buildStep(state, loc, r, isDark),
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStep(SetupState state, AppLocalizations loc, Responsive r, bool isDark) {
    switch (state.step) {
      case SetupStep.checkingExisting:
        return const Center(key: ValueKey('checking'), child: CircularProgressIndicator());
      case SetupStep.returningPrompt:
        return ReturningPrompt(key: const ValueKey('returning'), state: state, loc: loc, r: r, isDark: isDark);
      case SetupStep.language:
        return LanguageSlide(key: const ValueKey('language'), state: state, loc: loc, r: r, isDark: isDark);
      case SetupStep.username:
        return UsernameSlide(
          key: const ValueKey('username'), state: state, loc: loc, r: r, isDark: isDark,
          controller: _usernameController,
        );
      case SetupStep.googleSignIn:
        return GoogleSignInSlide(
          key: const ValueKey('googleSignIn'), state: state, loc: loc, r: r, isDark: isDark,
        );
      case SetupStep.mode:
        return ModeSlide(
          key: const ValueKey('mode'), state: state, loc: loc, r: r, isDark: isDark,
          showInfo: _showInfoDialog,
        );
      case SetupStep.storageFolder:
        return StorageFolderSlide(
          key: const ValueKey('storageFolder'), state: state, loc: loc, r: r, isDark: isDark,
        );
      case SetupStep.notifications:
        return NotificationSlide(
          key: const ValueKey('notifications'), state: state, loc: loc, r: r, isDark: isDark,
        );
      case SetupStep.verification:
        return VerificationSlide(
          key: const ValueKey('verification'), state: state, loc: loc, r: r, isDark: isDark,
        );
      case SetupStep.thankYou:
        return ThankYouSlide(
          key: const ValueKey('thankYou'), state: state, loc: loc, r: r, isDark: isDark,
        );
    }
  }

  void _showInfoDialog(String title, String message) {
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Theme.of(context).brightness == Brightness.dark
            ? const Color(0xFF1A1A1A) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(title, style: TextStyle(
          fontWeight: FontWeight.bold,
          color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black,
        )),
        content: Text(message, style: TextStyle(
          color: Theme.of(context).brightness == Brightness.dark ? Colors.white70 : Colors.black87,
        )),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(AppLocalizations.of(ctx).setup.continueText),
          ),
        ],
      ),
    );
  }
}


