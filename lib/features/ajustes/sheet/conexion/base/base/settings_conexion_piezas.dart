// ─────────────────────────────────────────────────────────────
// settings_conexion_piezas.dart — PART de settings_sheet_new.dart: las
// piezas de texto simples de la pestaña Conexión.
//
// Por ahora es una sola: el encabezado/explicación corta
// (`_AyudaSeccion`), que sirve tanto para abrir la pestaña como para la
// nota al pie. Se sacó de la pestaña para que cada archivo haga una sola
// cosa y ninguno pase de 150 líneas.
//
// Se conecta con: settings_conexion_tab.dart (la pestaña la usa).
// Parte del flujo: Ajustes → Conexión.
// ─────────────────────────────────────────────────────────────

part of '../../../settings_sheet_new.dart';

/// El cierre de la pestaña: el botón de agregar, la prueba (solo free) y la
/// nota del paso que sigue. Va junto para que la pestaña quede corta y solo
/// ordene: aviso, cupo, aparatos y este cierre.
class _ColaConexion extends StatelessWidget {
  final ServicioConexion servicio;
  final Color glowColor;
  final Color onBg;
  final Responsive r;
  final VoidCallback onCambio;

  const _ColaConexion({
    required this.servicio,
    required this.glowColor,
    required this.onBg,
    required this.r,
    required this.onCambio,
  });

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context).conexion;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _BotonAgregar(servicio: servicio, onBg: onBg, r: r, onCambio: onCambio),
        if (!servicio.esPremium) ...[
          SizedBox(height: r.spacingS),
          _TarjetaTrial(
            servicio: servicio,
            glowColor: glowColor,
            onBg: onBg,
            r: r,
            onCambio: onCambio,
          ),
        ],
        SizedBox(height: r.spacingS),
        // El aviso del paso que sigue: la lista hoy es la declaración de la
        // cuenta; el vínculo real entre aparatos llega después.
        _AyudaSeccion(texto: loc.proximoPaso, onBg: onBg, r: r),
      ],
    );
  }
}

/// Esqueleto de la pestaña Conexión: la silueta del cupo y de las filas de
/// aparatos, con los mismos aire y radio que el contenido real.
///
/// No es una ruedita: la ruedita no dice qué va a aparecer, y al llegar los
/// aparatos el contenido salta de la nada. Acá la forma ya está puesta.
class _EsqueletoConexion extends StatelessWidget {
  final Color glowColor;
  final Responsive r;

  const _EsqueletoConexion({required this.glowColor, required this.r});

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    padding: EdgeInsets.all(r.spacingL),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // La tarjeta del cupo.
        EsqueletoCarga(alto: r.spacingL * 3, radioBorde: 16),
        SizedBox(height: r.spacingS),
        // Dos aparatos declarados en la cuenta.
        for (var i = 0; i < 2; i++) ...[
          if (i > 0) SizedBox(height: r.spacingS),
          Row(
            children: [
              EsqueletoCarga(
                ancho: r.spacingL * 1.6,
                alto: r.spacingL * 1.6,
                radioBorde: 12,
              ),
              SizedBox(width: r.spacingS),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    EsqueletoCarga(alto: r.footerSize, radioBorde: 6),
                    SizedBox(height: r.spacingXS),
                    FractionallySizedBox(
                      alignment: Alignment.centerLeft,
                      widthFactor: 0.45,
                      child: EsqueletoCarga(
                        alto: r.footerSize,
                        radioBorde: 6,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
        SizedBox(height: r.spacingM),
        // El bloque de los aparatos de la misma red.
        EsqueletoCarga(alto: r.spacingL * 3, radioBorde: 16),
      ],
    ),
  );
}

/// Encabezado corto que explica de qué va la pestaña o una nota al pie.
class _AyudaSeccion extends StatelessWidget {
  final String texto;
  final Color onBg;
  final Responsive r;

  const _AyudaSeccion({
    required this.texto,
    required this.onBg,
    required this.r,
  });

  @override
  Widget build(BuildContext context) => Text(
    texto,
    style: TextStyle(
      fontSize: r.footerSize,
      color: onBg.withValues(alpha: 0.55),
      height: 1.35,
    ),
  );
}
