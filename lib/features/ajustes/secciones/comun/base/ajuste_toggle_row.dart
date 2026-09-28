// ─────────────────────────────────────────────────────────────
// ajuste_toggle_row.dart — Fila de ajuste tipo interruptor: icono, título,
// bajada y un switch, con el estado "todavía no sé si está prendido" resuelto
// con un esqueleto.
//
// Por qué existe: "Modo fluido" y "Audio en segundo plano" eran DOS copias del
// mismo bloque (mismo AnimatedContainer, mismo Row, mismo icono, mismo toggle,
// misma ruedita de carga). Con dos copias, cualquier arreglo visual había que
// hacerlo dos veces y se olvidaba en una; acá hay una sola implementación y
// los dos ajustes la usan.
//
// El "no sé" no es una ruedita: es la silueta del PROPIO switch. La ruedita
// dice "esperá" pero no dice qué va a aparecer, y al llegar el switch el
// contenido salta; el esqueleto ya tiene la forma y el tamaño, así que el
// cambio no mueve nada de lugar.
//
// Se conecta con: efectos_app (los esqueletos), responsive y l10n (ninguno:
// los textos llegan por parámetro, así sirve en cualquier idioma).
// Parte del flujo: Ajustes → Rendimiento.
// ─────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';

import '../../../../../shared/utilidades/plataforma/responsive.dart';
import '../../../../../shared/widgets/esqueletos/esqueleto_carga.dart';

/// Una fila de ajuste que se prende y se apaga.
class AjusteToggleRow extends StatelessWidget {
  final Color onBg;
  final Color glowColor;
  final IconData icono;
  final String titulo;
  final String descripcion;
  final bool activo;

  /// Mientras no se leyó la preferencia guardada. Se dibuja el esqueleto en
  /// lugar del switch y la fila NO responde al toque (prender a ciegas algo
  /// que no sabemos si estaba prendido es justo lo que confunde).
  final bool cargando;
  final VoidCallback onTap;

  const AjusteToggleRow({
    super.key,
    required this.onBg,
    required this.glowColor,
    required this.icono,
    required this.titulo,
    required this.descripcion,
    required this.activo,
    required this.cargando,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final r = Responsive(context);
    return GestureDetector(
      onTap: cargando ? null : onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: EdgeInsets.all(r.spacingS),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          color:
              activo
                  ? glowColor.withValues(alpha: 0.08)
                  : onBg.withValues(alpha: 0.03),
          border: Border.all(
            color:
                activo
                    ? glowColor.withValues(alpha: 0.4)
                    : onBg.withValues(alpha: 0.1),
          ),
        ),
        child: Row(
          children: [
            Icon(
              icono,
              size: r.subtitleSize + 4,
              color:
                  activo ? glowColor : onBg.withValues(alpha: 0.5),
            ),
            SizedBox(width: r.spacingS),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    titulo,
                    style: TextStyle(
                      fontSize: r.subtitleSize + 1,
                      fontWeight: FontWeight.w600,
                      color: onBg,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    descripcion,
                    style: TextStyle(
                      fontSize: r.footerSize - 1,
                      color: onBg.withValues(alpha: 0.5),
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
            // El switch o SU silueta: mismo ancho y mismo alto, para que al
            // llegar el dato real nada se corra de lugar.
            if (cargando)
              const EsqueletoCarga(ancho: 34, alto: 20, radioBorde: 10)
            else
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: Icon(
                  activo ? Icons.toggle_on_rounded : Icons.toggle_off_rounded,
                  key: ValueKey(activo),
                  size: 32,
                  color:
                      activo ? glowColor : onBg.withValues(alpha: 0.3),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
