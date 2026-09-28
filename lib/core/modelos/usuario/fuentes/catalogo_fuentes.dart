// ─────────────────────────────────────────────────────────────
// catalogo_fuentes.dart — La LISTA de tipografías y cuándo se abren.
//
// Va aparte del modelo para que cada archivo haga una sola cosa: uno describe
// QUÉ es una tipografía y éste dice CUÁLES hay y cuáles puede usar el usuario
// hoy.
//
// Por qué el catálogo vive en Flutter y no en el backend: la app necesita los
// nombres, el desbloqueo y un respaldo aunque no haya red (o el backend todavía
// no arrancó). El backend sólo aporta lo que Flutter no puede hacer —traer el
// archivo y validarlo—, así que agregar una tipografía es tocar ESTE archivo.
//
// Se conecta con: fuente_app.dart (el modelo) + servicio_fuentes.dart (bajar y
// registrar) + catalogo_disenos_barra_desbloqueo.dart (versionEnNumero, la
// misma escala de versiones que usa el cofre).
// Parte del flujo: Ajustes → Apariencia → Tipografía.
// ─────────────────────────────────────────────────────────────

import '../disenos/barra/catalogo_disenos_barra_desbloqueo.dart'
    show versionEnNumero;
import 'fuente_app.dart';

/// De dónde baja la app las tipografías que no trae.
///
/// Apunta al espejo público de releases (el mismo que usa la app para buscar
/// actualizaciones), como assets de la etiqueta `fuentes`: es el único host del
/// proyecto que ya es público y permanente, así que no hace falta infra nueva.
/// Subir una tipografía = subir el .ttf ahí con el nombre `<id>.ttf`.
const String baseFuentesUrl =
    'https://github.com/QuopTron/bitly-releases/releases/download/fuentes';

/// La que trae la app: funciona sin red y es la que se usa cuando algo falla.
/// La familia tiene que coincidir EXACTA con la declarada en pubspec.yaml.
const FuenteApp fuenteEmpaquetada = FuenteApp(
  id: 'google_sans',
  familia: 'Google Sans Flex',
);

/// Todas las tipografías, en el orden en que el menú las muestra: primero la
/// que ya se tiene, después las que se van consiguiendo.
///
/// Todas son de licencia libre (OFL/Apache) y se sirven desde el espejo; lo que
/// cambia entre ellas es la forma y en qué momento se abren.
const List<FuenteApp> catalogoFuentes = [
  fuenteEmpaquetada,
  FuenteApp(
    id: 'inter',
    familia: 'bitly_inter',
    url: '$baseFuentesUrl/inter.ttf',
  ),
  FuenteApp(
    id: 'manrope',
    familia: 'bitly_manrope',
    url: '$baseFuentesUrl/manrope.ttf',
    // A partir de acá la escalera acompaña a la de los niveles de escucha.
    desbloqueo: DesbloqueoFuente.horas,
    valor: 5,
  ),
  FuenteApp(
    id: 'rubik',
    familia: 'bitly_rubik',
    url: '$baseFuentesUrl/rubik.ttf',
    desbloqueo: DesbloqueoFuente.horas,
    valor: 50,
  ),
  FuenteApp(
    id: 'space_grotesk',
    familia: 'bitly_space_grotesk',
    url: '$baseFuentesUrl/space_grotesk.ttf',
    desbloqueo: DesbloqueoFuente.horas,
    valor: 300,
  ),
  FuenteApp(
    id: 'jetbrains_mono',
    familia: 'bitly_jetbrains_mono',
    url: '$baseFuentesUrl/jetbrains_mono.ttf',
    desbloqueo: DesbloqueoFuente.horas,
    valor: 1000,
  ),
  FuenteApp(
    id: 'nunito',
    familia: 'bitly_nunito',
    url: '$baseFuentesUrl/nunito.ttf',
    // Regalo de la v1.0.0: llega con la versión, no con las horas.
    desbloqueo: DesbloqueoFuente.version,
    valor: 10000,
  ),
];

/// La tipografía de ese id (null si no existe). Con id vacío devuelve la
/// empaquetada: en las preferencias, 'sin elegir' significa "la de fábrica".
FuenteApp? fuentePorId(String? id) {
  if (id == null || id.isEmpty) return fuenteEmpaquetada;
  for (final f in catalogoFuentes) {
    if (f.id == id) return f;
  }
  // Una tipografía que se quitó del catálogo no rompe nada: vuelve la de la app.
  return null;
}

/// Familia con la que hay que pintar el tema para ese id. Cae a la empaquetada
/// cuando el id no existe (una preferencia vieja, por ejemplo).
String familiaDeFuente(String? id) =>
    (fuentePorId(id) ?? fuenteEmpaquetada).familia;

/// ¿El usuario ya puede elegir [f], con [horas] escuchadas y la app en
/// [version] (ver [versionEnNumero])?
bool fuenteDesbloqueada(
  FuenteApp f, {
  required int horas,
  required int version,
}) {
  switch (f.desbloqueo) {
    case DesbloqueoFuente.libre:
      return true;
    case DesbloqueoFuente.horas:
      return horas >= f.valor;
    case DesbloqueoFuente.version:
      // Si no se pudo leer la versión (0) no se abre nada por versión: mejor
      // que el usuario no vea un regalo fantasma.
      return version > 0 && version >= f.valor;
  }
}

/// Las tipografías que el usuario ya puede usar hoy.
List<FuenteApp> fuentesDisponibles({
  required int horas,
  required int version,
}) => catalogoFuentes
    .where((f) => fuenteDesbloqueada(f, horas: horas, version: version))
    .toList(growable: false);
