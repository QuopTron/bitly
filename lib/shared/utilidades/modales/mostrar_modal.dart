// ─────────────────────────────────────────────────────────────
// mostrar_modal.dart — Apertura central de hojas y diálogos.
//
// El problema que resuelve: las hojas con "panel + margen arriba +
// esquinas redondeadas" dejan ver, por el hueco de arriba y por el
// velo translúcido, la hoja que ya estaba abierta. Al abrir una
// opción DENTRO de un modal (idioma de la letra, selector de
// playlist, sub-hojas de Ajustes) se veían dos modales a la vez.
//
// Con [sobreHoja]/[sobreModal] el velo pasa a ser OPACO (color de la
// página): tapa por completo lo que había debajo, así que en ningún
// momento se ven dos modales. El alto de la hoja no cambia.
//
// Además hay AUTO-DETECCIÓN ([hayModalAbierto]): como estos helpers
// llevan la cuenta de los modales vivos, cualquier apertura que ocurra
// con otro modal abierto tapa igual, aunque su llamador se olvide de
// pedirlo. Así la regla no depende de la memoria de cada llamador.
// Se conecta con: colores_app (fondo del tema).
// Parte del flujo: cualquier modal de la app.
// ─────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';

import '../../tema/colores_app.dart';

/// Modales abiertos ahora mismo (hojas + diálogos), contados por los
/// helpers de este archivo.
int _modalesAbiertos = 0;

/// True si ya hay un modal abierto: una apertura por encima tiene que
/// tapar lo de abajo.
///
/// Lo consultan los caminos que no eligen cuándo abrirse (el aviso de
/// verificación puede saltar con una hoja abierta) y también los helpers
/// para no depender de que el llamador pase `sobreHoja`/`sobreModal`.
bool get hayModalAbierto => _modalesAbiertos > 0;

/// Solo para tests: en la app el navegador vive lo que vive la app y las
/// hojas siempre cierran (el contador vuelve solo). Al desmontar un árbol
/// con una hoja abierta, en cambio, su futuro puede no completarse.
@visibleForTesting
void reiniciarModalesAbiertos() => _modalesAbiertos = 0;

/// Un modal menos al cerrarse (nunca por debajo de cero: si la cuenta se
/// desbalanceara, un valor negativo haría creer que no hay nada abierto).
void _cerrarModal() {
  if (_modalesAbiertos > 0) _modalesAbiertos--;
}

/// Abre una hoja modal.
///
/// [sobreHoja] = true cuando la apertura puede ocurrir DENTRO de otro modal:
/// el velo se vuelve opaco (color de la página) y tapa la hoja de abajo.
/// [sobreHoja] = false conserva el velo clásico (oscurece la página, que es lo
/// lindo cuando se abre desde una pantalla normal).
Future<T?> mostrarHoja<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool sobreHoja = false,
  bool isScrollControlled = false,
  bool useSafeArea = false,
  bool isDismissible = true,
  bool enableDrag = true,
  Color? backgroundColor,
  Color? barrierColor,
  ShapeBorder? shape,
}) {
  // Se mira ANTES de sumar el propio: si no, la primera hoja de una página
  // se creería anidada y perdería el velo clásico.
  final tapar = sobreHoja || hayModalAbierto;
  _modalesAbiertos++;
  try {
    return showModalBottomSheet<T>(
      context: context,
      // Material 3 limita las hojas a 640 px y las CENTRA en pantallas
      // anchas (PC/TV), así que se veían como una tarjeta flotante en vez
      // del panel anclado abajo con sus esquinas redondeadas. Sin tope, la
      // hoja ocupa el ancho real en todas las plataformas.
      constraints: const BoxConstraints(maxWidth: double.infinity),
      isScrollControlled: isScrollControlled,
      useSafeArea: useSafeArea,
      isDismissible: isDismissible,
      enableDrag: enableDrag,
      backgroundColor: backgroundColor,
      barrierColor: barrierDeModal(
        context,
        sobreModal: tapar,
        pedido: barrierColor,
      ),
      shape: shape,
      builder: builder,
    ).whenComplete(_cerrarModal);
  } catch (_) {
    _cerrarModal();
    rethrow;
  }
}

/// Abre un diálogo. [sobreModal] = true cuando se abre DENTRO de otro modal
/// (p. ej. confirmar limpiar caché desde Ajustes): el velo se vuelve opaco
/// para que detrás del diálogo no quede visible el modal anterior.
Future<T?> mostrarDialogo<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool sobreModal = false,
  bool barrierDismissible = true,
  Color? barrierColor,
}) {
  final tapar = sobreModal || hayModalAbierto;
  _modalesAbiertos++;
  try {
    return showDialog<T>(
      context: context,
      barrierDismissible: barrierDismissible,
      barrierColor: barrierDeModal(
        context,
        sobreModal: tapar,
        pedido: barrierColor,
      ),
      builder: builder,
    ).whenComplete(_cerrarModal);
  } catch (_) {
    _cerrarModal();
    rethrow;
  }
}

/// Velo del modal: opaco (fondo de la página) cuando hay otro modal abajo,
/// o el que pidió el llamador (null = el clásico de Flutter, oscuro y
/// translúcido).
Color? barrierDeModal(
  BuildContext context, {
  required bool sobreModal,
  Color? pedido,
}) {
  if (!sobreModal) return pedido;
  return ColoresApp.fondo(esOscuroSeguro(context));
}

/// True si el tema activo es oscuro.
///
/// Defensivo a propósito: esto puede llamarse con el contexto del navigator
/// raíz (p. ej. el diálogo de verificación de sesiones), donde una excepción
/// dejaría la app sin poder mostrar el modal.
bool esOscuroSeguro(BuildContext context) {
  try {
    return Theme.of(context).brightness == Brightness.dark;
  } catch (_) {
    return true;
  }
}
