// ─────────────────────────────────────────────────────────────
// settings_sheet_appearance_tipografia.dart — PART de settings_sheet_new.dart:
// la tarjeta "Tipografía" de Ajustes → Apariencia.
//
// Es la única puerta a la tipografía de la app: muestra cómo se ve la elegida
// (previa en vivo), el catálogo con lo que ya se puede usar y lo que falta, y
// permite bajar una nueva (que se registra al vuelo) o volver a la de fábrica.
//
// Resuelve el desbloqueo UNA vez con las horas de escucha y la versión de la
// app —la misma escalera que el cofre de barras— y se lo pasa a cada pieza.
//
// Se conecta con: catalogo_fuentes + ServicioFuentes + apariencia_helper
// (fuenteId) + las piezas (_previa, _fila, _marca).
// Parte del flujo: Ajustes → Apariencia → Tipografía.
// ─────────────────────────────────────────────────────────────

part of '../../../settings_sheet_new.dart';

/// Tarjeta "Tipografía": la elegida, la previa y el catálogo.
class _FuentesCard extends StatefulWidget {
  final Color glowColor;
  final Color onBg;
  final Responsive r;
  final AppLocalizations loc;

  const _FuentesCard({
    super.key,
    required this.glowColor,
    required this.onBg,
    required this.r,
    required this.loc,
  });

  @override
  State<_FuentesCard> createState() => _FuentesCardState();
}

class _FuentesCardState extends State<_FuentesCard> {
  /// Horas escuchadas y versión de la app: con eso se resuelve qué se abrió.
  int _horas = 0;
  int _version = 0;

  /// Se apaga solo: confirma que se liberó espacio sin abrir un aviso aparte.
  bool _liberado = false;

  @override
  void initState() {
    super.initState();
    _cargarProgreso();
  }

  /// Lee las horas de escucha y la versión. Best-effort: si algo falla, el
  /// catálogo se muestra sólo con lo libre (nunca queda una fuente fantasma).
  Future<void> _cargarProgreso() async {
    var horas = 0;
    var version = 0;
    try {
      final stats = await sl<ReproduccionStats>().getStatsUsuario();
      horas = stats.totalTiempoReproducidoMs ~/ 3600000;
    } catch (e) {
      debugPrint("[Fuentes] $e");
    }
    try {
      final pkg = await PackageInfo.fromPlatform();
      version = versionEnNumero(pkg.version);
    } catch (e) {
      debugPrint("[Fuentes] $e");
    }
    if (!mounted) return;
    setState(() {
      _horas = horas;
      _version = version;
    });
  }

  /// Elige una fuente: guarda la preferencia y pide su activación (que la baja
  /// si hace falta y registra la familia para el tema).
  ///
  /// Elegir la que ya está puesta REINTENTA: es la salida natural cuando una
  /// bajada falló y el usuario quiere probar de nuevo.
  void _elegir(FuenteApp fuente) {
    Haptico.medio();
    final prefs = AparienciaHelper.actual(context);
    if (fuentePorId(prefs.fuenteId)?.id == fuente.id) {
      ServicioFuentes.instancia.reintentar(fuente.id);
      return;
    }
    // La empaquetada se guarda como '' para que "Restablecer" siga dejando el
    // diseño de fábrica y no una elección aparente.
    final id = fuente.empaquetada ? '' : fuente.id;
    AparienciaHelper.cambiar(context, prefs.copiarCon(fuenteId: id));
    ServicioFuentes.instancia.activar(fuente.id);
  }

