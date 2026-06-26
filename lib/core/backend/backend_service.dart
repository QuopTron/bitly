import '../models/setup_data.dart';
import '../models/premium_status.dart';
import '../models/feed_models.dart';

abstract class BackendService {
  Future<bool> healthCheck();
  Future<void> saveLanguage(String locale);

  Future<SetupData?> loadSetupData();
  Future<void> completeSetup({
    required String locale,
    required String mode,
    required String username,
    String? premiumCode,
  });
  Future<String?> validatePremiumCode(String code);
  Future<void> activatePremium(String code);
  Future<PremiumStatus> getPremiumStatus();
  Future<List<FeedSection>> getHomeFeed({String locale = 'en'});
  Future<List<FeedItem>> search({
    required String query,
    String source = '',
    String type = '',
    int limit = 20,
  });
}
