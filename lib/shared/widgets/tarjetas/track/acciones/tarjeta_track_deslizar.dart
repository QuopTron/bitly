// ─────────────────────────────────────────────────────────────
// tarjeta_track_deslizar.dart — PART de tarjeta_track.dart:
// gestos rápidos sobre la tarjeta de canción, configurables desde
// Ajustes → Apariencia → Acciones rápidas. Antes este archivo sólo
// sabía "deslizar a la derecha = agregar a la cola", escrito a
// mano; ahora lee el mapa gesto → acción (ajustes_acciones_rapidas)
// y aplica el que corresponda: agregar a la cola, me gusta,
// descargar, compartir, info, ir al álbum o quitar de Mi Espacio.
//
// La tarjeta vuelve a su sitio siempre: ningún gesto la borra ni la
// descarga. Si no hay [TarjetaTrack.item] (no hay datos de canción)
// o el usuario dejó todos los gestos en "Nada", devuelve [hijo]
// intacto, sin envolver nada.
//
// Nota de arquitectura: los gestos horizontales van con Dismissible
// (su arena de gestos convive bien con el scroll vertical de la
// lista). Los verticales NO pueden ir con Dismissible —dentro de una
// lista vertical el scroll gana la arena y nunca dispararía— pero
// tampoco con un GestureDetector de arrastre vertical: ese gana la
// arena y ROMPE el desplazamiento de la lista (no se podría scrollear
// pasando el dedo por encima de una tarjeta, que es casi toda la
// pantalla). Por eso van con un Listener de punteros: mide el
// "flick" (recorrido + velocidad) sin pelear por el gesto, así la
// lista sigue desplazándose y el gesto dispara igual. La ayuda de la
// burbuja lo dice.
//
// Y para que el gesto no se confunda con el scroll, el flick SÓLO cuenta si la
// lista NO se movió durante ese dedo: un desplazamiento rápido hacia arriba
// (un fling de verdad) mueve la lista y entonces no dispara nada. El gesto
// queda para cuando la lista ya no puede moverse más (el final de la lista),
// que es donde el usuario lo busca. Antes cualquier fling sobre una tarjeta
// disparaba la acción además de scrollear: eso era el "scroll falso".
//
// Se conecta con: tarjeta_track.dart (misma library) + cubit_cola +
// cubit_descargas + navegador_detalle + acciones rápidas (ajustes) +
// haptico + l10n.
// Parte del flujo: listas de tracks (búsqueda, feed, mi espacio,
// detalle de álbum/playlist/artista).
// ─────────────────────────────────────────────────────────────

part of '../base/tarjeta_track.dart';

/// Velocidad mínima (px/s) del "flick" vertical para que cuente como gesto:
/// un arrastre lento es scroll y no debe disparar nada.
const double _velocidadGestoVertical = 420;

/// Recorrido mínimo (px) del flick vertical: evita que un movimiento corto
/// (el rebote de un toque) dispare la acción.
const double _recorridoGestoVertical = 36;

/// Cuánto puede moverse la lista sin que el flick deje de ser gesto. Con 1 px
/// ya se sabe que el desplazamiento se lo comió el scroll (no hay ruido: los
/// píxeles de un `ScrollPosition` son enteros).
const double _toleranciaScrollVertical = 1;

