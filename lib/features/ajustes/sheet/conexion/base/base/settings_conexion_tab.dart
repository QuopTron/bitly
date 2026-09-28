// ─────────────────────────────────────────────────────────────
// settings_conexion_tab.dart — PART de settings_sheet_new.dart: la
// pestaña CONEXIÓN de Ajustes.
//
// Muestra los cuatro lugares de la cuenta (este aparato es el que controla),
// el vínculo real con los aparatos de la misma red, el aviso de novedades y
// la prueba de 9 horas. Cuando una acción no se puede, se explica el MOTIVO
// en el idioma del usuario (el texto sale de la l10n, nunca del servicio).
//
// Se conecta con: settings_sheet_new.dart (misma library) + servicio_conexion.
// Parte del flujo: Ajustes → Conexión.
// ─────────────────────────────────────────────────────────────

part of '../../../settings_sheet_new.dart';

/// Pestaña Conexión: los aparatos de la cuenta y la prueba de 9 horas.
class _ConexionTab extends StatefulWidget {
  final Color glowColor;
  final Color onBg;
  final Responsive r;

  const _ConexionTab({
    required this.glowColor,
    required this.onBg,
    required this.r,
  });

  @override
  State<_ConexionTab> createState() => _ConexionTabState();
}

class _ConexionTabState extends State<_ConexionTab> {
  ServicioConexion? _servicio;

  /// Lo que había de nuevo AL ABRIR. Se guarda acá porque al entrar ya se
  /// marcan como vistas y el aviso se apagaría antes de que se lea.
  List<NovedadConexion> _novedades = const [];

  /// Repinta cada medio minuto para que el restante de la prueba avise sin
  /// tener que cerrar y abrir Ajustes (el tiempo se calcula, no se acumula).
  Timer? _reloj;

  @override
  void initState() {
    super.initState();
    _reloj = Timer.periodic(
      const Duration(seconds: 30),
      (_) => mounted ? setState(() {}) : null,
    );
    _cargar();
  }

  @override
  void dispose() {
    _reloj?.cancel();
    super.dispose();
  }

  /// Trae el estado de la conexión. Se refresca el plan porque el usuario
  /// pudo activar Premium con la hoja ya abierta.
  Future<void> _cargar() async {
    final servicio = sl<ServicioConexion>();
    await servicio.refrescarPlan();
    if (!servicio.cargado) await servicio.cargar();
    final novedades = servicio.novedades;
    // Abrir la pestaña es lo que apaga el mininumerito: el aviso queda a la
    // vista en esta visita y la próxima ya no molesta.
    await servicio.marcarNovedadesVistas();
    novedadesConexion.value = servicio.novedadesNuevas;
    if (mounted) {
      setState(() {
        _servicio = servicio;
        _novedades = novedades;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context).conexion;
    final t = AppLocalizations.of(context).ajustes;
    final servicio = _servicio;
    final r = widget.r;
    // Mientras el servicio no contestó se muestra la silueta de la pestaña
    // (la tarjeta del cupo y las filas de aparatos) y no una ruedita: ya se ve
    // qué va a aparecer y al llegar los datos nada salta de lugar.
    if (servicio == null) {
      return _EsqueletoConexion(glowColor: widget.glowColor, r: r);
    }
    final ahora = DateTime.now().millisecondsSinceEpoch;
    void pintar() => setState(() {});

    // Tres preguntas distintas, tres páginas: ¿qué aparatos hay en mi cuenta?,
    // ¿cuáles se ven en mi red? y ¿qué está viajando? Apiladas obligaban a
    // bajar hasta el final para ver la cola.
    return CarruselAjustes(
      key: const ValueKey('carrusel-conexion'),
      etiqueta: t.conexion,
      glowColor: widget.glowColor,
      onBg: widget.onBg,
      r: r,
      paginas: [
        // Página 1: la cuenta y sus aparatos.
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_novedades.isNotEmpty) ...[
              _AvisoNovedades(
                novedades: _novedades,
                glowColor: widget.glowColor,
                onBg: widget.onBg,
                r: r,
              ),
              SizedBox(height: r.spacingS),
            ],
            _AyudaSeccion(texto: loc.ayuda, onBg: widget.onBg, r: r),
            SizedBox(height: r.spacingS),
            _TarjetaCupo(
              servicio: servicio,
              glowColor: widget.glowColor,
              onBg: widget.onBg,
              r: r,
            ),
            SizedBox(height: r.spacingS),
            for (final d in servicio.dispositivos)
              Padding(
                padding: EdgeInsets.only(bottom: r.spacingS),
                child: _TarjetaAparato(
                  dispositivo: d,
                  servicio: servicio,
                  ahoraMs: ahora,
                  glowColor: widget.glowColor,
                  onBg: widget.onBg,
                  r: r,
                  onCambio: pintar,
                ),
              ),
            if (servicio.dispositivos.length == 1)
              _AyudaSeccion(texto: loc.vacio, onBg: widget.onBg, r: r),
          ],
        ),
        // Página 2: el vínculo de verdad, los aparatos de la misma red.
        _RedConexion(
          servicio: servicio,
          glowColor: widget.glowColor,
          onBg: widget.onBg,
          r: r,
        ),
        // Página 3: lo que está viajando.
        _ColaConexion(
          servicio: servicio,
          glowColor: widget.glowColor,
          onBg: widget.onBg,
          r: r,
          onCambio: pintar,
        ),
      ],
    );
  }
}
