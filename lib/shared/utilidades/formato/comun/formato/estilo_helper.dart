// ─────────────────────────────────────────────────────────────
// estilo_helper.dart — Helper del ESTILO con cover: leer la intensidad de
// cada componente desde cualquier widget y cambiarla desde Ajustes, sin
// que cada archivo importe el notifier ni la caché.
//
// La intensidad (0..1) es la ÚNICA fuente de verdad: no hay un "modo" aparte
// que pueda quedar desincronizado con lo que se pinta. Y se aplica 1:1: cada
// punto porcentual vale lo mismo de punta a punta del control, sin curvas que
// adelanten o atrasen el efecto.
//
// Se conecta con: inyeccion (el notifier) + cache_ajustes (persistencia) +
// preferencias_estilo (el modelo).
// Parte del flujo: Ajustes → Apariencia (estilo) y el pintado de la app.
// ─────────────────────────────────────────────────────────────

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../portada/paleta/paleta_portada.dart'
    show fondoParaTexto, mejorNeutro, relacionContraste;

import '../../../../../app/inyeccion/inyeccion.dart';
import '../../../../../core/cache/almacenes/sistema/cache_ajustes.dart';
import '../../../../../core/modelos/usuario/preferencias/preferencias_estilo.dart';

/// Helper para consultar y cambiar la intensidad del estilo con cover.
class EstiloHelper {
  EstiloHelper._();

  /// Preferencias actuales (todas las intensidades).
  static PreferenciasEstilo preferencias(BuildContext context) =>
      sl<ValueNotifier<PreferenciasEstilo>>().value;

  /// Notifier global, para escuchar los cambios en un widget.
  static ValueNotifier<PreferenciasEstilo> notifier() =>
      sl<ValueNotifier<PreferenciasEstilo>>();

  /// Intensidad de un componente (0 = sin color de cover, 1 = todo).
  static double nivel(BuildContext context, ComponenteEstilo componente) =>
      preferencias(context).nivelDe(componente);

  /// Atajos por componente: mantienen cortas las llamadas de las vistas que
  /// pintan (cards, grillas y fondos), que son once.
  static double cardsCancion(BuildContext context) =>
      nivel(context, ComponenteEstilo.cardsCancion);
  static double cardsGrilla(BuildContext context) =>
      nivel(context, ComponenteEstilo.cardsGrilla);
  static double fondoPrincipal(BuildContext context) =>
      nivel(context, ComponenteEstilo.fondoPrincipal);
  static double fondoReproductor(BuildContext context) =>
      nivel(context, ComponenteEstilo.fondoReproductor);
  static double fondosModals(BuildContext context) =>
      nivel(context, ComponenteEstilo.fondosModals);

  /// ¿Hay al menos un componente con color de cover? Lo usan las vistas que
  /// sólo quieren saber si vale la pena extraer la paleta.
  static bool hayAlguno(BuildContext context) =>
      !preferencias(context).esNormal;

  /// Mueve TODOS los componentes al mismo nivel: lo que hace el slider
  /// general de Ajustes. Sobrescribe lo personalizado, y es lo esperado:
  /// el general pone todo igual.
  static void moverTodos(BuildContext context, double nivel) {
    cambiarPreferencias(
      context,
      PreferenciasEstilo.completo.copiarCon(
        cardsCancion: nivel,
        cardsGrilla: nivel,
        fondoPrincipal: nivel,
        fondoReproductor: nivel,
        fondosModals: nivel,
      ),
    );
  }

  /// Cambia la intensidad de UN componente.
  static void cambiarNivel(
    BuildContext context,
    ComponenteEstilo componente,
    double nivel,
  ) {
    cambiarPreferencias(
      context,
      preferencias(context).conNivel(componente, nivel),
    );
  }

  /// Vuelve todo al diseño monocromático de fábrica.
  static void restablecer(BuildContext context) =>
      cambiarPreferencias(context, PreferenciasEstilo.normal);

  /// Guarda las preferencias nuevas (repinta y persiste).
  static void cambiarPreferencias(
    BuildContext context,
    PreferenciasEstilo prefs,
  ) {
    notifier().value = prefs;
    sl<CacheAjustes>().guardarPreferenciasEstilo(prefs);
  }