/// Envuelve [hijo] con los gestos rápidos configurados. Devuelve [hijo]
/// intacto si la tarjeta no tiene [TarjetaTrack.item] (no hay canción sobre
/// la que actuar) o si el usuario apagó todos los gestos.
Widget _conGestosRapidos(
  TarjetaTrack t,
  BuildContext context,
  Responsive r,
  Widget hijo,
) {
  final item = t.item;
  if (item == null) return hijo;

  return ValueListenableBuilder<AjustesAccionesRapidas>(
    valueListenable: accionesRapidas,
    builder: (context, ajustes, _) {
      if (!ajustes.hayAlgo) return hijo;
      var w = hijo;

      // ── Verticales (arriba/abajo): flick sin bloquear el scroll ──
      if (ajustes.hayVertical) {
        w = _ConFlickVertical(
          key: const ValueKey('gesto-vertical'),
          alFlick:
              (abajo) => _ejecutarGesto(
                t,
                context,
                abajo ? ajustes.abajo : ajustes.arriba,
              ),
          child: w,
        );
      }

      // ── Doble toque ──
      if (ajustes.dobleToque != AccionRapida.ninguna) {
        w = GestureDetector(
          // El doble toque retrasa el tap simple el tiempo del segundo toque;
          // es el precio de tenerlo y por eso viene apagado de fábrica.
          onDoubleTap: () => _ejecutarGesto(t, context, ajustes.dobleToque),
          child: w,
        );
      }

      // ── Horizontales (derecha/izquierda) ──
      final derecha = ajustes.derecha != AccionRapida.ninguna;
      final izquierda = ajustes.izquierda != AccionRapida.ninguna;
      if (derecha || izquierda) {
        final direccion =
            derecha && izquierda
                ? DismissDirection.horizontal
                : (derecha
                    ? DismissDirection.startToEnd
                    : DismissDirection.endToStart);
        w = Dismissible(
          key: ValueKey(
            'gesto_${item.id}_${item.source ?? ''}_${ajustes.derecha.clave}_${ajustes.izquierda.clave}',
          ),
          direction: direccion,
          dismissThresholds: const {
            DismissDirection.startToEnd: 0.35,
            DismissDirection.endToStart: 0.35,
          },
          confirmDismiss: (d) async {
            // La tarjeta NO se va: el gesto sólo dispara la acción.
            _ejecutarGesto(
              t,
              context,
              d == DismissDirection.startToEnd
                  ? ajustes.derecha
                  : ajustes.izquierda,
            );
            return false;
          },
          background:
              derecha
                  ? _fondoGesto(ajustes.derecha, r, context, aLaDerecha: true)
                  : null,
          secondaryBackground:
              izquierda
                  ? _fondoGesto(
                    ajustes.izquierda,
                    r,
                    context,
                    aLaDerecha: false,
                  )
                  : null,
          child: w,
        );
      }

      return w;
    },
  );
}

/// Escucha el "flick" vertical SIN entrar en la arena de gestos.
///
/// Un `GestureDetector` de arrastre vertical competiría con el scroll de la
/// lista y, al ganar, dejaría el desplazamiento roto sobre las tarjetas. Un
/// `Listener` recibe los eventos de puntero igual (la lista se desplaza
/// cuando corresponde) y sólo avisa si el movimiento fue un flick: recorrido
/// suficiente, velocidad alta y —clave— la lista quieta.
class _ConFlickVertical extends StatefulWidget {
  final ValueChanged<bool> alFlick;
  final Widget child;

  const _ConFlickVertical({
    super.key,
    required this.alFlick,
    required this.child,
  });

  @override
  State<_ConFlickVertical> createState() => _ConFlickVerticalState();
}

class _ConFlickVerticalState extends State<_ConFlickVertical> {
  /// Punto e instante del último pointer-down (uno a la vez: el gesto es con
  /// un dedo).
  double? _yInicial;
  Duration? _tInicial;
  int? _puntero;

  /// La lista de atrás y dónde estaba cuando empezó el dedo. Sirve para saber
  /// si el movimiento lo consumió el scroll (entonces NO es un gesto).
  ScrollPosition? _scroll;
  double? _scrollInicial;

  @override
  Widget build(BuildContext context) => Listener(
    onPointerDown: (e) {
      if (_puntero != null) return;
      _puntero = e.pointer;
      _yInicial = e.position.dy;
      _tInicial = e.timeStamp;
      // La lista puede no existir (una tarjeta suelta): ahí el flick siempre
      // es gesto, porque no hay nada con qué confundirlo.
      _scroll = Scrollable.maybeOf(context)?.position;
      _scrollInicial = _scroll?.pixels;
    },
    onPointerCancel: (_) => _limpiar(),
    onPointerUp: (e) {
      final y0 = _yInicial;
      final t0 = _tInicial;
      if (_puntero != e.pointer || y0 == null || t0 == null) {
        return _limpiar();
      }
      final dy = e.position.dy - y0;
      final ms = (e.timeStamp - t0).inMilliseconds;
      final seMovioLaLista = _seMovioLaLista();
      _limpiar();
      if (ms <= 0 || dy.abs() < _recorridoGestoVertical) return;
      // El dedo scrolleó: eso es desplazarse, no pedir una acción.
      if (seMovioLaLista) return;
      if (dy.abs() * 1000 / ms < _velocidadGestoVertical) return;
      widget.alFlick(dy > 0);
    },
    child: widget.child,
  );

  /// ¿La lista de atrás cambió de posición durante este dedo?
  bool _seMovioLaLista() {
    final scroll = _scroll;
    final desde = _scrollInicial;
    if (scroll == null || desde == null) return false;
    return (scroll.pixels - desde).abs() > _toleranciaScrollVertical;
  }

  void _limpiar() {
    _puntero = null;
    _yInicial = null;
    _tInicial = null;
    _scroll = null;
    _scrollInicial = null;
  }
}

