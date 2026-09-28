// ─────────────────────────────────────────────────────────────
// settings_sheet_appearance_vistas.dart — PART de settings_sheet_new.dart: la
// tarjeta "Diseño por vista" de Ajustes → Apariencia.
//
// Es el salto de la v1.0.0: hasta ahora el diseño se elegía UNA vez para toda
// la app. Acá se elige una pantalla y se le cambian sus ejes —tipografía,
// redondeo de las tarjetas y aire— mientras el resto sigue como estaba.
//
// Reglas que respeta:
//   · lo que no se toca se HEREDA del estilo global, y se dice cuál es
//     ("Heredado" / "Propio"), así nunca queda la duda de quién manda;
//   · sólo se ofrecen las tipografías que el usuario YA desbloqueó: las horas
//     de escucha valen igual acá que en el catálogo;
//   · una tipografía que se está bajando o que no se pudo bajar se dice, en vez
//     de dejar la pantalla con una letra que no es la elegida y ningún motivo.
//
// Se conecta con: apariencia_vistas_helper (leer/guardar) + apariencia_helper
// (el estilo global del que hereda) + catalogo_fuentes + servicio_fuentes +
// diseno_vista (el modelo) + sus piezas (tira, controles y muestra).
// Parte del flujo: Ajustes → Apariencia → Vistas.
// ─────────────────────────────────────────────────────────────

part of '../../../settings_sheet_new.dart';

/// Los EJES que se pueden personalizar por vista.
///
/// Cada uno tiene su pestaña: con los cinco controles abiertos a la vez la
/// tarjeta era un rollo donde había que bajar mucho para llegar al último, y
/// encima se veían cuatro deslizadores juntos sin saber cuál movía qué.
/// El ORDEN es el de las pestañas.
enum _EjeVista {
  /// El color de las tarjetas (la paleta del cofre).
  color,

  /// La tipografía con la que se escribe la pantalla.
  letra,

  /// Cuánto se redondean las tarjetas.
  forma,

  /// Cuánto aire hay entre las cosas.
  aire,

  /// Cuántas columnas tiene la grilla.
  grilla,
}

/// Tarjeta "Diseño por vista": elegir pantalla y personalizarla.
class _VistasCard extends StatefulWidget {
  final Color glowColor;
  final Color onBg;
  final Responsive r;
  final AppLocalizations loc;

  const _VistasCard({
    super.key,
    required this.glowColor,
    required this.onBg,
    required this.r,
    required this.loc,
  });

  @override
  State<_VistasCard> createState() => _VistasCardState();
}

class _VistasCardState extends State<_VistasCard> {
  /// Vista que se está editando. Arranca en Inicio: casi siempre es la que se
  /// quiere, y así la tarjeta nunca se abre vacía.
  VistaApp _vista = VistaApp.feed;

  /// Pestaña de eje abierta. Arranca en COLOR: es el cambio que más se ve y el
  /// que se puede aplicar sin bajar nada, así que la tarjeta abre mostrando
  /// algo que hace efecto en el acto.
  _EjeVista _eje = _EjeVista.color;

  /// Horas escuchadas y versión: las mismas que abren las tipografías.
  int _horas = 0;
  int _version = 0;

  /// Se apaga solo: confirma el restablecimiento sin abrir un aviso encima de
  /// la hoja.
  bool _restablecida = false;

  /// El temporizador que apaga esa confirmación. Se guarda para cancelarlo: si
  /// la hoja se cierra antes, quedaría vivo intentando tocar un State muerto.
  Timer? _apagarConfirmacion;

  @override
  void initState() {
    super.initState();
    _cargarProgreso();
    // Se escuchan las cuatro cosas que cambian lo que se ve: lo que declaró
    // cada vista, el estilo global (del que hereda) y el estado de las
    // bajadas (en curso y terminadas).
    AparienciaVistas.notifier().addListener(_alCambiar);
    AparienciaHelper.notifier().addListener(_alCambiar);
    ServicioFuentes.generacion.addListener(_alCambiar);
    ServicioFuentes.bajando.addListener(_alCambiar);
  }

  @override
  void dispose() {
    _apagarConfirmacion?.cancel();
    AparienciaVistas.notifier().removeListener(_alCambiar);
    AparienciaHelper.notifier().removeListener(_alCambiar);
    ServicioFuentes.generacion.removeListener(_alCambiar);
    ServicioFuentes.bajando.removeListener(_alCambiar);
    super.dispose();
  }

