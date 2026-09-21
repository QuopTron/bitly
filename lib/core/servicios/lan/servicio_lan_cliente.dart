// ─────────────────────────────────────────────────────────────
// servicio_lan_cliente.dart — PART de servicio_lan.dart: el lado que PIDE
// (vincularse, leer el catálogo del otro y copiar lo que falta).
//
// Todo pasa por la red local, directo de aparato a aparato: no hay ningún
// servidor en el medio ni nada sale a internet.
//
// Copiar es de a una canción y se informa el avance: si una falla, las demás
// siguen (y esa se reintenta en la próxima pasada, porque sigue faltando).
//
// Se conecta con: servicio_lan.dart (misma library) + lan_modelos +
// lan_protocolo.
// Parte del flujo: Ajustes → Conexión → traer mi biblioteca del otro aparato.
// ─────────────────────────────────────────────────────────────

part of 'servicio_lan.dart';

/// Las operaciones que este aparato hace contra otro.
extension ClienteLan on ServicioLan {
  /// Pide vincularse con [par]. El otro aparato le pregunta al usuario, así
  /// que esto puede tardar: devuelve el par ya vinculado, o null si dijo que
  /// no (o no contestó).
  Future<ParLan?> pedirVinculo(ParLan par) async {
    final json = await _pedirJson(
      'POST',
      '/lan/pair',
      par,
      cuerpo: {
        'id': _idPropio,
        'nombre': _nombre,
        'puerto': _puerto,
        'token': _token,
      },
      // Hay alguien del otro lado decidiendo: hay que darle tiempo.
      espera: const Duration(seconds: 70),
      conToken: false,
    );
    final token = json?['token'] as String?;
    if (token == null || token.isEmpty) return null;
    final vinculado = par.copiarCon(
      token: token,
      ultimaVezMs: DateTime.now().millisecondsSinceEpoch,
    );
    await fusionarPar(vinculado);
    alVincular?.call(par.id, par.nombre);
    return vinculado;
  }

  /// El catálogo del otro aparato (null si no contesta o no autoriza).
  Future<List<CancionLan>?> traerIndice(ParLan par) async {
    final json = await _pedirJson('GET', '/lan/index', par);
    final crudas = json?['canciones'];
    if (crudas is! List) return null;
    return [
      for (final c in crudas)
        if (c is Map<String, dynamic>) CancionLan.desdeJson(c),
    ];
  }

  /// Lo que el otro tiene y a este le falta (null si no se pudo consultar).
  Future<List<CancionLan>?> faltantesDe(ParLan par) async {
    final remotas = await traerIndice(par);
    if (remotas == null) return null;
    return faltantesPara(remotas, await clavesLocales());
  }

  /// Copia todas las canciones de [par] que falten acá. Devuelve cuántas
  /// llegaron bien y si el usuario cortó a mitad de camino, e informa el
  /// avance en [traspaso] (lo que pinta la barra de la pestaña).
  Future<(int copiadas, bool cancelado)> traerFaltantes(ParLan par) async {
    // Se limpia ANTES de pedir el catálogo: si el usuario cancela mientras
    // todavía se está contando, ese pedido de cancelar no se pierde.
    _cancelado = false;
    final faltan = await faltantesDe(par) ?? const <CancionLan>[];
    traspaso.value = (0, faltan.length);
    var listas = 0;
    for (final cancion in faltan) {
      // Cancelar frena al terminar la canción que está bajando: lo que ya
      // llegó se queda, y lo que falta sigue faltando para la próxima.
      if (_cancelado) break;
      final bytes = await _traerBytes(
        par,
        '/lan/file/${Uri.encodeComponent(cancion.id)}',
      );
      if (bytes != null) {
        try {
          final (cover, letra) = await _traerSidecars(par, cancion);
          await asentarArchivo(cancion, bytes, cover: cover, letra: letra);
          listas++;
        } catch (e) {
          debugPrint('[Lan] no se pudo asentar ${cancion.nombre}: $e');
        }
      }
      traspaso.value = (listas, faltan.length);
    }
    return (listas, _cancelado);
  }

  /// Corta el traspaso en curso (no borra lo que ya llegó).
  void cancelarTraspaso() => _cancelado = true;

  /// Olvida el vínculo con [id] (deja de poder pedirle cosas).
  Future<void> olvidarPar(String id) async {
    _lista = [
      for (final p in _lista)
        if (p.id != id) p,
    ];
    await guardarPares();
  }

  /// La carátula y la letra que acompañan a la canción. Se piden solo si el
  /// catálogo dijo que existen, y si una falla la canción igual llega: son
  /// un extra, no un requisito.
  Future<(List<int>?, List<int>?)> _traerSidecars(
    ParLan par,
    CancionLan cancion,
  ) async {
    final id = Uri.encodeComponent(cancion.id);
    final cover =
        cancion.extCover.isEmpty
            ? null
            : await _traerBytes(par, '/lan/cover/$id');
    final letra =
        cancion.tieneLetra ? await _traerBytes(par, '/lan/lyrics/$id') : null;
    return (cover, letra);
  }
}