/// Fondo que asoma mientras se desliza: color e icono de la acción.
Widget _fondoGesto(
  AccionRapida accion,
  Responsive r,
  BuildContext context, {
  required bool aLaDerecha,
}) {
  final (color, icono) = _colorEIconoGesto(accion);
  return Container(
    alignment: aLaDerecha ? Alignment.centerLeft : Alignment.centerRight,
    padding: EdgeInsets.only(
      left: aLaDerecha ? r.spacingL : 0,
      right: aLaDerecha ? 0 : r.spacingL,
    ),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.22),
      borderRadius: BorderRadius.circular(_radioCardTrack(context)),
    ),
    child: Icon(icono, color: color, size: r.footerSize * 1.8),
  );
}

/// Color e icono de cada acción, para el fondo del deslizamiento.
(Color, IconData) _colorEIconoGesto(AccionRapida accion) {
  switch (accion) {
    case AccionRapida.agregarCola:
      return (ColoresApp.verdeBrillante, Icons.queue_music_rounded);
    case AccionRapida.meGusta:
      return (ColoresApp.error, Icons.favorite_rounded);
    case AccionRapida.descargar:
      return (ColoresApp.exito, Icons.download_rounded);
    case AccionRapida.compartir:
      return (ColoresApp.primario, Icons.share_rounded);
    case AccionRapida.info:
      return (ColoresApp.primario, Icons.info_outline_rounded);
    case AccionRapida.irAlbum:
      return (ColoresApp.primario, Icons.album_rounded);
    case AccionRapida.quitarMiEspacio:
      return (ColoresApp.error, Icons.remove_circle_outline_rounded);
    case AccionRapida.ninguna:
      return (ColoresApp.primario, Icons.block_rounded);
  }
}

/// Ejecuta la acción del gesto sobre la canción de la tarjeta.
///
/// Todo lo que no puede resolverse desde acá (una tarjeta sin álbum, sin
/// callback de descarga, etc.) avisa en vez de quedarse mudo: si el usuario
/// eligió ese gesto, tiene que saber por qué no pasó nada.
void _ejecutarGesto(TarjetaTrack t, BuildContext context, AccionRapida accion) {
  final item = t.item;
  if (item == null || accion == AccionRapida.ninguna) return;
  final t9 = AppLocalizations.of(context).accionesRapidas;

  switch (accion) {
    case AccionRapida.agregarCola:
      Haptico.medio();
      sl<CubitCola>().agregarAlFinal(item);
      _avisoGesto(context, t9.agregadoACola(t.titulo));

    case AccionRapida.meGusta:
      if (t.onLike == null) return _avisoGesto(context, t9.accionNoDisponible);
      Haptico.medio();
      t.onLike!.call();

    case AccionRapida.descargar:
      final accionDescarga = _accionDescargaDe(t);
      if (accionDescarga == null) {
        return _avisoGesto(context, t9.accionNoDisponible);
      }
      accionDescarga();

    case AccionRapida.compartir:
      if (t.onCompartir == null) {
        return _avisoGesto(context, t9.accionNoDisponible);
      }
      t.onCompartir!.call();

    case AccionRapida.info:
      if (t.onInfo == null) return _avisoGesto(context, t9.accionNoDisponible);
      t.onInfo!.call();

    case AccionRapida.irAlbum:
      final albumId = item.albumId;
      if (albumId == null || albumId.isEmpty) {
        return _avisoGesto(context, t9.accionNoDisponible);
      }
      abrirDetalleAlbum(
        context,
        id: albumId,
        fuente: item.source ?? '',
        coverUrl: item.coverUrl,
      );

    case AccionRapida.quitarMiEspacio:
      // Mi Espacio guarda descargas: "quitar" es borrar lo que ya está
      // resuelto en disco. Se usa el service locator (y no el provider del
      // árbol) porque la tarjeta vive en vistas que no siempre lo proveen.
      Haptico.medio();
      final cubit = sl<CubitDescargas>();
      final src = item.source ?? '';
      if (item.type == 'album') {
        cubit.borrarDescargaAlbum(item.id, src);
      } else if (item.type == 'playlist') {
        cubit.borrarDescargaPlaylist(item.id, src);
      } else {
        cubit.borrarTrackResuelto(item);
      }
      _avisoGesto(context, t9.quitadoDeMiEspacio(t.titulo));

    case AccionRapida.ninguna:
      break;
  }
}

/// Aviso breve del gesto. Reemplaza al anterior en vez de apilarse: con
/// varios gestos seguidos la cola de SnackBars duraba demasiado.
void _avisoGesto(BuildContext context, String texto) {
  final messenger = ScaffoldMessenger.maybeOf(context);
  messenger
    ?..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(texto, maxLines: 1, overflow: TextOverflow.ellipsis),
        duration: const Duration(milliseconds: 1400),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
}
