// ─────────────────────────────────────────────────────────────
// settings_audio_fondo.dart — Toggle de audio en segundo plano: si está activo, la música sigue sonando aunque otra app toque audio (con warning explicativo).
// Se conecta con: settings_performance_section.dart (lo usa) + cache_ajustes + servicio_foco_audio.
// Parte del flujo: Ajustes → Rendimiento (audio en segundo plano).
// ─────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import '../../../../core/cache/almacenes/sistema/cache_ajustes.dart';
import '../../../../core/plataforma/sistema/base/servicio_foco_audio.dart';
import '../../../../app/inyeccion/inyeccion.dart';
import '../../../../l10n/app_localizations.dart';
import '../comun/base/ajuste_toggle_row.dart';

// Toggle de audio en segundo plano: si esta activo, la musica sigue
// sonando aunque otra app toque audio. Con warning explicativo.
//
// La fila en sí (icono, textos, switch, esqueleto) vive en AjusteToggleRow:
// acá sólo queda LA DECISIÓN (leer la preferencia, aplicarla, guardarla).
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
    if (mounted) {
      setState(() {
        _activo = v;
        _cargando = false;
      });
    }
  }

  Future<void> _alternar(bool valor) async {
    setState(() => _activo = valor);
    await sl<CacheAjustes>().guardarAudioEnSegundoPlano(valor);
    await ServicioFocoAudio.instance.setPermitirFondo(valor);
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    return AjusteToggleRow(
      onBg: widget.onBg,
      glowColor: widget.glowColor,
      icono: Icons.volume_up_rounded,
      titulo: loc.setup.audioFondoTitulo,
      descripcion: loc.setup.audioFondoDesc,
      activo: _activo,
      cargando: _cargando,
      onTap: () => _alternar(!_activo),
    );
  }
}
