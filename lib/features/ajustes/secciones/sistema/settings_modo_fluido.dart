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
import '../../../../shared/utilidades/plataforma/responsive.dart';
import '../../../../core/cache/almacenes/sistema/cache_ajustes.dart';
import '../../../../app/inyeccion/inyeccion.dart';
import '../../../../l10n/app_localizations.dart';

/// Toggle del modo fluido: la elección explícita de priorizar frames sobre
/// efectos de GPU. Se aplica al instante (no hace falta reiniciar la app)
/// porque [EfectosApp] es un notificador que los widgets ya escuchan.
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
    final r = Responsive(context);
    final loc = AppLocalizations.of(context);
    return GestureDetector(
      onTap: _cargando ? null : () => _alternar(!_activo),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: EdgeInsets.all(r.spacingS),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          color:
              _activo
                  ? widget.glowColor.withValues(alpha: 0.08)
                  : widget.onBg.withValues(alpha: 0.03),
          border: Border.all(
            color:
                _activo
                    ? widget.glowColor.withValues(alpha: 0.4)
                    : widget.onBg.withValues(alpha: 0.1),
          ),
        ),
        child: Row(
          children: [
            Icon(
              Icons.bolt_rounded,
              size: r.subtitleSize + 4,
              color:
                  _activo
                      ? widget.glowColor
                      : widget.onBg.withValues(alpha: 0.5),
            ),
            SizedBox(width: r.spacingS),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    loc.setup.modoFluidoTitulo,
                    style: TextStyle(
                      fontSize: r.subtitleSize + 1,
                      fontWeight: FontWeight.w600,
                      color: widget.onBg,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    loc.setup.modoFluidoDesc,
                    style: TextStyle(
                      fontSize: r.footerSize - 1,
                      color: widget.onBg.withValues(alpha: 0.5),
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
            if (_cargando)
              SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: widget.glowColor,
                ),
              )
            else
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: Icon(
                  _activo ? Icons.toggle_on_rounded : Icons.toggle_off_rounded,
                  key: ValueKey(_activo),
                  size: 32,
                  color:
                      _activo
                          ? widget.glowColor
                          : widget.onBg.withValues(alpha: 0.3),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
