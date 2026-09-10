// ─────────────────────────────────────────────────────────────
// slide_google.dart — Paso "Inicia sesión con Google" del setup
// (opcional, se puede omitir): explica para qué se usa la sesión
// (streams sin 403, solo música, privado, se puede cerrar) antes de
// conectar. El flujo lo maneja ServicioOAuthYouTube: nativo
// (Credential Manager) con caída a WebView in-app — el
// consentimiento de Google nunca sale de la app. Los tokens quedan
// en el dispositivo. Los sub-widgets viven en el part
// slide_google_widgets.dart.
// Se conecta con: ServicioOAuthYouTube (conexión) + setup_bloc
// (EstadoGoogleCambiado) + shared (vidrio, logo) + l10n.
// Parte del flujo: setup (paso 4: conexión con Google).
// ─────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../l10n/app_localizations.dart';
import '../../../shared/tema/colores_app.dart';
import '../../../shared/utilidades/responsive.dart';
import '../../../shared/widgets/boton_vidrio.dart';
import '../../../shared/widgets/contenedor_vidrio.dart';
import '../../../shared/widgets/logo_google.dart';
import '../../../core/servicios/servicio_oauth_youtube.dart';
import '../bloc/setup_bloc.dart';
import '../bloc/setup_estado.dart';
import '../bloc/setup_evento.dart';

part 'slide_google_widgets.dart';
part 'slide_google_tarjeta.dart';

/// Slide de inicio de sesión con Google (opcional).
class SlideGoogle extends StatefulWidget {
  final EstadoSetup state;
  final AppLocalizations loc;
  final Responsive r;
  final bool isDark;

  const SlideGoogle({
    super.key,
    required this.state,
    required this.loc,
    required this.r,
    required this.isDark,
  });

  @override
  State<SlideGoogle> createState() => _SlideGoogleState();
}

class _SlideGoogleState extends State<SlideGoogle> {
  bool _conectando = false;

  String _t(String es, String en) {
    final lang = Localizations.localeOf(context).languageCode;
    return lang == 'es' ? es : en;
  }

  Future<void> _conectar(BuildContext context) async {
    if (_conectando) return;
    final bloc = context.read<SetupBloc>();
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _conectando = true);
    final msg = await ServicioOAuthYouTube().conectar(context);
    if (!mounted) return;
    setState(() => _conectando = false);
    final ok = msg.startsWith('Sesión de YouTube conectada');
    bloc.add(EstadoGoogleCambiado(ok));
    messenger.showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: ok ? null : Colors.redAccent,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 4),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final onBg = widget.isDark ? Colors.white : Colors.black;
    final glowColor =
        widget.isDark ? ColoresApp.verdeBrillante : ColoresApp.verdeMedio;
    final conectado = widget.state.googleConectado;

    return Padding(
      key: const ValueKey('googleSignIn'),
      padding: EdgeInsets.only(bottom: widget.r.bottomPadding),
      child: Column(
        children: [
          const Spacer(),
          _insigniaGoogle(),
          SizedBox(height: widget.r.spacingS),
          Text(
            _t('Inicia sesión con Google', 'Sign in with Google'),
            style: TextStyle(
              fontSize: widget.r.titleSize + 3,
              fontWeight: FontWeight.bold,
              color: onBg,
              letterSpacing: 0.6,
            ),
          ),
          SizedBox(height: 4),
          Text(
            _t('Opcional — mejora tu reproducción', 'Optional — better playback'),
            style: TextStyle(
              fontSize: widget.r.footerSize + 1,
              color: onBg.withValues(alpha: 0.5),
            ),
          ),
          SizedBox(height: widget.r.spacingM),
          _tarjetaInfo(this, onBg, glowColor),
          SizedBox(height: widget.r.spacingM),
          if (conectado)
            _chipConectado(this, glowColor)
          else
            _botonConectar(this, glowColor),
          const Spacer(),
          _botones(this, context, glowColor),
          SizedBox(height: widget.r.spacingS),
        ],
      ),
    );
  }
}