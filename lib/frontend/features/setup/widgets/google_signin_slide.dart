import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../backend/services/youtube_oauth_service.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/theme/app_colors.dart';
import '../../../shared/utils/responsive.dart';
import '../../../shared/widgets/glass_button.dart';
import '../../../shared/widgets/glass_container.dart';
import '../bloc/setup_bloc.dart';
import '../bloc/setup_event.dart';
import '../bloc/setup_state.dart';

/// Setup slide: "Inicia sesión con Google" (optional, skippable).
///
/// Explains what the account session is used for before connecting, so the
/// user decides at onboarding time instead of being asked inside the app.
/// The flow itself is handled by [YoutubeOauthService] (Google's own consent
/// page in the system browser; tokens stay on-device).
class GoogleSignInSlide extends StatefulWidget {
  final SetupState state;
  final AppLocalizations loc;
  final Responsive r;
  final bool isDark;

  const GoogleSignInSlide({
    super.key,
    required this.state,
    required this.loc,
    required this.r,
    required this.isDark,
  });

  @override
  State<GoogleSignInSlide> createState() => _GoogleSignInSlideState();
}

class _GoogleSignInSlideState extends State<GoogleSignInSlide> {
  bool _connecting = false;

  String _t(String es, String en) {
    final lang = Localizations.localeOf(context).languageCode;
    return lang == 'es' ? es : en;
  }

  Future<void> _connect(BuildContext context) async {
    if (_connecting) return;
    final bloc = context.read<SetupBloc>();
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _connecting = true);
    final msg = await YoutubeOauthService().connect();
    if (!mounted) return;
    setState(() => _connecting = false);
    final ok = msg.startsWith('Sesión de YouTube conectada');
    bloc.add(GoogleSignInStatusChanged(ok));
    messenger.showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: ok ? null : Colors.redAccent,
      behavior: SnackBarBehavior.floating,
      duration: const Duration(seconds: 4),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final onBg = widget.isDark ? Colors.white : Colors.black;
    final glowColor =
        widget.isDark ? AppColors.greenBright : AppColors.greenMedium;
    final connected = widget.state.googleConnected;