  void _alCambiar() {
    if (mounted) setState(() {});
  }

  /// Best-effort, igual que el catálogo: si algo falla se muestran sólo las
  /// tipografías libres, nunca una fantasma.
  Future<void> _cargarProgreso() async {
    var horas = 0;
    var version = 0;
    try {
      final stats = await sl<ReproduccionStats>().getStatsUsuario();
      horas = stats.totalTiempoReproducidoMs ~/ 3600000;
    } catch (e) {
      debugPrint('[Vistas] $e');
    }
    try {
      final pkg = await PackageInfo.fromPlatform();
      version = versionEnNumero(pkg.version);
    } catch (e) {
      debugPrint('[Vistas] $e');
    }
    if (!mounted) return;
    setState(() {
      _horas = horas;
      _version = version;
    });
  }

  /// Guarda el diseño de la vista que se está editando.
  void _poner(DisenoVista diseno) => AparienciaVistas.poner(_vista, diseno);

  /// Elige la tipografía de la vista ('' = heredar la global).
  ///
  /// La bajada se pide YA, aunque la pantalla no esté montada: si esperáramos a
  /// que el usuario entre, la vería primero con la letra vieja.
  void _elegirTipografia(String id) {
    Haptico.medio();
    _poner(AparienciaVistas.declarado(_vista).copiarCon(tipografiaId: id));
    unawaited(ServicioFuentes.instancia.asegurarFamilia(id));
  }

  void _restablecerVista() {
    Haptico.medio();
    AparienciaVistas.restablecer(_vista);
    setState(() => _restablecida = true);
    _apagarConfirmacion?.cancel();
    _apagarConfirmacion = Timer(const Duration(seconds: 4), () {
      if (mounted) setState(() => _restablecida = false);
    });
  }

  @override
  Widget build(BuildContext context) =>
      _tarjeta(context, AparienciaVistas.actual(), widget.loc.vistas);

