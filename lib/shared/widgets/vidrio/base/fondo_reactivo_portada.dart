// ─────────────────────────────────────────────────────────────
// fondo_reactivo_portada.dart — El fondo de modal que reacciona a la
// carátula: la portada desenfocada detrás con un velo del tema, y encima su
// color dominante, que entra según la intensidad de "fondos de modales"
// (0 = sólo la portada difuminada, 1 = sólo el color del cover).
// Un solo widget porque el karaoke y la cola tenían cada uno su copia del
// fondo Y del velo (dos paletas extraídas por la misma carátula): acá se
// extrae una vez y se pintan las dos capas, así todo modal que lo use queda
// con el MISMO diseño. En gama baja `DesenfoqueHijo` devuelve la imagen sin
// filtrar y el velo igual deja todo legible.
// Se conecta con: paleta_portada + imagen_portada + perfil_rendimiento +
// estilo_helper (el control de intensidad, aplicado 1:1).
// Parte del flujo: modales (cola, karaoke, playlist, agregar a).
// ─────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';

import '../../../../app/inyeccion/inyeccion.dart';
import '../../../../core/modelos/usuario/perfil/perfil_rendimiento.dart';
import '../../../../core/modelos/usuario/preferencias/preferencias_estilo.dart';
import '../../../utilidades/formato/comun/formato/estilo_helper.dart';
import '../../../utilidades/portada/paleta/paleta_portada.dart';
import '../../fondos/ambiente/atenuado_por_nivel.dart';
import '../../tarjetas/portada/imagen_portada.dart';
import 'desenfoque_adaptativo.dart';

/// Fondo de modal que reacciona a la carátula.
class FondoReactivoPortada extends StatefulWidget {
  /// Carátula (URL o archivo local). Vacía = fondo del tema sin más.
  final String? caratula;
  final bool esOscuro;

  /// Esquinas del panel (para que el desenfoque no se salga) y opacidad del
  /// velo en modo clásico (carátula desenfocada detrás).
  final double radio, veloOscuro, veloClaro;

  const FondoReactivoPortada({
    super.key,
    this.caratula,
    required this.esOscuro,
    this.radio = 24,
    this.veloOscuro = 0.74,
    this.veloClaro = 0.55,
  });

  @override
  State<FondoReactivoPortada> createState() => _FondoReactivoPortadaState();
}

class _FondoReactivoPortadaState extends State<FondoReactivoPortada> {
  Color? _acento;

  /// Fondo neutro del tema (el piso sobre el que se mezcla todo).
  Color get _base =>
      widget.esOscuro ? const Color(0xFF141414) : const Color(0xFFF6F6F6);

  String get _caratula => widget.caratula?.trim() ?? '';

  @override
  void initState() {
    super.initState();
    _extraerColor();
  }

  @override
  void didUpdateWidget(covariant FondoReactivoPortada oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.caratula != widget.caratula) _extraerColor();
  }

  Future<void> _extraerColor() async {
    if (_caratula.isEmpty) return;
    try {
      final paleta = await paletaParaPortada(_caratula);
      if (mounted) setState(() => _acento = paleta?.dominante);
    } catch (e) {
      debugPrint('[Fondo] no se pudo leer la paleta: $e');
    }
  }

  /// Dos capas: la portada desenfocada con velo (siempre) y el color
  /// dominante encima, que aparece a medida que sube la intensidad.
  @override
  Widget build(BuildContext context) {
    final prefs = _leer<ValueNotifier<PreferenciasEstilo>>();
    if (prefs == null) return _clasico(0);

    return ValueListenableBuilder<PreferenciasEstilo>(
      valueListenable: prefs,
      builder:
          (context, preferencias, _) => Stack(
            fit: StackFit.expand,
            children: [
              _clasico(preferencias.fondosModals),
              if (_acento != null)
                AtenuadoPorNivel(
                  // La opacidad es la intensidad tal cual: cada punto
                  // porcentual del control vale lo mismo.
                  opacidad: preferencias.fondosModals,
                  child: _tinte(),
                ),
            ],
          ),
    );
  }

  Widget _tinte() {
    // El color del cover con presencia (estilo_helper): si se mezclaba
    // apagado, sobre su propia carátula no se notaba el cambio.
    final colorFinal = EstiloHelper.colorDeCover(
      _acento ?? _base,
      _base,
      mezcla: widget.esOscuro ? 0.50 : 0.38,
    );
    return AnimatedContainer(
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeOutCubic,
      color: colorFinal,
    );
  }

  /// Modo clásico: portada desenfocada detrás + velo del tema encima.
  ///
  /// [nivel] es la intensidad de "fondos de modales": el velo del tema se apaga
  /// y la portada se va desenfocando, así se disuelve en el color del cover.
  Widget _clasico(double nivel) {
    final velo = (widget.esOscuro ? Colors.black : Colors.white).withValues(
      alpha: widget.esOscuro ? widget.veloOscuro : widget.veloClaro,
    );
    if (_caratula.isEmpty) {
      return Container(color: Color.alphaBlend(velo, _base));
    }
    final sigma =
        _leer<ValueNotifier<PerfilRendimiento>>()?.value.sigmaDesenfoque ?? 18;
    return ClipRRect(
      borderRadius: BorderRadius.vertical(top: Radius.circular(widget.radio)),
      child: Stack(
        fit: StackFit.expand,
        children: [
          DesenfoqueHijo(
            sigma: EstiloHelper.sigmaPorNivel(sigma, nivel),
            tope: EstiloHelper.topeSigma(sigma),
            child: Transform.scale(
              scale: 1.3,
              child: imagenDesdeUrl(
                _caratula,
                ajuste: BoxFit.cover,
                ancho: 512,
                alto: double.infinity,
              ),
            ),
          ),
          ColoredBox(color: velo),
        ],
      ),
    );
  }
}

/// Lee un singleton de DI sin romper si todavía no está registrado.
T? _leer<T extends Object>() {
  try {
    return sl<T>();
  } catch (e) {
    debugPrint('[FondoReactivoPortadaState] $e');
    return null;
  }
}
