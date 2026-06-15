import 'package:get_it/get_it.dart';
import '../models/extension_model.dart';
import '../../../../core/api/methods/extension_methods.dart' as rpc;

class ExtensionRepository {
  final rpc.ExtensionMethods _rpc;

  ExtensionRepository(this._rpc);

  static ExtensionRepository get instance =>
      GetIt.I<ExtensionRepository>();

  Future<List<ExtensionModel>> getInstalled() async {
    final result = await _rpc.getInstalled();
    return (result as List<dynamic>)
        .map((e) => ExtensionModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> setEnabled(String id, bool enabled) async {
    await _rpc.setEnabled(id, enabled);
  }

  Future<void> setPriority(String id, int priority) async {
    await _rpc.setPriority(id, priority);
  }

  Future<void> install(String path) async {
    await _rpc.install(path);
  }

  Future<void> remove(String id) async {
    await _rpc.remove(id);
  }

  Future<void> upgrade(String id) async {
    // No upgrade method in RPC, implement if needed
    throw UnimplementedError('Upgrade not implemented in RPC');
  }
}
