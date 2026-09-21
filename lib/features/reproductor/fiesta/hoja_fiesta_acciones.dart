// ─────────────────────────────────────────────────────────────
// hoja_fiesta_acciones.dart — PART de hoja_fiesta.dart: lo que el usuario
// puede TOCAR en la hoja: el botón grande (armar, cortar, salir) y la fila de
// un aparato con su botón de sumarse a la fiesta.
//
// Las dos se apagan solas mientras hay una acción en curso, así dos toques
// seguidos no disparan dos veces lo mismo.
//
// Se conecta con: hoja_fiesta_cuerpos.dart (las monta).
// Parte del flujo: reproductor → modo fiesta.
// ─────────────────────────────────────────────────────────────

part of 'hoja_fiesta.dart';


/// Botón grande de la hoja (armar, cortar, salir).
class _BotonFiesta extends StatelessWidget {
  final String texto;
  final IconData icono;
  final bool ocupado;
  final Future<void> Function() onTap;

  const _BotonFiesta({
    required this.texto,
    required this.icono,
    required this.ocupado,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => SizedBox(
    width: double.infinity,
    child: FilledButton.icon(
      onPressed: ocupado ? null : () => onTap(),
      icon: Icon(icono, size: 18),
      label: Text(texto),
    ),
  );
}

/// Un aparato vinculado, con el botón para sumarse a su fiesta.
class _FilaUnirse extends StatelessWidget {
  final ParLan par;
  final Responsive r;
  final bool oscuro;
  final bool ocupado;
  final VoidCallback onUnirse;

  const _FilaUnirse({
    required this.par,
    required this.r,
    required this.oscuro,
    required this.ocupado,
    required this.onUnirse,
  });

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.only(bottom: r.spacingXS),
    child: Row(
      children: [
        Icon(
          Icons.speaker_group_rounded,
          size: r.subtitleSize + 4,
          color: ColoresApp.enSuperficieApagado(oscuro),
        ),
        SizedBox(width: r.spacingS),
        Expanded(
          child: Text(
            par.nombre.isEmpty ? par.host : par.nombre,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: r.footerSize,
              color: ColoresApp.enSuperficie(oscuro),
            ),
          ),
        ),
        TextButton(
          onPressed: ocupado ? null : onUnirse,
          child: Text(AppLocalizations.of(context).fiesta.unirse),
        ),
      ],
    ),
  );
}
