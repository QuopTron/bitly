// ─────────────────────────────────────────────────────────────
// settings_sheet_soulseek_form.dart — PART de settings_sheet_new
// .dart: cuerpo del formulario de la hoja de Soulseek — campo de
// nombre, textos de ayuda, botón "Siguiente" y bloque para
// revelar la contraseña guardada.
// Se conecta con: settings_sheet_new.dart (misma library) +
// settings_sheet_soulseek_sheet (lo monta).
// Parte del flujo: Ajustes → Más (formulario Soulseek).
// ─────────────────────────────────────────────────────────────

part of 'settings_sheet_new.dart';

/// Formulario de alta/conexión de Soulseek. Recibe el estado desde la hoja y
/// avisa por callbacks para no guardar lógica acá.
class _SoulseekForm extends StatelessWidget {
  final TextEditingController nombreCtrl;
  final bool cargando;
  final bool conectada;
  final bool propuestaDeLaApp;
  final bool revelada;
  final String password;
  final String? mensaje;
  final Color glow;
  final Color onBg;
  final Responsive r;
  final VoidCallback onSiguiente;
  final VoidCallback onToggleRevelada;

  const _SoulseekForm({
    required this.nombreCtrl,
    required this.cargando,
    required this.conectada,
    required this.propuestaDeLaApp,
    required this.revelada,
    required this.password,
    required this.mensaje,
    required this.glow,
    required this.onBg,
    required this.r,
    required this.onSiguiente,
    required this.onToggleRevelada,
  });

  @override
  Widget build(BuildContext context) => _construirFormularioSoulseek(context, nombreCtrl, cargando, conectada, propuestaDeLaApp, revelada, password, mensaje, glow, onBg, r, onSiguiente, onToggleRevelada);

}
