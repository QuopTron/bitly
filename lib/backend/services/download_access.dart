import '../../injection.dart';
import '../cache/premium_cache.dart';
import '../cache/settings_cache.dart';

/// Result of the download-access gate.
enum DownloadAccess { premium, freeWindow, expired }

/// Decides whether the user may download right now.
///
/// The ONLY difference between Free and Premium is downloads:
/// - Premium (code activated, lifetime) → downloads allowed forever.
/// - Free → downloads allowed only inside the 8-hour trial window recorded at
///   setup (`trial_expires_at`). After it expires, downloads are blocked.
/// - Streaming is NEVER affected by this gate — it works for everyone.
class DownloadAccessChecker {
  static Future<DownloadAccess> check() async {
    // 1. Premium / lifetime (local DB tier + expiry) → always allowed.
    try {
      final status = await sl<PremiumCache>().getPremiumStatus();
      if (status.isPremium) return DownloadAccess.premium;
    } catch (_) {}

    // 2. Free mode → allowed while inside the 8-hour window.
    try {
      final setup = await sl<SettingsCache>().loadSetupData();
      if (setup != null && setup.mode == 'free' && setup.trialExpiresAt != null) {
        final exp = DateTime.tryParse(setup.trialExpiresAt!);
        if (exp != null) {
          return DateTime.now().isBefore(exp)
              ? DownloadAccess.freeWindow
              : DownloadAccess.expired;
        }
      }
    } catch (_) {}

    // No setup data yet (shouldn't happen post-setup) → treat the free window
    // as active so first-time users are never hard-blocked by a missing row.
    return DownloadAccess.freeWindow;
  }
}