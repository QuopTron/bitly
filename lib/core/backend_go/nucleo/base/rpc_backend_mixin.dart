// ─────────────────────────────────────────────────────────────
// rpc_backend_mixin.dart — Mixin que agrega todos los mixins RPC
// por dominio. La cláusula `on` garantiza que todos los mixins
// requeridos se apliquen antes en la linearización de la clase
// (ver implementaciones concretas: Android/iOS/Desktop).
// Se conecta con: backend_go (contrato + mixins por dominio).
// Parte del flujo: es la base de toda implementación de backend.
// ─────────────────────────────────────────────────────────────

import 'contrato_backend.dart';
import '../../mixins/base/acciones_mixin.dart';
import '../../mixins/base/ajustes_mixin.dart';
import '../../mixins/musica/detalle_mixin.dart';
import '../../mixins/biblioteca/editor_etiquetas_mixin.dart';
import '../../mixins/biblioteca/isrc_mixin.dart';
import '../../mixins/musica/enlaces_mixin.dart';
import '../../mixins/musica/feed_busqueda_mixin.dart';
import '../../mixins/base/infra_mixin.dart';
import '../../mixins/base/premium_mixin.dart';
import '../../mixins/sesiones/sesiones_firmadas_mixin.dart';

/// Agrega todos los mixins RPC por dominio. Las subclases concretas deben
/// implementar [rpcCall].
mixin RpcBackendMixin
    on
        BackendService,
        AjustesMixin,
        FeedBusquedaMixin,
        AccionesMixin,
        DetalleMixin,
        InfraMixin,
        PremiumMixin,
        EditorEtiquetasMixin,
        EnlacesMixin,
        IsrcMixin,
        SesionesFirmadasMixin {
  @override
  Future<dynamic> rpcCall(
    String method, [
    Map<String, dynamic>? params,
    Duration? timeout,
  ]);
}
