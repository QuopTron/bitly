import 'package:flutter/material.dart';
import '../../shared/utilidades/responsive.dart';
import '../../l10n/app_localizations.dart';
import '../../core/modelos/perfil_rendimiento.dart';
import '../../core/cache/cache_ajustes.dart';
import '../../core/backend_go/contrato_backend.dart';
import '../../app/inyeccion.dart';
import '../../shared/widgets/contenedor_vidrio.dart';

/// Selector de perfil de rendimiento (Bajo / Medio / Alto).
/// Al cambiar, persiste el perfil, ajusta la calidad de audio por defecto
/// y sincroniza concurrencia/buffer con el backend Go.
class SettingsPerformanceSection extends StatefulWidget {
  final Color onBg;
  final Color glowColor;

  const SettingsPerformanceSection({super.key, required this.onBg, required this.glowColor});

  @override
  State<SettingsPerformanceSection> createState() => _SettingsPerformanceSectionState();
}

class _SettingsPerformanceSectionState extends State<SettingsPerformanceSection> {
  NivelRendimiento _nivel = NivelRendimiento.medio;

  @override
  void initState() {
    super.initState();
    _cargar();
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
    final r = Responsive(context);
    final loc = AppLocalizations.of(context);
    final perfiles = [
      (NivelRendimiento.bajo, loc.setup.perfLow, loc.setup.perfLowDesc, Icons.battery_1_bar),
      (NivelRendimiento.medio, loc.setup.perfMedium, loc.setup.perfMediumDesc, Icons.balance),
      (NivelRendimiento.alto, loc.setup.perfHigh, loc.setup.perfHighDesc, Icons.rocket_launch),
    ];

    return ContenedorVidrio(
      borderRadius: 16, borderColor: widget.onBg.withValues(alpha: 0.08),
      bgColor: widget.onBg.withValues(alpha: 0.03),
      margin: EdgeInsets.symmetric(horizontal: r.spacingM),
      padding: EdgeInsets.all(r.spacingM),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(loc.setup.performanceProfile,
          style: TextStyle(fontSize: r.subtitleSize, fontWeight: FontWeight.w600, color: widget.onBg)),
        SizedBox(height: r.spacingM),
        ...perfiles.map((p) => Padding(
          padding: EdgeInsets.only(bottom: r.spacingS),
          child: _opcion(p.$1, p.$2, p.$3, p.$4, r),
        )),
      ]),
    );
  }

  Widget _opcion(NivelRendimiento nivel, String label, String desc, IconData icon, Responsive r) {
    final seleccionado = _nivel == nivel;
    final color = seleccionado ? widget.glowColor : widget.onBg.withValues(alpha: 0.5);
    return InkWell(
      key: ValueKey('perf_${nivel.clave}'),
      onTap: () => _aplicar(nivel),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: EdgeInsets.all(r.spacingS),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: seleccionado ? widget.glowColor.withValues(alpha: 0.6) : widget.onBg.withValues(alpha: 0.1)),
          color: seleccionado ? widget.glowColor.withValues(alpha: 0.1) : Colors.transparent,
        ),
        child: Row(children: [
          Icon(icon, size: r.subtitleSize, color: color),
          SizedBox(width: r.spacingS),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: TextStyle(fontSize: r.subtitleSize - 1, fontWeight: FontWeight.w600, color: widget.onBg)),
            SizedBox(height: 2),
            Text(desc, style: TextStyle(fontSize: r.footerSize - 2, color: widget.onBg.withValues(alpha: 0.5))),
          ])),
          if (seleccionado) Icon(Icons.check_circle, size: r.subtitleSize, color: widget.glowColor),
        ]),
      ),
    );
  }
}