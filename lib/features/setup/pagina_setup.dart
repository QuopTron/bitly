// ─────────────────────────────────────────────────────────────
// pagina_setup.dart — Selector del flujo de setup: elige el layout
// según plataforma (móvil/escritorio), crea el SetupBloc con el
// notifier de idioma y comparte el controlador de usuario y el
// diálogo de info entre ambas variantes. Al entrar despacha
// ChequearDatosExistentes para el prompt de reingreso.
// Se conecta con: setup_bloc + setup_movil/setup_escritorio +
// deteccion_plataforma + l10n + fondo_particulas.
// Parte del flujo: setup (bienvenida completa).
// ─────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../l10n/app_localizations.dart';
import '../../shared/tema/colores_app.dart';
import '../../shared/utilidades/deteccion_plataforma.dart';
import '../../shared/utilidades/responsive.dart';
import '../../shared/widgets/fondo_particulas.dart';
import 'bloc/setup_bloc.dart';
import 'bloc/setup_estado.dart';
import 'bloc/setup_evento.dart';
import 'setup_escritorio.dart';
import 'setup_movil.dart';

/// Página del setup: elige el layout según la plataforma.
class PaginaSetup extends StatefulWidget {
  const PaginaSetup({super.key});

  @override
  State<PaginaSetup> createState() => _PaginaSetupState();
}

class _PaginaSetupState extends State<PaginaSetup> {
  final TextEditingController _controladorUsuario = TextEditingController();

  @override
  void initState() {
    super.initState();
    context.read<SetupBloc>().add(const ChequearDatosExistentes());
  }

  @override
  void dispose() {
    _controladorUsuario.dispose();
    super.dispose();
  }

  void _mostrarInfo(String titulo, String mensaje) {
    if (!mounted) return;
    final esOscuro = Theme.of(context).brightness == Brightness.dark;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: esOscuro ? const Color(0xFF1A1A1A) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          titulo,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: esOscuro ? Colors.white : Colors.black,
          ),
        ),
        content: Text(
          mensaje,
          style: TextStyle(
            color: esOscuro ? Colors.white70 : Colors.black87,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(AppLocalizations.of(ctx).setup.continueText),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final r = Responsive(context);
    final esOscuro = Theme.of(context).brightness == Brightness.dark;
    final colorFondo = esOscuro ? ColoresApp.fondoOscuro : ColoresApp.fondoClaro;
    final colorBrillo =
        esOscuro ? ColoresApp.verdeBrillante : ColoresApp.verdeMedio;

    final selector = BlocConsumer<SetupBloc, EstadoSetup>(
      listener: (context, state) {
        if (state.paso == PasoSetup.usuario &&
            _controladorUsuario.text != state.usuario) {
          _controladorUsuario.text = state.usuario;
        }
      },
      builder: (context, state) {
        if (usarLayoutEscritorio(context)) {
          return SetupEscritorio(
            state: state,
            loc: loc,
            r: r,
            esOscuro: esOscuro,
            controladorUsuario: _controladorUsuario,
            mostrarInfo: _mostrarInfo,
          );
        }
        return SetupMovil(
          state: state,
          loc: loc,
          r: r,
          esOscuro: esOscuro,
          controladorUsuario: _controladorUsuario,
          mostrarInfo: _mostrarInfo,
        );
      },
    );

    return Scaffold(
      backgroundColor: colorFondo,
      body: Stack(
        children: [
          FondoParticulas(
            glowColor: colorBrillo,
            particleColor: colorBrillo,
            particleCount: 8,
          ),
          SafeArea(child: selector),
        ],
      ),
    );
  }
}