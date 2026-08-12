import 'backend_service.dart';
import 'mixins/settings_mixin.dart';
import 'mixins/feed_search_mixin.dart';
import 'mixins/actions_mixin.dart';
import 'mixins/detail_mixin.dart';
import 'mixins/infra_mixin.dart';

/// Mixin that aggregates all domain-specific RPC mixins.
///
/// Each sub-mixin provides implementations for a domain (settings, premium,
/// feed/search, actions, library, detail views, collections, infrastructure).
/// The `on` clause ensures all required mixins are applied before this one
/// in the class linearization (see concrete backends like [DesktopBackend]).
mixin RpcBackendMixin on BackendService,
    SettingsMixin,
    FeedSearchMixin,
    ActionsMixin,
    DetailMixin,
    InfraMixin {
  // All RPC methods are provided by the domain mixins above.
  // Subclasses must implement [rpcCall]:
  @override
  Future<dynamic> rpcCall(String method, [Map<String, dynamic>? params, Duration? timeout]);
}

