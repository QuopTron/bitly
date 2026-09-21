// ─────────────────────────────────────────────────────────────
// settings_conexion_aparato_acciones.dart — PART de settings_sheet_new.dart:
// lo que se puede hacer con un aparato de la lista.
//
// Dos cosas: la fila de sacar (con el MOTIVO traducido cuando no se puede,
// por ejemplo si ese aparato no está conectado ahora) y el diálogo para
// renombrarlo. El aparato propio no lleva acciones: no te podés sacar a vos
// mismo.
//
// Se conecta con: settings_conexion_aparato_tarjeta.dart (la tarjeta) +
// settings_conexion_aparato.dart (los ayudantes de texto) +
// servicio_conexion_reglas.
// Parte del flujo: Ajustes → Conexión.
// ─────────────────────────────────────────────────────────────

part of 'settings_sheet_new.dart';

/// Motivo por el que no se puede (si no sos el dueño) y el botón de sacar.
class _AccionesAparato extends StatelessWidget {
  final DispositivoConectado dispositivo;
  final bool esEste;
  final ServicioConexion servicio;
  final Color onBg;
  final Responsive r;
  final VoidCallback onCambio;

  const _AccionesAparato({
    required this.dispositivo,
    required this.esEste,
    required this.servicio,
    required this.onBg,
    required this.r,
    required this.onCambio,
  });

  @override
  Widget build(BuildContext context) {
    if (esEste) return const SizedBox.shrink();
    final t = AppLocalizations.of(context).conexion;
    final motivo = servicio.motivoParaQuitar(dispositivo);
    final puede = servicio.puedeQuitar(dispositivo);
    // Si no se puede sacar, el motivo lo explica; si se puede, no hay nada
    // que explicar y la fila queda solo con el botón.
    final texto = puede ? '' : _textoConexion(t, motivo!);

    return Padding(
      padding: EdgeInsets.only(top: r.spacingXS),
      child: Row(
        children: [
          Expanded(
            child: Text(
              texto,
              style: TextStyle(
                fontSize: r.footerSize - 2,
                color: onBg.withValues(alpha: 0.4),
              ),
            ),
          ),
          if (puede)
            TextButton(
              onPressed: () async {
                await servicio.quitar(dispositivo.id);
                onCambio();
              },
              child: Text(t.sacar),
            ),
        ],
      ),
    );
  }
}

/// Pide un nombre nuevo para [dispositivo] y lo guarda.
Future<void> _pedirNombreAparato(
  BuildContext context,
  ServicioConexion servicio,
  DispositivoConectado dispositivo,
  VoidCallback onCambio,
) async {
  final t = AppLocalizations.of(context).conexion;
  final campo = TextEditingController(text: dispositivo.nombre);
  final nuevo = await mostrarDialogo<String>(
    context: context,
    builder:
        (ctx) => AlertDialog(
          title: Text(t.renombrar),
          content: TextField(controller: campo, autofocus: true),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text(t.cancelar),
            ),
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(campo.text),
              child: Text(t.renombrar),
            ),
          ],
        ),
  );
  final limpio = nuevo?.trim() ?? '';
  if (limpio.isEmpty) return;
  await servicio.renombrar(dispositivo.id, limpio);
  onCambio();
}
