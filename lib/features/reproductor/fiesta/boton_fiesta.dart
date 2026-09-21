// ─────────────────────────────────────────────────────────────
// boton_fiesta.dart — El icono de BOLA DISCO de la fila de controles: abre el
// modo fiesta y se queda encendido (con el número de aparatos) mientras la
// fiesta está andando en este aparato.
//
// Cuando hay fiesta, el icono pasa a mostrar cuántos están sonando: es la
// señal de que no estás escuchando solo. El número sale del propio servicio,
// así que se actualiza apenas alguien se suma o se va.
//
// Todas las medidas salen del Responsive: en la tele el globito con el número
// se agranda con el resto, no queda con el tamaño de celular.
//
// Se conecta con: fila_controles_reproductor.dart (lo monta) + servicio_fiesta.
// Parte del flujo: reproductor → modo fiesta.
// ─────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';

import '../../../app/inyeccion/inyeccion.dart';
import '../../../core/servicios/fiesta/base/servicio_fiesta.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/utilidades/interaccion/haptico.dart';
import '../../../shared/utilidades/plataforma/responsive.dart';
import 'hoja_fiesta.dart';

/// Icono de fiesta de la fila de controles.
class BotonFiesta extends StatelessWidget {
  final Color activo;
  final Color apagado;
  final double tamano;

  const BotonFiesta({
    super.key,
    required this.activo,
    required this.apagado,
    required this.tamano,
  });

  @override
  Widget build(BuildContext context) {
    // El servicio puede no estar (tests de widgets sueltos): sin él no hay
    // fiesta, pero el reproductor sigue andando igual.
    ServicioFiesta? fiesta;
    try {
      fiesta = sl<ServicioFiesta>();
    } catch (e) {
      debugPrint('[Fiesta] sin servicio para el botón: $e');
    }
    if (fiesta == null) return _icono(context, null, const []);
    return ValueListenableBuilder<ModoFiesta>(
      valueListenable: fiesta.modo,
      builder:
          (_, modo, _) => ValueListenableBuilder<List<String>>(
            valueListenable: fiesta!.juntos,
            builder:
                (_, unidos, _) => _icono(
                  context,
                  modo == ModoFiesta.apagado ? null : modo,
                  unidos,
                ),
          ),
    );
  }

  Widget _icono(BuildContext context, ModoFiesta? modo, List<String> unidos) {
    final encendido = modo != null;
    final cuantos = unidos.isEmpty ? 1 : unidos.length;
    final r = Responsive(context);
    return Tooltip(
      message: AppLocalizations.of(context).fiesta.a11y,
      child: GestureDetector(
        onTap: () {
          Haptico.tap();
          mostrarHojaFiesta(context);
        },
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Icon(
              // La bola disco con sus destellos: la fiesta de verdad.
              Icons.nightlife_rounded,
              color: encendido ? activo : apagado,
              size: tamano,
            ),
            if (encendido)
              Positioned(
                right: -r.spacingXS,
                top: -r.spacingXS,
                child: _GloboCantidad(
                  cuantos: cuantos,
                  color: activo,
                  r: r,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// El globito con cuántos aparatos están sonando.
class _GloboCantidad extends StatelessWidget {
  final int cuantos;
  final Color color;
  final Responsive r;

  const _GloboCantidad({
    required this.cuantos,
    required this.color,
    required this.r,
  });

  @override
  Widget build(BuildContext context) => Container(
    padding: EdgeInsets.symmetric(
      horizontal: r.val(5, 4, 9),
      vertical: r.val(1, 1, 3),
    ),
    decoration: BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(r.val(9, 7, 14)),
    ),
    child: Text(
      '$cuantos',
      style: TextStyle(
        fontSize: r.val(9, 8, 14),
        fontWeight: FontWeight.w800,
        color: Theme.of(context).brightness == Brightness.dark
            ? Colors.black
            : Colors.white,
      ),
    ),
  );
}
