// ─────────────────────────────────────────────────────────────
// settings_conexion_red_acciones.dart — PART de settings_sheet_new.dart: lo
// que se puede hacer con un aparato de la red, como funciones sueltas.
//
// Están fuera del widget a propósito: devuelven el TEXTO que hay que mostrar
// (o null si no hay nada que decir), así la sección solo se ocupa de pintar y
// el resultado se puede probar sin abrir la app.
//
// Se conecta con: settings_conexion_red.dart (la sección las llama) +
// servicio_lan.
// Parte del flujo: Ajustes → Conexión → biblioteca en tu red.
// ─────────────────────────────────────────────────────────────

part of '../../settings_sheet_new.dart';

/// Pide el vínculo con [par]. El otro aparato le pregunta a su usuario, así
/// que puede tardar; devuelve el aviso a mostrar (null = salió bien).
Future<String?> vincularParRed(
  ServicioLan lan,
  ParLan par,
  StringsConexionRed loc,
) async {
  final vinculado = await lan.pedirVinculo(par);
  return vinculado == null ? loc.fallo : null;
}

/// Cómo terminó un pedido de vínculo que llegó de otro aparato.
enum ResultadoPedidoVinculo { aceptado, rechazado, sinLugar }

/// Atiende un pedido de vínculo: sin lugar se rechaza con aviso; con lugar se
/// le pregunta al usuario (aceptar solo si el aparato es suyo) y se contesta.
Future<ResultadoPedidoVinculo> atenderPedidoVinculo(
  BuildContext context,
  ServicioLan lan,
  ParLan pedido, {
  required bool hayLugar,
}) async {
  if (!hayLugar) {
    await lan.responderSolicitud(false);
    return ResultadoPedidoVinculo.sinLugar;
  }
  final loc = AppLocalizations.of(context).redConexion;
  final si = await mostrarDialogo<bool>(
    context: context,
    builder:
        (ctx) => AlertDialog(
          title: Text(loc.pedidoTitulo),
          content: Text(loc.pedidoTexto(pedido.nombre)),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: Text(loc.rechazar),
            ),
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: Text(loc.aceptar),
            ),
          ],
        ),
  );
  await lan.responderSolicitud(si == true);
  return si == true
      ? ResultadoPedidoVinculo.aceptado
      : ResultadoPedidoVinculo.rechazado;
}

/// Copia de [par] lo que acá falte. Devuelve qué pasó: todo al día, cuántas
/// llegaron o que el usuario cortó a mitad.
Future<String?> traerParRed(
  ServicioLan lan,
  ParLan par,
  StringsTraspaso prog,
) async {
  final (copiadas, cancelado) = await lan.traerFaltantes(par);
  if (cancelado) return prog.cancelado(copiadas);
  return copiadas == 0 ? prog.todoAlDia : prog.copiando(copiadas, copiadas);
}
