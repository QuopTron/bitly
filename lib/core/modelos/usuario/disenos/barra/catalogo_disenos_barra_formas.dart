// ─────────────────────────────────────────────────────────────
// catalogo_disenos_barra_formas.dart — Los diseños de FORMA del cofre:
// los que cambian cómo se ve la barra (no su color).
//
// Cambian las esquinas de arriba (recto, muy redondeado, pastilla) y/o el
// contorno (filoso, contorno marcado, sin contorno). Ninguno trae paleta: el
// color que ya tenías queda intacto.
//
// Va aparte de catalogo_disenos_barra_lista.dart (que las junta con las
// paletas) para que cada archivo siga chico y haga una sola cosa.
//
// Se conecta con: catalogo_disenos_barra.dart (el modelo) +
// preferencias_apariencia.dart (maxRadioBarra).
// Parte del flujo: Ajustes → Apariencia → Barras → Cofre.
// ─────────────────────────────────────────────────────────────

import '../../preferencias/preferencias_apariencia.dart';

import '../base/catalogo_disenos_barra.dart';

/// Las formas, en el orden en que se muestran.
const List<DisenoBarra> disenosFormaBarra = [
  // Recto: esquinas de arriba cuadradas.
  DisenoBarra(
    id: 'esquinas_rectas',
    desbloqueo: DesbloqueoBarra.horas,
    valor: 1,
    radioArriba: 0,
  ),
  // Muy redondeado: se nota el curveado pero no llega a pastilla.
  DisenoBarra(
    id: 'muy_redondeada',
    desbloqueo: DesbloqueoBarra.horas,
    valor: 10,
    radioArriba: 28,
  ),
  // Pastilla: todo curveado arriba, el máximo del control.
  DisenoBarra(
    id: 'pastilla',
    desbloqueo: DesbloqueoBarra.horas,
    valor: 50,
    radioArriba: PreferenciasApariencia.maxRadioBarra,
  ),
  // Filoso: recto y sin contorno (la barra pegada al fondo).
  DisenoBarra(
    id: 'filosa',
    desbloqueo: DesbloqueoBarra.horas,
    valor: 150,
    radioArriba: 0,
    trazo: TrazoBarra.sinTrazo,
  ),
  // Contorno marcado: se nota el borde, misma forma.
  DisenoBarra(
    id: 'contorno_marcado',
    desbloqueo: DesbloqueoBarra.horas,
    valor: 400,
    trazo: TrazoBarra.marcado,
  ),
  // Sin contorno: solo el borde, sin tocar las esquinas.
  DisenoBarra(
    id: 'sin_contorno',
    desbloqueo: DesbloqueoBarra.horas,
    valor: 1_000,
    trazo: TrazoBarra.sinTrazo,
  ),
];