  Widget _tarjeta(
    BuildContext context,
    PreferenciasVistas prefs,
    StringsVistas t,
  ) {
    final r = widget.r;
    final declarado = prefs.para(_vista);
    final resuelto = AparienciaVistas.de(context, _vista);
    // La separación de la vista es la global pasada por su densidad: es
    // exactamente lo que hace AparienciaEspacios, así que la muestra dice la
    // verdad y no una aproximación.
    final global = AparienciaHelper.actual(context);
    return ContenedorVidrio(
      borderRadius: 16,
      borderColor: widget.onBg.withValues(alpha: 0.08),
      bgColor: widget.onBg.withValues(alpha: 0.03),
      padding: EdgeInsets.all(r.spacingM),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _encabezado(t),
          SizedBox(height: r.spacingM),
          _TiraVistas(
            seleccionada: _vista,
            personalizadas: prefs.personalizadas.toSet(),
            t: t,
            r: r,
            onBg: widget.onBg,
            glowColor: widget.glowColor,
            onElegir: (v) => setState(() => _vista = v),
          ),
          SizedBox(height: r.spacingM),
          _VistasMuestra(
            radio: resuelto.radioTarjeta,
            espacioX: global.espacioX * resuelto.densidad,
            espacioY: global.espacioY * resuelto.densidad,
            paleta: resuelto.paleta,
            // La letra y el texto de la muestra: sin esto la previa diría el
            // color y la forma pero no la tipografía, que es medio control.
            familia:
                resuelto.tipografiaId.isEmpty
                    ? null
                    : familiaDeFuente(resuelto.tipografiaId),
            texto: widget.loc.fuentes.previaTexto,
            r: r,
            onBg: widget.onBg,
            glowColor: widget.glowColor,
          ),
          SizedBox(height: r.spacingM),
          // Las cinco pestañas de eje, con un punto en las que ESTA pantalla ya
          // tiene algo propio: de un vistazo se ve dónde se salió del diseño
          // general sin abrir una por una.
          _tiraEjes(declarado, t),
          SizedBox(height: r.spacingS),
          _cuerpoEje(declarado, resuelto, t),
          _pie(prefs, t),
        ],
      ),
    );
  }

  /// La tira de pestañas: un eje por pestaña.
  Widget _tiraEjes(DisenoVista declarado, StringsVistas t) {
    final r = widget.r;
    return Wrap(
      spacing: r.spacingXS,
      runSpacing: r.spacingXS,
      children: [
        for (final e in _EjeVista.values)
          _VistasChip(
            texto: _rotuloEje(e, t),
            seleccionado: e == _eje,
            marcada: _tienePropio(e, declarado),
            r: r,
            onBg: widget.onBg,
            glowColor: widget.glowColor,
            onTap: () => setState(() => _eje = e),
          ),
      ],
    );
  }

  /// El contenido de la pestaña abierta: un eje por vez.
  Widget _cuerpoEje(
    DisenoVista declarado,
    DisenoResuelto resuelto,
    StringsVistas t,
  ) => switch (_eje) {
    _EjeVista.color => _ejeCofre(declarado, t),
    _EjeVista.letra => _ejeTipografia(declarado, t),
    _EjeVista.forma => _ejeRadio(declarado, resuelto, t),
    _EjeVista.aire => _ejeDensidad(declarado, t),
    _EjeVista.grilla => _ejeColumnas(declarado, t),
  };

  /// Rótulo corto de la pestaña del eje.
  String _rotuloEje(_EjeVista e, StringsVistas t) => switch (e) {
    _EjeVista.color => t.ejeColor,
    _EjeVista.letra => t.ejeLetra,
    _EjeVista.forma => t.ejeForma,
    _EjeVista.aire => t.ejeAire,
    _EjeVista.grilla => t.ejeGrilla,
  };

  /// ¿Esta vista ya tiene algo PROPIO en ese eje? (el punto de la pestaña)
  bool _tienePropio(_EjeVista e, DisenoVista d) => switch (e) {
    _EjeVista.color => d.disenoId.isNotEmpty,
    _EjeVista.letra => d.tipografiaId.isNotEmpty,
    _EjeVista.forma => d.radioTarjeta != null,
    _EjeVista.aire => d.densidad != null,
    _EjeVista.grilla => d.columnasMax > 0,
  };

  Widget _encabezado(StringsVistas t) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Icon(
        Icons.dashboard_customize_outlined,
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

  /// Eje de tipografía: heredar + sólo las que el usuario ya desbloqueó.
  Widget _ejeTipografia(DisenoVista declarado, StringsVistas t) {
    final r = widget.r;
    final disponibles = fuentesDisponibles(horas: _horas, version: _version);
    final id = declarado.tipografiaId;
    final aviso = _avisoTipografia(id, t);
    return _VistasEje(
      rotulo: t.tipografia,
      propio: id.isNotEmpty,
      t: t,
      r: r,
      onBg: widget.onBg,
      glowColor: widget.glowColor,
      onHeredar: () => _elegirTipografia(''),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(height: r.spacingXS),
          Wrap(
            spacing: r.spacingXS,
            runSpacing: r.spacingXS,
            children: [
              _ChipOpcion(
                texto: t.heredar,
                seleccionado: id.isEmpty,
                r: r,
                onBg: widget.onBg,
                glowColor: widget.glowColor,
                onTap: () => _elegirTipografia(''),
              ),
              for (final f in disponibles)
                _ChipOpcion(
                  texto: widget.loc.fuentes.nombre(f.id),
                  seleccionado: fuentePorId(id)?.id == f.id,
                  familia: f.familia,
                  r: r,
                  onBg: widget.onBg,
                  glowColor: widget.glowColor,
                  onTap: () => _elegirTipografia(f.empaquetada ? '' : f.id),
                ),
            ],
          ),
          if (aviso != null) ...[
            SizedBox(height: r.spacingXS),
            Text(
              aviso,
              style: TextStyle(
                fontSize: r.footerSize - 2,
                color: widget.glowColor,
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// Qué avisar sobre la tipografía de esta vista (null = nada que decir).
  String? _avisoTipografia(String id, StringsVistas t) {
    if (id.isEmpty) return null;
    if (ServicioFuentes.instancia.estaBajando(id)) return t.bajandoTipografia;
    if (!ServicioFuentes.instancia.estaRegistrada(id)) return t.sinTipografia;
    return null;
  }

  /// Eje de COLOR de las tarjetas: la paleta del cofre que tiñe esta pantalla.
  ///
  /// El cofre es del aparato (la TV no ofrece las paletas del dedo), así que
  /// se ofrece el mismo catálogo que ya se ve en Barras y con las mismas reglas
  /// de apertura: lo bloqueado va con candado y con cómo se abre, no escondido
  /// —si no, el eje parecería roto al abrir la hoja recién instalada—.
  Widget _ejeCofre(DisenoVista declarado, StringsVistas t) {
    final r = widget.r;
    final cofre = widget.loc.cofre;
    final paleta = paletaDeDiseno(declarado.disenoId);
    // Sólo las que TIÑEN: una paleta sin colores sería un chip que no hace
    // nada, justo lo que este eje quiere evitar.
    final colores = coloresParaAparato(
      tipoDeEsteAparato(),
    ).where((d) => d.tienePaleta).toList(growable: false);
    return _VistasEje(
      rotulo: t.cofre,
      propio: paleta.isNotEmpty,
      t: t,
      r: r,
      onBg: widget.onBg,
      glowColor: widget.glowColor,
      onHeredar: () => _elegirCofre(''),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(height: r.spacingXS),
          Wrap(
            spacing: r.spacingXS,
            runSpacing: r.spacingXS,
            children: [
              _TilePaleta(
                colores: const [],
                texto: t.cofreCover,
                estado: paleta.isEmpty ? cofre.enUso : cofre.usar,
                seleccionado: paleta.isEmpty,
                abierto: true,
                r: r,
                onBg: widget.onBg,
                glowColor: widget.glowColor,
                onTap: () => _elegirCofre(''),
              ),
              for (final d in colores) _tileDePaleta(d, declarado, cofre),
            ],
          ),
          SizedBox(height: r.spacingXS + 2),
          Text(
            t.cofreAyuda,
            style: TextStyle(
              fontSize: r.footerSize - 2,
              color: widget.onBg.withValues(alpha: 0.45),
            ),
          ),
        ],
      ),
    );
  }

  /// Una paleta del cofre como opción de esta vista.
  Widget _tileDePaleta(
    DisenoBarra d,
    DisenoVista declarado,
    StringsCofrePaletas cofre,
  ) {
    final abierto = disenoDesbloqueado(d, horas: _horas, version: _version);
    final elegida = declarado.disenoId == d.id;
    return _TilePaleta(
      colores: [for (final c in d.paleta) Color(c)],
      texto: cofre.nombre(d.id),
      // El estado con el mismo vocabulario que el cofre: "En uso" / "Usar" y,
      // si todavía no se abrió, cómo se abre.
      estado: abierto ? (elegida ? cofre.enUso : cofre.usar) : _notaPaleta(d, cofre),
      seleccionado: elegida,
      abierto: abierto,
      r: widget.r,
      onBg: widget.onBg,
      glowColor: widget.glowColor,
      onTap: () => _elegirCofre(d.id),
    );
  }

  /// Cómo se abre una paleta bloqueada.
  String _notaPaleta(DisenoBarra d, StringsCofrePaletas cofre) =>
      switch (d.desbloqueo) {
        DesbloqueoBarra.horas => cofre.horas(d.valor),
        DesbloqueoBarra.version => cofre.llegaConVersion(versionLegible(d.valor)),
        DesbloqueoBarra.libre => cofre.usar,
      };

  /// Elige la paleta del cofre de esta vista ('' = volver al color del cover).
  void _elegirCofre(String id) {
    Haptico.medio();
    _poner(AparienciaVistas.declarado(_vista).copiarCon(disenoId: id));
  }

  /// Eje de redondeo de las tarjetas.
  Widget _ejeRadio(
    DisenoVista declarado,
    DisenoResuelto resuelto,
    StringsVistas t,
  ) {
    final valor = declarado.radioTarjeta ?? resuelto.radioTarjeta;
    return _VistasEje(
      rotulo: t.radio,
      propio: declarado.radioTarjeta != null,
      t: t,
      r: widget.r,
      onBg: widget.onBg,
      glowColor: widget.glowColor,
      onHeredar: () => _poner(declarado.copiarCon(borrarRadio: true)),
      child: _deslizador(
        valor: valor,
        min: DisenoVista.minRadio,
        max: DisenoVista.maxRadio,
        etiqueta: '${valor.round()}',
        onChanged: (v) => _poner(declarado.copiarCon(radioTarjeta: v)),
      ),
    );
  }

  /// Eje de aire entre las cosas.
  Widget _ejeDensidad(DisenoVista declarado, StringsVistas t) {
    final valor = declarado.densidad ?? 1.0;
    return _VistasEje(
      rotulo: t.densidad,
      propio: declarado.densidad != null,
      t: t,
      r: widget.r,
      onBg: widget.onBg,
      glowColor: widget.glowColor,
      onHeredar: () => _poner(declarado.copiarCon(borrarDensidad: true)),
      child: _deslizador(
        valor: valor,
        min: DisenoVista.minDensidad,
        max: DisenoVista.maxDensidad,
        etiqueta: '${valor.toStringAsFixed(1)}×',
        onChanged: (v) => _poner(declarado.copiarCon(densidad: v)),
      ),
    );
  }

  /// Eje de columnas de la grilla.
  ///
  /// A diferencia del aire y el redondeo, las columnas NO heredan del estilo
  /// global: sin tocar nada las decide el ancho de la pantalla (2 en un
  /// celular, 4 en una PC, 6 en una pantalla grande). Por eso el valor sin tocar
  /// dice "Automático" y no "Heredado", y el tope sólo puede REDUCIR: pedirle
  /// más columnas a un celular dejaría las portadas del tamaño de un sello.
  Widget _ejeColumnas(DisenoVista declarado, StringsVistas t) {
    final r = widget.r;
    final valor = declarado.columnasMax.toDouble();
    return _VistasEje(
      rotulo: t.columnas,
      propio: declarado.columnasMax > 0,
      marcaVacia: t.automatico,
      t: t,
      r: r,
      onBg: widget.onBg,
      glowColor: widget.glowColor,
      onHeredar: () => _poner(declarado.copiarCon(columnasMax: 0)),
      child: _deslizador(
        valor: valor,
        min: 0,
        max: DisenoVista.maxColumnas.toDouble(),
        divisiones: DisenoVista.maxColumnas,
        etiqueta: valor == 0 ? t.automatico : '${declarado.columnasMax}',
        onChanged: (v) => _poner(declarado.copiarCon(columnasMax: v.round())),
      ),
    );
  }

  /// Un deslizador con su valor a la derecha.
  Widget _deslizador({
    required double valor,
    required double min,
    required double max,
    required String etiqueta,
    required ValueChanged<double> onChanged,
    int? divisiones,
  }) {
    final r = widget.r;
    return Row(
      children: [
        Expanded(
          child: Slider(
            value: valor.clamp(min, max),
            min: min,
            max: max,
            divisions: divisiones,
            activeColor: widget.glowColor,
            onChanged: onChanged,
          ),
        ),
        SizedBox(width: r.spacingS),
        SizedBox(
          width: 68,
          child: Text(
            etiqueta,
            textAlign: TextAlign.right,
            style: TextStyle(
              fontSize: r.footerSize,
              fontWeight: FontWeight.w600,
              color: widget.onBg.withValues(alpha: 0.7),
            ),
          ),
        ),
      ],
    );
  }

  /// Pie: restablecer esta vista y cuántas quedaron personalizadas.
  Widget _pie(PreferenciasVistas prefs, StringsVistas t) {
    final r = widget.r;
    final vacia = prefs.para(_vista).esHereda;
    return Padding(
      padding: EdgeInsets.only(top: r.spacingS),
      child: Row(
        children: [
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: vacia ? null : _restablecerVista,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.settings_backup_restore_rounded,
                  size: r.footerSize + 2,
                  color: widget.onBg.withValues(alpha: vacia ? 0.25 : 0.55),
                ),
                SizedBox(width: r.spacingXS),
                Text(
                  _restablecida ? t.restablecida : t.restablecer,
                  style: TextStyle(
                    fontSize: r.footerSize - 1,
                    color:
                        _restablecida
                            ? widget.glowColor
                            : widget.onBg.withValues(alpha: vacia ? 0.25 : 0.55),
                  ),
                ),
              ],
            ),
          ),
          const Spacer(),
          if (prefs.esDeFabrica)
            Flexible(
              child: Text(
                t.sinCambios,
                textAlign: TextAlign.right,
                style: TextStyle(
                  fontSize: r.footerSize - 2,
                  color: widget.onBg.withValues(alpha: 0.35),
                ),
              ),
            )
          else
            Text(
              t.tocadas(prefs.cantidadPersonalizadas),
              style: TextStyle(
                fontSize: r.footerSize - 2,
                color: widget.onBg.withValues(alpha: 0.45),
              ),
            ),
        ],
      ),
    );
  }
}
