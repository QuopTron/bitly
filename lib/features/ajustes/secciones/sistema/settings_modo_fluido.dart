// ─────────────────────────────────────────────────────────────
// settings_modo_fluido.dart — Toggle de "Modo fluido" en Ajustes →
// Rendimiento: pintar lo mínimo por frame en equipos donde la app se siente
// pesada, sin cambiar el diseño (los fondos usan el color dominante del cover
// en vez de la foto a pantalla completa).
// Se conecta con: settings_performance_section.dart (lo usa) + cache_ajustes +
// efectos_app (el interruptor global que leen los widgets).
// Parte del flujo: Ajustes → Rendimiento (modo fluido).
// ─────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import '../../../../shared/utilidades/plataforma/pantalla/efectos_app.dart';
import '../../../../core/cache/almacenes/sistema/cache_ajustes.dart';
import '../../../../app/inyeccion/inyeccion.dart';
import '../../../../l10n/app_localizations.dart';
import '../comun/base/ajuste_toggle_row.dart';

/// Toggle del modo fluido: la elección explícita de priorizar frames sobre
/// efectos de GPU. Se aplica al instante (no hace falta reiniciar la app)
/// porque [EfectosApp] es un notificador que los widgets ya escuchan.
///
/// La fila en sí vive en AjusteToggleRow; acá queda SÓLO la decisión de qué
/// significa prenderlo (aplicar los efectos y persistir).
class ModoFluidoRow extends StatefulWidget {
  final Color onBg;
  final Color glowColor;

  const ModoFluidoRow({
    super.key,
    required this.onBg,
    required this.glowColor,
  });

  @override
  State<ModoFluidoRow> createState() => ModoFluidoRowState();
}

class ModoFluidoRowState extends State<ModoFluidoRow> {
  bool _activo = false;
  bool _cargando = true;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    final v = await sl<CacheAjustes>().getModoFluido();
    if (mounted) {
      setState(() {
        _activo = v;
        _cargando = false;
      });
    }
  }

  Future<void> _alternar(bool valor) async {
    setState(() => _activo = valor);
    // Primero se aplica (el cambio se ve al instante en toda la app) y recién
    // después se persiste, que es lo que no debe bloquear el frame.
    EfectosApp.aplicarModoFluido(valor);
    await sl<CacheAjustes>().guardarModoFluido(valor);
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    return AjusteToggleRow(
      onBg: widget.onBg,
      glowColor: widget.glowColor,
      icono: Icons.bolt_rounded,
      titulo: loc.setup.modoFluidoTitulo,
      descripcion: loc.setup.modoFluidoDesc,
      activo: _activo,
      cargando: _cargando,
      onTap: () => _alternar(!_activo),
    );
  }
}
