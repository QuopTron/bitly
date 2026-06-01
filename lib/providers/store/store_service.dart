import 'package:bitly/core/bridge/bridge_client.dart';

class StoreService {
  Future<void> initExtensionStore(String cacheDir) async {
    await PlatformBridge.initExtensionStore(cacheDir);
  }

  Future<void> setRegistryUrl(String url) async {
    await PlatformBridge.setStoreRegistryUrl(url);
  }

  Future<String> getRegistryUrl() async {
    return await PlatformBridge.getStoreRegistryUrl();
  }

  Future<void> clearRegistryUrl() async {
    await PlatformBridge.clearStoreRegistryUrl();
  }

  Future<List<Map<String, dynamic>>> getExtensions({
    bool forceRefresh = false,
  }) async {
    return await PlatformBridge.getStoreExtensions(forceRefresh: forceRefresh);
  }

  Future<List<Map<String, dynamic>>> getInstalledExtensions() async {
    return await PlatformBridge.getInstalledExtensions();
  }

  Future<String> downloadExtension(String extensionId, String tempDir) async {
    return await PlatformBridge.downloadStoreExtension(extensionId, tempDir);
  }
}
