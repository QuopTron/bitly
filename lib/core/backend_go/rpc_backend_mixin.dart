// ─────────────────────────────────────────────────────────────
// rpc_backend_mixin.dart — Mixin que agrega todos los mixins RPC
// por dominio. La cláusula `on` garantiza que todos los mixins
// requeridos se apliquen antes en la linearización de la clase
// (ver implementaciones concretas: Android/iOS/Desktop).
// Se conecta con: backend_go (contrato + mixins por dominio).
// Parte del flujo: es la base de toda implementación de backend.
// ─────────────────────────────────────────────────────────────

import 'contrato_backend.dart';
import 'mixins/acciones_mixin.dart';
import 'mixins/ajustes_mixin.dart';
import 'mixins/detalle_mixin.dart';
import 'mixins/editor_etiquetas_mixin.dart';
import 'mixins/feed_busqueda_mixin.dart';
import 'mixins/infra_mixin.dart';
import 'mixins/premium_mixin.dart';
import 'mixins/sesiones_firmadas_mixin.dart';

/// Agrega todos los mixins RPC por dominio. Las subclases concretas deben
/// implementar [rpcCall].
mixin RpcBackendMixin on BackendService,
    AjustesMixin,
    FeedBusquedaMixin,
    AccionesMixin,
    DetalleMixin,
    InfraMixin,
    PremiumMixin,
    EditorEtiquetasMixin,
    SesionesFirmadasMixin {
  @override
  Future<dynamic> rpcCall(String method, [Map<String, dynamic>? params, Duration? timeout]);
}