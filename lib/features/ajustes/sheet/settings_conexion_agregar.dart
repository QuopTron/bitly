// ─────────────────────────────────────────────────────────────
// settings_conexion_agregar.dart — PART de settings_sheet_new.dart: el
// botón de "Agregar aparato" y su diálogo de alta.
//
// Un aparato declarado a mano queda SIN VINCULAR: existe en la lista (el
// dueño le reserva el lugar) pero no cuenta como conectado hasta que se
// empareje. El botón se deshabilita cuando no sos el dueño o no hay cupo, y
// en ese caso muestra el motivo traducido.
//
// Se conecta con: settings_conexion_tab.dart (la pestaña) +
// settings_conexion_aparato.dart (los ayudantes de texto) +
// servicio_conexion_reglas.
// Parte del flujo: Ajustes → Conexión (alta declarada de un aparato).
// ─────────────────────────────────────────────────────────────

part of 'settings_sheet_new.dart';

/// Botón para declarar un aparato nuevo (queda sin vincular).
class _BotonAgregar extends StatelessWidget {
  final ServicioConexion servicio;
  final Color onBg;
  final Responsive r;
  final VoidCallback onCambio;

  const _BotonAgregar({
    required this.servicio,
    required this.onBg,
    required this.r,
    required this.onCambio,
  });

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context).conexion;
    final motivo = servicio.motivoParaAgregar();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: motivo == null ? () => _abrirAlta(context) : null,
            icon: const Icon(Icons.add_rounded, size: 18),
            label: Text(t.agregar),
          ),
        ),
        if (motivo != null)
          Padding(
            padding: EdgeInsets.only(top: r.spacingXS),
            child: Text(
              _textoConexion(t, motivo),
              style: TextStyle(
                fontSize: r.footerSize - 2,
                color: onBg.withValues(alpha: 0.45),
              ),
            ),
          ),
        Padding(
          padding: EdgeInsets.only(top: r.spacingXS),
          child: Text(
            t.notaPendiente,
            style: TextStyle(
              fontSize: r.footerSize - 2,
              color: onBg.withValues(alpha: 0.35),
            ),
          ),
        ),
      ],
    );
  }

  /// Pide nombre y tipo, y declara el aparato (sin vincular todavía).
  void _abrirAlta(BuildContext context) {
    final t = AppLocalizations.of(context).conexion;
    var tipo = TipoDispositivo.extra;
    final nombre =
        TextEditingController(); // Se abre con el helper: si ya hay un modal abajo (Ajustes), el velo
    // lo tapa entero y no se ven dos modales a la vez.
    mostrarDialogo<void>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: Text(t.agregar),
            content: StatefulBuilder(
              builder:
                  (ctx, setState) => Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextField(
                        controller: nombre,
                        decoration: InputDecoration(
                          hintText: _nombreTipo(t, tipo),
                        ),
                      ),
                      SizedBox(height: r.spacingS),
                      Wrap(
                        spacing: r.spacingXS,
                        children: [
                          for (final op in TipoDispositivo.values)
                            ChoiceChip(
                              label: Text(_nombreTipo(t, op)),
                              selected: tipo == op,
                              onSelected: (_) => setState(() => tipo = op),
                            ),
                        ],
                      ),
                    ],
                  ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: Text(t.cancelar),
              ),
              FilledButton(
                onPressed: () async {
                  final id = 'dev_${DateTime.now().microsecondsSinceEpoch}';
                  await servicio.agregar(
                    nombre:
                        nombre.text.trim().isEmpty
                            ? _nombreTipo(t, tipo)
                            : nombre.text,
                    tipo: tipo,
                    id: id,
                  );
                  if (ctx.mounted) Navigator.of(ctx).pop();
                  onCambio();
                },
                child: Text(t.agregar),
              ),
            ],
          ),
    );
  }
}
