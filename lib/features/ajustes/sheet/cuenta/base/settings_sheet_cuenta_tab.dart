// ─────────────────────────────────────────────────────────────
// settings_sheet_cuenta_tab.dart — PART de settings_sheet_new.dart:
// pestaña Cuenta de Ajustes.
//
// Agrupa lo que es TU cuenta y nada más: el plan (gratis/prueba/premium),
// el tiempo de prueba que queda y la conexión con Google. Antes vivía
// apretado dentro de "Más"; ahora tiene su propia burbuja.
//
// Se conecta con: settings_sheet_premium_card.dart,
// settings_sheet_more_cards.dart (tarjeta de Google) + CacheAjustes.
// Parte del flujo: Ajustes → Cuenta.
// ─────────────────────────────────────────────────────────────

part of '../../settings_sheet_new.dart';

class _CuentaTab extends StatefulWidget {
  final Color glowColor;
  final EstadoPremium? premium;
  final Future<void> Function() onPremiumChanged;

  const _CuentaTab({
    required this.glowColor,
    this.premium,
    required this.onPremiumChanged,
  });

  @override
  State<_CuentaTab> createState() => _CuentaTabState();
}

class _CuentaTabState extends State<_CuentaTab> {
  String? _trialRemaining;

  @override
  void initState() {
    super.initState();
    _cargarPrueba();
  }

  /// Horas y minutos que le quedan a la prueba gratis en modo `free`.
  Future<void> _cargarPrueba() async {
    try {
      final setup = await sl<CacheAjustes>().cargarDatosSetup();
      if (setup == null ||
          setup.mode != 'free' ||
          setup.trialExpiraEn == null) {
        return;
      }
      final expira = DateTime.tryParse(setup.trialExpiraEn!);
      if (expira == null) return;
      final resta = expira.difference(DateTime.now());
      if (!mounted) return;
      // 'EXPIRADO' es el centinela interno: nunca se muestra tal cual, el
      // texto visible lo traduce cada tarjeta que lo recibe.
      if (resta.isNegative) {
        setState(() => _trialRemaining = 'EXPIRADO');
      } else {
        final h = resta.inHours;
        final m = resta.inMinutes % 60;
        final loc = AppLocalizations.of(context);
        setState(
          () =>
              _trialRemaining = loc.ajustes.trialRestante(
                h,
                m,
                en: loc.locale.languageCode == 'en',
              ),
        );
      }
    } catch (e) {
      debugPrint("[Feature] $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = Responsive(context);
    final t = AppLocalizations.of(context).ajustes;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(r.spacingL, r.spacingS, r.spacingL, 0),
          child: _TituloApartado(
            titulo: t.cuenta,
            bajada: t.cuentaAyuda,
            glowColor: widget.glowColor,
          ),
        ),
        Expanded(
          child: CarruselAjustes(
            key: const ValueKey('carrusel-cuenta'),
            etiqueta: t.cuenta,
            glowColor: widget.glowColor,
            onBg: ColoresApp.enSuperficie(
              Theme.of(context).brightness == Brightness.dark,
            ),
            r: r,
            paginas: [
              _PremiumCardWidget(
                glowColor: widget.glowColor,
                premium: widget.premium,
                trialRemaining: _trialRemaining,
                onPremiumChanged: widget.onPremiumChanged,
              ),
              _GoogleConnectionCard(glowColor: widget.glowColor),
            ],
          ),
        ),
      ],
    );
  }
}