    return Padding(
      key: const ValueKey('googleSignIn'),
      padding: EdgeInsets.only(bottom: widget.r.bottomPadding),
      child: Column(
        children: [
          const Spacer(),
          _googleBadge(),
          SizedBox(height: widget.r.spacingS),
          Text(
            _t('Inicia sesión con Google', 'Sign in with Google'),
            style: TextStyle(
              fontSize: widget.r.titleSize,
              fontWeight: FontWeight.bold,
              color: onBg,
              letterSpacing: 1,
            ),
          ),
          SizedBox(height: 2),
          Text(
            _t('Opcional — mejora tu reproducción', 'Optional — better playback'),
            style: TextStyle(
              fontSize: widget.r.footerSize,
              color: onBg.withValues(alpha: 0.5),
            ),
          ),
          SizedBox(height: widget.r.spacingM),
          _infoCard(onBg, glowColor),
          SizedBox(height: widget.r.spacingM),
          if (connected)
            _connectedChip(glowColor)
          else
            _connectButton(glowColor),
          const Spacer(),
          _buttons(context, glowColor),
          SizedBox(height: widget.r.spacingS),
        ],
      ),
    );
  }

  Widget _googleBadge() {
    return Container(
      padding: EdgeInsets.all(widget.r.spacingS),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white.withValues(alpha: 0.06),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.15),
          width: 0.8,
        ),
      ),
      child: const Text(
        'G',
        style: TextStyle(
          fontSize: 30,
          fontWeight: FontWeight.w800,
          color: Color(0xFF4285F4),
        ),
      ),
    );
  }

  Widget _infoCard(Color onBg, Color glowColor) {
    final rows = [
      (
        Icons.bolt,
        _t(
          'Streams más rápidos y sin errores 403',
          'Faster streams and no 403 errors',
        ),
        _t(
          'Con sesión, YouTube trata tu app como cuenta autenticada y deja de '
              'bloquear los streams anónimos.',
          'Signed-in playback avoids the anonymous rate limits that make '
              'streams slow or fail.',
        ),
      ),
      (
        Icons.music_note_outlined,
        _t('Solo se usa para música', 'Used only for music'),
        _t(
          'Tu cuenta se usa únicamente para resolver y reproducir canciones.',
          'Your account is only used to resolve and play songs.',
        ),
      ),
      (
        Icons.lock_outline,
        _t('Privado y en tu dispositivo', 'Private, on your device'),
        _t(
          'Los tokens se guardan solo aquí. Nada sale de tu teléfono excepto '
              'a los servidores oficiales de Google.',
          'Tokens are stored only on this device. Nothing leaves your phone '
              'except to Google\'s official servers.',
        ),
      ),
      (
        Icons.logout,
        _t('Puedes cerrarla cuando quieras', 'You can sign out anytime'),
        _t(
          'Cierra la sesión desde Ajustes y se eliminan los tokens.',
          'Sign out from Settings and the tokens are removed.',
        ),
      ),
    ];

    return GlassContainer(
      borderRadius: 14,
      borderColor: onBg.withValues(alpha: 0.08),
      bgColor: onBg.withValues(alpha: 0.03),
      margin: EdgeInsets.symmetric(horizontal: widget.r.spacingL),
      padding: EdgeInsets.all(widget.r.spacingM),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final row in rows) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(row.$1, size: widget.r.subtitleSize, color: glowColor),
                SizedBox(width: widget.r.spacingS),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        row.$2,
                        style: TextStyle(
                          fontSize: widget.r.footerSize + 1,
                          fontWeight: FontWeight.w600,
                          color: onBg,
                        ),
                      ),
                      Text(
                        row.$3,
                        style: TextStyle(
                          fontSize: widget.r.footerSize - 2,
                          color: onBg.withValues(alpha: 0.55),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (row != rows.last) SizedBox(height: widget.r.spacingM),
          ],
        ],
      ),
    );
  }

  Widget _connectButton(Color glowColor) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: widget.r.spacingXL),
      child: SizedBox(
        height: widget.r.continueButtonHeight,
        width: double.infinity,
        child: GlassButton(
          label: _connecting
              ? _t('Conectando…', 'Connecting…')
              : _t('Iniciar sesión con Google', 'Sign in with Google'),
          onPressed: _connecting ? null : () => _connect(context),
          height: widget.r.continueButtonHeight,
          accent: glowColor,
          icon: Icon(_connecting ? Icons.hourglass_top : Icons.login),
        ),
      ),
    );
  }

  Widget _connectedChip(Color glowColor) {
    return GlassContainer(
      borderRadius: 10,
      borderColor: glowColor.withValues(alpha: 0.35),
      bgColor: glowColor.withValues(alpha: 0.08),
      padding: EdgeInsets.symmetric(
        horizontal: widget.r.spacingM,
        vertical: widget.r.spacingS,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.check_circle, color: glowColor, size: widget.r.subtitleSize),
          SizedBox(width: widget.r.spacingS),
          Text(
            _t('Conectado con Google', 'Connected with Google'),
            style: TextStyle(
              fontSize: widget.r.footerSize + 1,
              fontWeight: FontWeight.w600,
              color: glowColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buttons(BuildContext context, Color glowColor) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: widget.r.spacingXL),
      child: SizedBox(
        height: widget.r.continueButtonHeight,
        child: Row(
          children: [
            Expanded(
              child: GlassButton(
                label: widget.loc.setup.back,
                onPressed: () =>
                    context.read<SetupBloc>().add(const PreviousSlide()),
                height: widget.r.continueButtonHeight,
                accent: glowColor,
              ),
            ),
            SizedBox(width: widget.r.spacingM),
            Expanded(
              child: GlassButton(
                label: widget.loc.setup.next,
                onPressed: () =>
                    context.read<SetupBloc>().add(const NextSlide()),
                height: widget.r.continueButtonHeight,
                accent: glowColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}