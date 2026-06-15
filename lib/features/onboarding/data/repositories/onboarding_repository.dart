import 'package:shared_preferences/shared_preferences.dart';
import '../models/setup_step.dart';

class OnboardingRepository {
  static const _firstLaunchKey = 'first_launch';
  static const _setupCompletedKey = 'setup_completed';
  static const _usernameKey = 'username';
  static const _premiumCodeKey = 'premium_code';
  static const _tutorialShownKey = 'tutorial_shown';

  Future<bool> isFirstLaunch() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_firstLaunchKey) ?? true;
  }

  Future<void> completeSetup() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_setupCompletedKey, true);
    await prefs.setBool(_firstLaunchKey, false);
  }

  Future<SetupStep> getSetupStep() async {
    final prefs = await SharedPreferences.getInstance();
    final completed = prefs.getBool(_setupCompletedKey) ?? false;
    if (completed) return SetupStep.complete;
    final username = prefs.getString(_usernameKey);
    if (username != null && username.isNotEmpty) return SetupStep.directories;
    final premium = prefs.getString(_premiumCodeKey);
    if (premium != null && premium.isNotEmpty) return SetupStep.username;
    return SetupStep.welcome;
  }

  Future<void> saveUsername(String username) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_usernameKey, username);
  }

  Future<void> savePremiumCode(String code) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_premiumCodeKey, code);
  }

  Future<bool> isSetupCompleted() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_setupCompletedKey) ?? false;
  }

  Future<bool> validatePremiumCode(String code) async {
    await Future.delayed(const Duration(milliseconds: 500));
    return code.length >= 6;
  }

  Future<void> setTutorialShown() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_tutorialShownKey, true);
  }

  Future<bool> isTutorialShown() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_tutorialShownKey) ?? false;
  }
}
