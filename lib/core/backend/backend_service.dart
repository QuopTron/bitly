abstract class BackendService {
  Future<bool> healthCheck();
  Future<void> saveLanguage(String locale);
}