  /// Acento para la CAPA de tinte sobre la carátula.
  ///
  /// Devuelve el color PURO del cover (o null con intensidad 0). La
  /// atenuación NO se hace mezclando el color hacia el fondo: esa mezcla
  /// ensuciaba el tono y, como además el que pintaba elegía una rama u otra,
  /// al 1% la carátula desaparecía y quedaba un gris plano. Ahora la
  /// intensidad es la OPACIDAD de la capa de tinte (ver AtenuadoPorNivel),
  /// así que la foto se sigue viendo y el color entra de a poco.
  static Color? acentoDeTinte(Color? acento, double nivel) =>
      (acento == null || nivel <= 0) ? null : acento;

  /// Color del cover listo para PINTAR sobre [fondo].
  ///
  /// Por qué no alcanza con mezclar el color crudo: ese color sale de la
  /// MISMA carátula que está debajo, así que al mezclarlo apagado quedaba casi
  /// igual que la foto y el control no se notaba (medido: 0.0 de diferencia de
  /// píxeles entre 0% y 50%). Acá el color se lleva a un tono con presencia
  /// —saturación mínima y luminosidad acotada— antes de mezclarlo, así cada
  /// paso del control se ve y al 100% el color manda de verdad.
  ///
  /// [mezcla] es cuánto del color entra sobre el fondo (1 = color puro).
  ///
  /// [respetarClaridad] decide qué hacer con un cover SIN tono (blanco, negro o
  /// gris): en las CARDS va en true, así el tinte se parece a su portada —un
  /// cover blanco aclara la card y uno negro la deja oscura, y las letras se
  /// acomodan solas—. Los FONDOS lo dejan en false: ahí el color tiñe toda la
  /// pantalla y sus letras son las del tema, así que tiene que quedar dentro de
  /// una franja oscura y legible (un cover blanco no puede blanquear la Home).
  static Color colorDeCover(
    Color acento,
    Color fondo, {
    double mezcla = 0.55,
    bool respetarClaridad = false,
  }) {
    final hsl = HSLColor.fromColor(acento);
    // Un cover blanco, negro o gris NO tiene tono. Antes se le forzaba
    // saturación igual y salía un color falso —y peor: rojo— porque el "hue"
    // de un gris es 0 y el círculo de color arranca en rojo. Ahí no se inventa
    // nada: se respeta el gris y lo único que se acomoda es la claridad.
    final tieneTono = hsl.saturation >= _satMinimaTono;
    final pintable =
        tieneTono
            ? hsl
                .withSaturation((hsl.saturation * 1.3).clamp(0.35, 0.85))
                .withLightness(hsl.lightness.clamp(0.34, 0.58))
                .toColor()
            : hsl
                .withSaturation(0)
                .withLightness(
                  respetarClaridad
                      ? claridadNeutra(hsl.lightness)
                      : hsl.lightness.clamp(0.28, 0.62),
                )
                .toColor();
    return Color.lerp(fondo, pintable, mezcla.clamp(0.0, 1.0))!;
  }

  /// Color de un FONDO con cover que deja legibles las letras del tema.
  ///
  /// En las cards son las letras las que siguen al fondo ([textoDeTinte]); en
  /// un fondo a pantalla completa (reproductor, cola, Home, modales) las letras
  /// son las del tema y no se pueden recolorear una por una, así que el que se
  /// acomoda es el fondo: se lo oscurece o aclara lo justo para que [texto]
  /// llegue al contraste mínimo. Sin esto, un cover saturado y claro al 100%
  /// (un verde o un cian brillante) dejaba el texto blanco en ~3.9:1.
  static Color fondoDeCover(
    Color acento,
    Color fondo,
    Color texto, {
    double mezcla = 0.55,
  }) => fondoParaTexto(colorDeCover(acento, fondo, mezcla: mezcla), texto);

