// ─────────────────────────────────────────────────────────────
// settings_compartidos_lista.dart — PART de settings_sheet_new.dart:
// la sección "quién te compartió qué" de la pestaña Estadísticas:
// título, botón de borrar y las filas de cada envío recibido.
//
// Va aparte de settings_compartidos_tab.dart para que el tab solo
// arme la pestaña (resumen + niveles + esta lista) y este archivo se
// ocupe de la lista.
//
// Se conecta con: settings_sheet_new.dart (misma library) +
// settings_compartidos_tab.dart (la usa) + settings_compartidos_fila.
// Parte del flujo: Ajustes → Estadísticas (compartidos recibidos).
// ─────────────────────────────────────────────────────────────

part of 'settings_sheet_new.dart';

/// Título + filas de los compartidos recibidos. Vacío muestra el aviso.
class _ListaCompartidos extends StatelessWidget {
  final List<CompartidoRecibido> items;
  final Color glowColor;
  final Color onBg;
  final Responsive r;
  final VoidCallback onBorrar;
  final void Function(CompartidoRecibido) onTocar;

  const _ListaCompartidos({
    required this.items,
    required this.glowColor,
    required this.onBg,
    required this.r,
    required this.onBorrar,
    required this.onTocar,
  });

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context).setup;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                l.compartidosLabel,
                style: TextStyle(
                  fontSize: r.subtitleSize,
                  fontWeight: FontWeight.w700,
                  color: onBg.withValues(alpha: 0.9),
                ),
              ),
            ),
            if (items.isNotEmpty)
              TextButton(
                onPressed: onBorrar,
                child: Text(l.compartidosBorrar),
              ),
          ],
        ),
        if (items.isEmpty)
          _vacio(r, l.compartidosVacio)
        else
          for (final entrada in items) ...[
            _filaCompartido(
              context,
              r,
              entrada,
              onTap: () => onTocar(entrada),
            ),
            SizedBox(height: r.spacingS),
          ],
      ],
    );
  }
}
