import 'dart:convert';
import '../../frontend/shared/models/setup_data.dart';
import '../../frontend/shared/models/premium_status.dart';
import '../../frontend/shared/models/feed_models.dart';

/// Shared logic between AndroidBackend and DesktopBackend
/// to eliminate code duplication in data building and parsing.
class BackendHelpers {
  static Map<String, dynamic> buildSetupData({
    required String locale,
    required String mode,
    required String username,
    String? premiumCode,
    // Preserve existing trial timestamps so the user cannot extend
    // their free trial by restarting setup repeatedly.
    String? existingTrialStartedAt,
    String? existingTrialExpiresAt,
  }) {
    final data = <String, dynamic>{
      'locale': locale,
      'mode': mode,
      'username': username,
      'setup_completed': true,
      'setup_completed_at': DateTime.now().toIso8601String(),
    };
    if (mode == 'free') {
      // If the user already has trial timestamps from a previous setup,
      // preserve them to prevent trial extension abuse.
      data['trial_started_at'] = existingTrialStartedAt ?? DateTime.now().toIso8601String();
      data['trial_expires_at'] = existingTrialExpiresAt ??
          DateTime.now().add(const Duration(hours: 6)).toIso8601String();
      data['trial_used'] = true;
    }
    if (premiumCode != null) {
      data['premium_code'] = premiumCode;
    }
    return data;
  }

  static SetupData? parseSetupData(dynamic result) {
    if (result == null || result == '') return null;
    final decoded = jsonDecode(result as String);
    return SetupData.fromJson(decoded);
  }

  static PremiumStatus parsePremiumStatus(dynamic result) {
    try {
      if (result == null || result == '') {
        return const PremiumStatus(tier: 'free', premiumUntil: 0, activo: false);
      }
      final decoded = jsonDecode(result as String);
      return PremiumStatus.fromJson(decoded);
    } catch (_) {
      return const PremiumStatus(tier: 'free', premiumUntil: 0, activo: false);
    }
  }

  static List<FeedSection> parseFeedSections(dynamic result) {
    try {
      if (result is String && result.isNotEmpty) {
        final list = jsonDecode(result) as List<dynamic>;
        return list
            .map((e) => FeedSection.fromJson(e as Map<String, dynamic>))
            .toList();
      }
      return [];
    } catch (_) {
      return [];
    }
  }

  static String? parseValidationResult(dynamic result) {
    try {
      if (result is String && result.isNotEmpty) {
        result = jsonDecode(result);
      }
      if (result is Map && result['valido'] == true) return null;
      if (result is Map && result['error'] is String) return result['error'];
      return 'Código inválido';
    } catch (_) {
      return 'Código inválido';
    }
  }

  static List<String> parseRecentSearches(dynamic result) {
    try {
      if (result is String && result.isNotEmpty) {
        final list = jsonDecode(result) as List<dynamic>;
        return list.cast<String>();
      }
      return [];
    } catch (_) {
      return [];
    }
  }

  static List<FeedItem> parseSearchResults(dynamic result) {
    try {
      if (result is String && result.isNotEmpty) {
        final list = jsonDecode(result) as List<dynamic>;
        return list
            .map((e) => FeedItem.fromJson(e as Map<String, dynamic>))
            .toList();
      }
      if (result is List) {
        return result.map((e) => FeedItem.fromJson(e as Map<String, dynamic>)).toList();
      }
      return [];
    } catch (_) {
      return [];
    }
  }
}