  /// Claridad del tinte cuando el cover NO tiene tono (blanco, negro o gris).
  ///
  /// Sin color, lo único que identifica al arte es su CLARIDAD: un cover
  /// blanco puro tiene que teñir la card de claro y uno negro puro de oscuro.
  /// Por eso se la conserva en vez de achatarla en una franja media (que
  /// dejaba los dos extremos en el mismo gris y hacía que la card no se
  /// pareciera a su portada). Se le da un tirón leve hacia el medio —así el
  /// tinte se sigue notando sobre su propia foto, que es lo que mueve el
  /// control— y un tope que evita el blanco y el negro puros, que se ven
  /// rotos. El texto que va encima no se toca acá: lo decide [textoDeTinte],
  /// que sobre la card clara de un cover blanco pasa solo a negro.
  static double claridadNeutra(double luz) =>
      (0.5 + (luz - 0.5) * 0.8).clamp(0.08, 0.92);

  /// Saturación por debajo de la cual el color cuenta como gris (sin tono).
  static const double _satMinimaTono = 0.12;

  /// El fondo REAL que va a quedar pintado en la card con el tinte a [nivel].
  ///
  /// Es la mezcla del fondo del tema con el color del cover a la intensidad
  /// elegida, en el punto donde el tinte manda (la parada con más color del
  /// gradiente). Sirve para decidir el color de las letras encima.
  static Color fondoPintado(Color? acento, Color fondo, double nivel) {
    final v = nivel.clamp(0.0, 1.0);
    if (acento == null || v <= 0) return fondo;
    return Color.lerp(fondo, colorDeCover(acento, fondo), v)!;
  }

  /// Color de las letras e íconos de la card, ya adaptado al tinte.
  ///
  /// Por qué: con una carátula clara al 100% la card queda clara, y el texto
  /// blanco de fábrica desaparecía sobre ella (y al revés: con una portada
  /// oscura, un texto negro se perdía en el fondo oscuro del tema). Se pide el
  /// mínimo de contraste WCAG (4.5:1); si el color del tema no llega, se pasa
  /// al neutro más legible sobre ese fondo (blanco o negro).
  static Color textoDeTinte(
    Color? acento,
    Color fondo,
    double nivel, {
    required Color fgTema,
  }) {
    final pintado = fondoPintado(acento, fondo, nivel);
    if (relacionContraste(fgTema, pintado) >= _contrasteTextoMinimo) {
      return fgTema;
    }
    return mejorNeutro(pintado);
  }

  /// Contraste mínimo de texto (WCAG AA para texto normal).
  static const double _contrasteTextoMinimo = 4.5;

  /// Sigma del desenfoque de un fondo para una intensidad del control.
  ///
  /// El control no sólo cruza la carátula con el color: a medida que sube, la
  /// carátula se va DESENFOCANDO, así se disuelve en el color del cover en vez
  /// de apagarse como una foto. Con 0 devuelve el sigma de fábrica (el del
  /// perfil de rendimiento), así el diseño de siempre queda intacto.
  ///
  /// Con [base] 0 (gama baja: sin presupuesto de desenfoque) devuelve 0, que es
  /// gratis porque no hay efecto.
  static double sigmaPorNivel(double base, double nivel) {
    if (base <= 0) return 0;
    final t = nivel.clamp(0.0, 1.0);
    // +60% del sigma del perfil en el extremo, con tope duro: más que eso ya
    // no se distingue del color plano y sí se paga en la GPU en cada frame.
    return math.min(base * (1 + 0.6 * t), topeSigma(base));
  }

  /// Tope de sigma que puede alcanzar [sigmaPorNivel] con ese [base].
  ///
  /// El sigma del perfil de rendimiento es el del diseño de FÁBRICA (intensidad
  /// 0); la disolución necesita un margen por encima, y este es su límite. Los
  /// fondos lo pasan como tope del desenfoque para que no se recorte al del
  /// perfil (que dejaría el control sin efecto) sin quedar sin tope.
  static double topeSigma(double base) =>
      base <= 0 ? 0 : math.min(base * 1.6, 60);

  /// Mezcla un valor del diseño Normal con el del look con color: 0 devuelve
  /// [normal] tal cual y 1 devuelve [conColor]. Lo usan los velos y sombras
  /// de las cards, que antes cambiaban de golpe al primer punto del slider.
  static double mezclar(double normal, double conColor, double nivel) =>
      normal + (conColor - normal) * nivel;

  /// Igual que [mezclar] pero para colores: el velo de la foto y el del
  /// color del cover se cruzan sin saltos.
  static Color mezclarColor(Color normal, Color conColor, double nivel) =>
      Color.lerp(normal, conColor, nivel)!;
}
