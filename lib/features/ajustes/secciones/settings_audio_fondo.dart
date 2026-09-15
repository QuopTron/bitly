// ─────────────────────────────────────────────────────────────
// settings_audio_fondo.dart — Toggle de audio en segundo plano: si está activo, la música sigue sonando aunque otra app toque audio (con warning explicativo).
// Se conecta con: settings_performance_section.dart (lo usa) + cache_ajustes + servicio_foco_audio.
// Parte del flujo: Ajustes → Rendimiento (audio en segundo plano).
// ─────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import '../../../shared/utilidades/plataforma/responsive.dart';
import '../../../core/cache/almacenes/cache_ajustes.dart';
import '../../../core/plataforma/sistema/servicio_foco_audio.dart';
import '../../../app/inyeccion.dart';


// Toggle de audio en segundo plano: si esta activo, la musica sigue
// sonando aunque otra app toque audio. Con warning explicativo.
class AudioSegundoPlanoRow extends StatefulWidget {
  final Color onBg;
  final Color glowColor;
  const AudioSegundoPlanoRow({
    super.key,
    required this.onBg,
    required this.glowColor,
  });

  @override
  State<AudioSegundoPlanoRow> createState() => AudioSegundoPlanoRowState();
}

class AudioSegundoPlanoRowState extends State<AudioSegundoPlanoRow> {
  bool _activo = false;
  bool _cargando = true;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    final v = await sl<CacheAjustes>().getAudioEnSegundoPlano();
    if (mounted) setState(() { _activo = v; _cargando = false; });
  }

  Future<void> _alternar(bool valor) async {
    setState(() => _activo = valor);
    await sl<CacheAjustes>().guardarAudioEnSegundoPlano(valor);
    await ServicioFocoAudio.instance.setPermitirFondo(valor);
  }

  @override
  Widget build(BuildContext context) {
    final r = Responsive(context);
    return GestureDetector(
      onTap: _cargando ? null : () => _alternar(!_activo),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: EdgeInsets.all(r.spacingS),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          color: _activo
              ? widget.glowColor.withValues(alpha: 0.08)
              : widget.onBg.withValues(alpha: 0.03),
          border: Border.all(
            color: _activo
                ? widget.glowColor.withValues(alpha: 0.4)
                : widget.onBg.withValues(alpha: 0.1),
          ),
        ),
        child: Row(children: [
          Icon(
            Icons.volume_up_rounded,
            size: r.subtitleSize + 4,
            color: _activo ? widget.glowColor : widget.onBg.withValues(alpha: 0.5),
          ),
          SizedBox(width: r.spacingS),
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Audio en segundo plano',
                style: TextStyle(
                  fontSize: r.subtitleSize + 1,
                  fontWeight: FontWeight.w600,
                  color: widget.onBg,
                ),
              ),
              SizedBox(height: 2),
              Text(
                'La música sigue sonando aunque otra app tenga audio '
                '(ideal para jugar mientras escuchás).',
                style: TextStyle(
                  fontSize: r.footerSize - 1,
                  color: widget.onBg.withValues(alpha: 0.5),
                  height: 1.3,
                ),
              ),
            ],
          )),
          if (_cargando)
            SizedBox(
              width: 18, height: 18,
              child: CircularProgressIndicator(strokeWidth: 2, color: widget.glowColor),
            )
          else
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: Icon(
                _activo ? Icons.toggle_on_rounded : Icons.toggle_off_rounded,
                key: ValueKey(_activo),
                size: 32,
                color: _activo ? widget.glowColor : widget.onBg.withValues(alpha: 0.3),
              ),
            ),
        ]),
      ),
    );
  }
}
