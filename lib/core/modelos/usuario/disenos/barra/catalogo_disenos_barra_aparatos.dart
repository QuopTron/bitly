// ─────────────────────────────────────────────────────────────
// catalogo_disenos_barra_aparatos.dart — Los diseños del cofre que son
// PROPIOS DE UN APARATO: unos se ofrecen solo en la TV, otros solo en la PC y
// otros solo en el celular.
//
// Por qué existen: un diseño no se lee igual en los tres. La TV se mira a
// metros y no tiene dedo, así que necesita contornos marcados y esquinas
// enteras para no perder la barra contra el fondo; en una ventana de PC el
// vidrio ya sobra y conviene lo fino y sutil; y en el celular manda el pulgar
// y el alto de pantalla, así que van las esquinas muy curveadas o la barra
// pegada que deja ver más contenido.
//
// Van en DOS listas para respetar las secciones del cofre (Diseños y Colores):
// [disenosFormaAparato] no tiñe (cambia esquinas y contorno) y
// [disenosColorAparato] son paletas y no tocan la forma.
//
// Se conecta con: catalogo_disenos_barra.dart (el modelo, campo `aparatos`) +
// catalogo_disenos_barra_lista.dart (los junta con el resto del catálogo).
// Parte del flujo: Ajustes → Apariencia → Barras → Cofre.
// ─────────────────────────────────────────────────────────────

import '../base/catalogo_disenos_barra.dart';
import '../../dispositivos/dispositivo_conectado.dart';
import '../../preferencias/preferencias_apariencia.dart';

/// Diseños de FORMA y contorno propios de cada aparato (no tiñen la barra).
const List<DisenoBarra> disenosFormaAparato = [
  // ── TV ──────────────────────────────────────────────────────
  // Panel: recto y con el contorno marcado. A metros, una barra sin borde se
  // pierde contra el fondo de la tele.
  DisenoBarra(
    id: 'tv_panel',
    desbloqueo: DesbloqueoBarra.horas,
    valor: 3,
    radioArriba: 0,
    trazo: TrazoBarra.marcado,
    aparatos: [TipoDispositivo.tv],
  ),
  // Marco: las esquinas al máximo, también con contorno marcado: en pantalla
  // grande la curva se ve de lejos y el borde la sostiene.
  DisenoBarra(
    id: 'tv_marco',
    desbloqueo: DesbloqueoBarra.horas,
    valor: 30,
    radioArriba: PreferenciasApariencia.maxRadioBarra,
    trazo: TrazoBarra.marcado,
    aparatos: [TipoDispositivo.tv],
  ),
  // ── PC ──────────────────────────────────────────────────────
  // Fina: casi sin curva y sin contorno. En una ventana, el vidrio ya está:
  // sumarle borde es ruido.
  DisenoBarra(
    id: 'pc_fina',
    desbloqueo: DesbloqueoBarra.horas,
    valor: 5,
    radioArriba: 6,
    trazo: TrazoBarra.sinTrazo,
    aparatos: [TipoDispositivo.pc],
  ),
  // Cristal: curva media y sin contorno, que es como se leen las superficies
  // de escritorio.
  DisenoBarra(
    id: 'pc_cristal',
    desbloqueo: DesbloqueoBarra.horas,
    valor: 20,
    radioArriba: 16,
    trazo: TrazoBarra.sinTrazo,
    aparatos: [TipoDispositivo.pc],
  ),
  // ── Celular ─────────────────────────────────────────────────
  // Redonda: bien curveada, que es donde cae el pulgar.
  DisenoBarra(
    id: 'movil_redonda',
    desbloqueo: DesbloqueoBarra.horas,
    valor: 4,
    radioArriba: 34,
    aparatos: [TipoDispositivo.celu],
  ),
  // Pegada: recta y sin contorno, para ganar alto en pantallas chicas.
  DisenoBarra(
    id: 'movil_pegada',
    desbloqueo: DesbloqueoBarra.horas,
    valor: 12,
    radioArriba: 0,
    trazo: TrazoBarra.sinTrazo,
    aparatos: [TipoDispositivo.celu],
  ),
];

/// Diseños de COLOR propios de cada aparato (no tocan la forma).
const List<DisenoBarra> disenosColorAparato = [
  // Cine (TV): oscuro, para no encandilar en un cuarto a oscuras.
  DisenoBarra(
    id: 'tv_cine',
    desbloqueo: DesbloqueoBarra.horas,
    valor: 400,
    paleta: [0xFF0F172A, 0xFF312E81],
    aparatos: [TipoDispositivo.tv],
  ),
  // Neón (PC): el acento de escritorio, más frío y eléctrico.
  DisenoBarra(
    id: 'pc_neon',
    desbloqueo: DesbloqueoBarra.horas,
    valor: 150,
    paleta: [0xFF06B6D4, 0xFF8B5CF6],
    aparatos: [TipoDispositivo.pc],
  ),
  // Jade (celular): verde de día, pensado para pantalla chica y a plena luz.
  DisenoBarra(
    id: 'movil_jade',
    desbloqueo: DesbloqueoBarra.horas,
    valor: 60,
    paleta: [0xFF10B981, 0xFF84CC16],
    aparatos: [TipoDispositivo.celu],
  ),
];
