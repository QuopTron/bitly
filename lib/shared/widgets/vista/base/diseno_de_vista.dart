// ─────────────────────────────────────────────────────────────
// diseno_de_vista.dart — Monta el diseño propio de una vista: resuelve la
// cascada (vista → global → fábrica), pinta el subárbol con la tipografía que
// la vista eligió y deja el resto del diseño a mano de sus piezas.
//
// Cómo se usa: se envuelve UNA vez el cuerpo de cada vista.
//
//     DisenoDeVista(vista: VistaApp.busqueda, child: PaginaBusqueda(...))
//
// Con eso, TODAS las cards, grillas y espacios de adentro ya obedecen al diseño
// por vista sin tocar una sola tarjeta: el radio y la separación los pide cada
// pieza por `AparienciaEspacios`, que es quien lee el ámbito.
//
// Reglas:
//   · una vista que no eligió nada se ve EXACTAMENTE igual que el estilo
//     global (no hay "diseño vacío" que rompa nada);
//   · la tipografía propia se asegura al montar (se baja si hace falta) sin
//     cambiar la de toda la app — por eso ServicioFuentes.asegurarFamilia
//     existe separado de activar();
//   · si esa bajada falla, la vista queda con la tipografía del tema en vez de
//     quedarse sin letra. La vista no maneja errores: hereda y sigue.
//
// Se conecta con: ambito_vista.dart (lo que deja puesto) + apariencia_vistas_
// helper.dart (la cascada) + servicio_fuentes.dart (asegurar la familia) +
// apariencia_helper.dart (el estilo global).
// Parte del flujo: presentación (cada vista con su diseño).
// ─────────────────────────────────────────────────────────────

import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../core/modelos/usuario/disenos/vistas/vista_app.dart';
import '../../../../core/modelos/usuario/fuentes/catalogo_fuentes.dart';
import '../../../../core/servicios/fuentes/servicio_fuentes.dart';
import '../../../utilidades/formato/apariencia/base/apariencia_helper.dart';
import '../../../utilidades/formato/apariencia/vistas/apariencia_vistas_helper.dart';
import 'ambito_vista.dart';

/// Le da a [child] el diseño de [vista].
class DisenoDeVista extends StatefulWidget {
  /// La vista que se está montando.
  final VistaApp vista;

  /// Su cuerpo.
  final Widget child;

  const DisenoDeVista({
    super.key,
    required this.vista,
    required this.child,
  });

  @override
  State<DisenoDeVista> createState() => _DisenoDeVistaState();
}

class _DisenoDeVistaState extends State<DisenoDeVista> {
  /// Última tipografía propia pedida, para no repetir el trabajo en cada
  /// repintado (el tema se repinta seguido).
  String _tipografiaPedida = '';

  @override
  void initState() {
    super.initState();
    // Las tres cosas que cambian el diseño de la vista: lo que declaró ella
    // misma, el estilo global (del que hereda lo que no declara) y el momento
    // en que una familia termina de registrarse.
    AparienciaVistas.notifier().addListener(_alCambiar);
    AparienciaHelper.notifier().addListener(_alCambiar);
    ServicioFuentes.generacion.addListener(_alCambiar);
  }

  @override
  void dispose() {
    AparienciaVistas.notifier().removeListener(_alCambiar);
    AparienciaHelper.notifier().removeListener(_alCambiar);
    ServicioFuentes.generacion.removeListener(_alCambiar);
    super.dispose();
  }

  void _alCambiar() {
    if (mounted) setState(() {});
  }

  /// Pide el archivo de la tipografía de la vista si todavía no está listo.
  /// No cambia la elección global: sólo la hace pintable.
  void _asegurarTipografia(String tipografiaId) {
    if (tipografiaId.isEmpty || tipografiaId == _tipografiaPedida) return;
    _tipografiaPedida = tipografiaId;
    unawaited(ServicioFuentes.instancia.asegurarFamilia(tipografiaId));
  }

  @override
  Widget build(BuildContext context) {
    final declarado = AparienciaVistas.declarado(widget.vista);
    final resuelto = AparienciaVistas.de(context, widget.vista);
    _asegurarTipografia(declarado.tipografiaId);

    return AmbitoVista(
      vista: widget.vista,
      declarado: declarado,
      resuelto: resuelto,
      child: _conTipografia(
        context,
        declarado.tipografiaId,
        widget.child,
      ),
    );
  }

  /// Pinta [child] con la tipografía de la vista, si eligió una propia.
  ///
  /// Se aplica sobre el `textTheme` del tema en vez de armar un `ThemeData`
  /// nuevo: así la vista cambia sólo la letra y conserva colores, brillo y
  /// todo lo demás del tema real de la app.
  Widget _conTipografia(
    BuildContext context,
    String tipografiaId,
    Widget child,
  ) {
    if (tipografiaId.isEmpty) return child;
    final familia = familiaDeFuente(tipografiaId);
    final base = Theme.of(context);
    return Theme(
      data: base.copyWith(
        textTheme: base.textTheme.apply(fontFamily: familia),
        primaryTextTheme: base.primaryTextTheme.apply(fontFamily: familia),
      ),
      child: child,
    );
  }
}
