// ─────────────────────────────────────────────────────────────
// catalogo_disenos_barra_adornos.dart — Los diseños de ADORNO del cofre:
// los que le dan a la barra un borde ondulado o una calcomanía.
//
// No son otra vuelta de curvatura (eso ya lo mueve el deslizador con las
// FORMAS): acá el borde de arriba deja de ser una recta y pasa a ondular, o
// la barra se lleva un detalle encima. Con Olas, el deslizador deja de mover
// el radio y pasa a dar MÁS O MENOS OLAS.
//
// Ninguno toca el color ni el contorno: se combinan con lo que ya tengas.
//
// Va aparte de catalogo_disenos_barra_lista.dart (que los junta con las
// formas y los colores) para que cada archivo siga chico y haga una sola cosa.
//
// Se conecta con: catalogo_disenos_barra.dart (el modelo).
// Parte del flujo: Ajustes → Apariencia → Barras → Cofre.
// ─────────────────────────────────────────────────────────────

import 'catalogo_disenos_barra.dart';

/// Los adornos, en el orden en que se muestran.
const List<DisenoBarra> disenosAdornoBarra = [
  // Destello: una calcomanía chica arriba de la barra.
  DisenoBarra(
    id: 'sticker_destello',
    desbloqueo: DesbloqueoBarra.horas,
    valor: 750,
    sticker: 'destello',
  ),
  // Olas: el borde de arriba ondula. El control da más o menos olas.
  DisenoBarra(
    id: 'olas',
    desbloqueo: DesbloqueoBarra.horas,
    valor: 2_000,
    adorno: AdornoBarra.olas,
  ),
  // Nota: otra calcomanía, para la escalera larga.
  DisenoBarra(
    id: 'sticker_nota',
    desbloqueo: DesbloqueoBarra.horas,
    valor: 5_000,
    sticker: 'nota',
  ),
];
