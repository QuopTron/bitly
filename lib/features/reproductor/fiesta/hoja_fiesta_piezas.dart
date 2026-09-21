// ─────────────────────────────────────────────────────────────
// hoja_fiesta_piezas.dart — PART de hoja_fiesta.dart: las piezas chicas de la
// hoja: el tirador, la cabecera con la bola disco, los avisos (cortos y
// largos) y los chips de los aparatos que están sonando.
//
// Todas reciben el Responsive y el color de fondo ya resueltos, así ninguna
// tiene que saber si la app está en claro u oscuro.
//
// Se conecta con: hoja_fiesta_panel.dart + hoja_fiesta_cuerpos.dart (las usan).
// Parte del flujo: reproductor → modo fiesta.
// ─────────────────────────────────────────────────────────────

part of 'hoja_fiesta.dart';

/// El tirador de la hoja.
class _TiradorFiesta extends StatelessWidget {
  final Responsive r;
  final Color onBg;

  const _TiradorFiesta({required this.r, required this.onBg});

  @override
  Widget build(BuildContext context) => Center(
    child: Container(
      width: r.val(38, 30, 54),
      height: 4,
      decoration: BoxDecoration(
        color: onBg.withValues(alpha: 0.25),
        borderRadius: BorderRadius.circular(2),
      ),
    ),
  );
}

/// Icono de bola disco + título, para que se entienda de qué se trata.
class _CabeceraFiesta extends StatelessWidget {
  final Responsive r;
  final bool oscuro;

  const _CabeceraFiesta({required this.r, required this.oscuro});

  @override
  Widget build(BuildContext context) {
    final fg = ColoresApp.enSuperficie(oscuro);
    return Row(
      children: [
        Icon(Icons.nightlife_rounded, size: r.subtitleSize + 8, color: fg),
        SizedBox(width: r.spacingS),
        Text(
          AppLocalizations.of(context).fiesta.titulo,
          style: TextStyle(
            fontSize: r.titleSize,
            fontWeight: FontWeight.w700,
            color: fg,
          ),
        ),
      ],
    );
  }
}

/// Un texto de ayuda de la hoja, con su color ya elegido por quien lo monta.
class _AyudaFiesta extends StatelessWidget {
  final String texto;
  final Color onBg;
  final Responsive r;

  const _AyudaFiesta({
    required this.texto,
    required this.onBg,
    required this.r,
  });

  @override
  Widget build(BuildContext context) => Text(
    texto,
    style: TextStyle(fontSize: r.footerSize, color: onBg, height: 1.35),
  );
}

/// Aviso corto (por qué no entra, o qué falta para armar la fiesta).
class _AvisoFiesta extends StatelessWidget {
  final String texto;
  final Responsive r;
  final bool oscuro;

  const _AvisoFiesta({
    required this.texto,
    required this.r,
    required this.oscuro,
  });

  @override
  Widget build(BuildContext context) => Text(
    texto,
    style: TextStyle(
      fontSize: r.footerSize,
      color: ColoresApp.enSuperficieApagado(oscuro),
      height: 1.3,
    ),
  );
}

/// Los aparatos que ya están sonando con nosotros.
class _ChipsUnidos extends StatelessWidget {
  final List<String> nombres;
  final Responsive r;
  final bool oscuro;

  const _ChipsUnidos({
    required this.nombres,
    required this.r,
    required this.oscuro,
  });

  @override
  Widget build(BuildContext context) => Wrap(
    spacing: r.spacingXS,
    runSpacing: r.spacingXS,
    children: [
      for (final n in nombres)
        Chip(
          avatar: const Icon(Icons.speaker_rounded, size: 16),
          label: Text(n.isEmpty ? '—' : n),
          labelStyle: TextStyle(fontSize: r.footerSize),
          visualDensity: VisualDensity.compact,
        ),
    ],
  );
}
