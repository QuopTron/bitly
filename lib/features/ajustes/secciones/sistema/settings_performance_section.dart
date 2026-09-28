// ─────────────────────────────────────────────────────────────
// settings_performance_section.dart — Selector de perfil de rendimiento (Bajo/Medio/Alto) y sus
// dos interruptores vecinos (Modo fluido y audio en segundo plano). Al cambiar
// el perfil persiste la elección, ajusta calidad de audio y sincroniza
// concurrencia/buffer con Go.
//
// Está partido en TRES piezas ([ParteRendimiento]) porque la pestaña las gira
// como páginas de un carrusel: el que entra a prender "audio en segundo plano"
// no tiene que pasar por los tres perfiles ni por el modo fluido.
//
// Se conecta con: cache_ajustes + backend_go + efectos_app + servicio_foco_audio.
// Parte del flujo: Ajustes → Rendimiento.
// ─────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import '../../../../shared/utilidades/plataforma/pantalla/efectos_app.dart';
import '../../../../shared/utilidades/plataforma/responsive.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../core/modelos/usuario/perfil/perfil_rendimiento.dart';
import '../../../../core/cache/almacenes/sistema/cache_ajustes.dart';
import '../../../../core/backend_go/nucleo/base/contrato_backend.dart';
import '../../../../app/inyeccion/inyeccion.dart';

import 'settings_audio_fondo.dart';
import 'settings_modo_fluido.dart';

/// Qué pieza de Rendimiento se dibuja. Una por página del carrusel.
enum ParteRendimiento {
  /// Los tres niveles (Bajo / Medio / Alto). Van juntos porque son UNA
  /// elección: tocar uno deselecciona los otros.
  perfil,

  /// El interruptor del modo fluido.
  fluido,

  /// El interruptor del audio en segundo plano.
  audio,
}

/// Pieza del panel de rendimiento.
///
/// Al elegir un perfil se persiste, se ajusta la calidad de audio por defecto
/// y se sincroniza concurrencia/buffer con el backend Go.
class SettingsPerformanceSection extends StatefulWidget {
  final Color onBg;
  final Color glowColor;
  final ParteRendimiento parte;

  const SettingsPerformanceSection({
    super.key,
    required this.onBg,
    required this.glowColor,
    this.parte = ParteRendimiento.perfil,
  });

  @override
  State<SettingsPerformanceSection> createState() =>
      _SettingsPerformanceSectionState();
}

class _SettingsPerformanceSectionState
    extends State<SettingsPerformanceSection> {
  NivelRendimiento _nivel = NivelRendimiento.medio;

  @override
  void initState() {
    super.initState();
    // Sólo la página del perfil necesita saber cuál está elegido; las otras dos
    // son interruptores que se leen solos y no gastan una lectura de más.
    if (widget.parte == ParteRendimiento.perfil) _cargar();
  }

  Future<void> _cargar() async {
    final nivel = await sl<CacheAjustes>().getNivelRendimiento();
    if (mounted) setState(() => _nivel = nivel);
  }

  Future<void> _aplicar(NivelRendimiento nivel) async {
    final perfil = PerfilRendimiento.paraNivel(nivel);
    setState(() => _nivel = nivel);
    final cacheAjustes = sl<CacheAjustes>();
    await cacheAjustes.guardarNivelRendimiento(nivel);

    // Refleja el perfil activo en toda la app (listas, efectos, carátulas).
    sl<ValueNotifier<PerfilRendimiento>>().value = perfil;
    // Y en el interruptor global de efectos: al elegir "Bajo" los desenfoques
    // se apagan al instante en vez de necesitar reiniciar la app.
    EfectosApp.aplicar(
      efectosPesados: perfil.efectosPesados,
      sigmaMax: perfil.sigmaDesenfoque,
    );

    // Sincroniza la calidad de audio por defecto con el perfil.
    final ajustes = await cacheAjustes.getAjustesDescarga();
    await cacheAjustes.guardarAjustesDescarga(
      ajustes.copiarCon(calidadAudio: perfil.calidadAudio),
    );

    // Empuja concurrencia / buffer al backend Go.
    await sl<BackendService>().syncBackendConfig(
      mode: perfil.nivel.clave,
      streamCacheMaxMb: perfil.cacheStreamingMaxMb,
      downloadConcurrency: perfil.concurrenciaDescargas,
      streamChunkSize: perfil.tamanoChunkStreaming,
    );
  }

  @override
  Widget build(BuildContext context) {
    switch (widget.parte) {
      case ParteRendimiento.fluido:
        return ModoFluidoRow(
          onBg: widget.onBg,
          glowColor: widget.glowColor,
        );
      case ParteRendimiento.audio:
        return AudioSegundoPlanoRow(
          onBg: widget.onBg,
          glowColor: widget.glowColor,
        );
      case ParteRendimiento.perfil:
        return _perfiles(context);
    }
  }

  Widget _perfiles(BuildContext context) {
    final r = Responsive(context);
    final loc = AppLocalizations.of(context);
    final perfiles = [
      (
        NivelRendimiento.bajo,
        loc.setup.perfLow,
        loc.setup.perfLowDesc,
        Icons.battery_1_bar,
      ),
      (
        NivelRendimiento.medio,
        loc.setup.perfMedium,
        loc.setup.perfMediumDesc,
        Icons.balance,
      ),
      (
        NivelRendimiento.alto,
        loc.setup.perfHigh,
        loc.setup.perfHighDesc,
        Icons.rocket_launch,
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final p in perfiles)
          Padding(
            padding: EdgeInsets.only(bottom: r.spacingS),
            child: _opcion(p.$1, p.$2, p.$3, p.$4, r),
          ),
      ],
    );
  }

  Widget _opcion(
    NivelRendimiento nivel,
    String label,
    String desc,
    IconData icon,
    Responsive r,
  ) {
    final seleccionado = _nivel == nivel;
    final color =
        seleccionado ? widget.glowColor : widget.onBg.withValues(alpha: 0.5);
    return InkWell(
      key: ValueKey('perf_${nivel.clave}'),
      onTap: () => _aplicar(nivel),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: EdgeInsets.all(r.spacingS),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color:
                seleccionado
                    ? widget.glowColor.withValues(alpha: 0.6)
                    : widget.onBg.withValues(alpha: 0.1),
          ),
          color:
              seleccionado
                  ? widget.glowColor.withValues(alpha: 0.1)
                  : Colors.transparent,
        ),
        child: Row(
          children: [
            Icon(icon, size: r.subtitleSize + 4, color: color),
            SizedBox(width: r.spacingS),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: r.subtitleSize + 1,
                      fontWeight: FontWeight.w600,
                      color: widget.onBg,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    desc,
                    style: TextStyle(
                      fontSize: r.footerSize - 2,
                      color: widget.onBg.withValues(alpha: 0.5),
                    ),
                  ),
                ],
              ),
            ),
            if (seleccionado)
              Icon(
                Icons.check_circle,
                size: r.subtitleSize,
                color: widget.glowColor,
              ),
          ],
        ),
      ),
    );
  }
}