  Future<void> _liberar() async {
    Haptico.tap();
    await ServicioFuentes.instancia.liberarDescargadas();
    if (!mounted) return;
    setState(() => _liberado = true);
    Timer(const Duration(seconds: 4), () {
      if (mounted) setState(() => _liberado = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.loc.fuentes;
    final r = widget.r;
    final onBg = widget.onBg;
    return ValueListenableBuilder<EstadoFuente>(
      valueListenable: ServicioFuentes.estado,
      builder:
          (context, estado, _) => ValueListenableBuilder<PreferenciasApariencia>(
            valueListenable: AparienciaHelper.notifier(),
            builder:
                (context, prefs, _) =>
                    // La familia activa se escucha también: cuando una bajada
                    // termina de registrarse, la previa y cada muestra se
                    // repintan sin cerrar Ajustes.
                    ValueListenableBuilder<String?>(
                      valueListenable: sl<ValueNotifier<String?>>(),
                      builder:
                          (context, _, _) => ContenedorVidrio(
                            borderRadius: 16,
                            borderColor: onBg.withValues(alpha: 0.08),
                            bgColor: onBg.withValues(alpha: 0.03),
                            padding: EdgeInsets.all(r.spacingM),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _encabezado(t),
                                SizedBox(height: r.spacingS),
                                _PreviaFuente(
                                  r: r,
                                  onBg: onBg,
                                  titulo: t.previaTitulo,
                                  texto: t.previaTexto,
                                ),
                                SizedBox(height: r.spacingS),
                                for (final f in catalogoFuentes)
                                  _fila(f, prefs, t, estado),
                                if (estado == EstadoFuente.sinRed ||
                                    estado == EstadoFuente.error) ...[
                                  SizedBox(height: r.spacingS),
                                  _AvisoBajada(
                                    r: r,
                                    onBg: onBg,
                                    glowColor: widget.glowColor,
                                    texto: t.sinRed,
                                    accion: t.reintentar,
                                    onReintentar:
                                        () => ServicioFuentes.instancia
                                            .reintentar(
                                              AparienciaHelper.actual(
                                                context,
                                              ).fuenteId,
                                            ),
                                  ),
                                ],
                                _liberarFila(t, r),
                              ],
                            ),
                          ),
                    ),
          ),
    );
  }

  /// Encabezado con el nombre del bloque y su bajada (mismo molde que Barras).
  Widget _encabezado(StringsFuentes t) => Row(
    children: [
      Icon(
        Icons.text_fields_rounded,
        color: widget.glowColor,
        size: widget.r.subtitleSize,
      ),
      SizedBox(width: widget.r.spacingS),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              t.titulo,
              style: TextStyle(
                fontSize: widget.r.subtitleSize,
                fontWeight: FontWeight.w700,
                color: widget.onBg,
              ),
            ),
            Text(
              t.ayuda,
              style: TextStyle(
                fontSize: widget.r.footerSize - 2,
                color: widget.onBg.withValues(alpha: 0.45),
              ),
            ),
          ],
        ),
      ),
    ],
  );

  /// Una fila del catálogo, con su estado ya resuelto.
  Widget _fila(
    FuenteApp f,
    PreferenciasApariencia prefs,
    StringsFuentes t,
    EstadoFuente estado,
  ) {
    // Se compara por FUENTE, no por texto guardado: '' y 'google_sans' son la
    // misma (la de la app), y así la fila nunca queda sin tilde.
    final enUso = fuentePorId(prefs.fuenteId)?.id == f.id;
    final desbloqueada = fuenteDesbloqueada(
      f,
      horas: _horas,
      version: _version,
    );
    final bajando = enUso && estado == EstadoFuente.descargando;
    return _FilaFuente(
      fuente: f,
      r: widget.r,
      onBg: widget.onBg,
      glowColor: widget.glowColor,
      nombre: t.nombre(f.id),
      estado: _textoEstado(f, t, enUso: enUso, desbloqueada: desbloqueada, bajando: bajando),
      enUso: enUso,
      desbloqueada: desbloqueada,
      bajando: bajando,
      onTap: () => _elegir(f),
    );
  }

  /// Qué dice la segunda línea de la fila.
  String _textoEstado(
    FuenteApp f,
    StringsFuentes t, {
    required bool enUso,
    required bool desbloqueada,
    required bool bajando,
  }) {
    if (bajando) return t.descargando;
    if (enUso) return t.enUso;
    if (desbloqueada) return t.usar;
    if (f.desbloqueo == DesbloqueoFuente.horas) return t.horas(f.valor);
    return t.llegaConVersion(versionLegible(f.valor));
  }

  /// Botón para borrar las tipografías bajadas (liberar espacio).
  Widget _liberarFila(StringsFuentes t, Responsive r) => Align(
    alignment: Alignment.centerLeft,
    child: GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _liberar,
      child: Padding(
        padding: EdgeInsets.only(top: r.spacingXS),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.delete_outline_rounded,
              size: r.footerSize + 2,
              color: widget.onBg.withValues(alpha: 0.45),
            ),
            SizedBox(width: r.spacingXS),
            Text(
              _liberado ? t.liberado : t.liberar,
              style: TextStyle(
                fontSize: r.footerSize - 1,
                color:
                    _liberado
                        ? widget.glowColor
                        : widget.onBg.withValues(alpha: 0.45),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
