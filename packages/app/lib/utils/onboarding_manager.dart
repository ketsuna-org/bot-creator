import 'package:shared_preferences/shared_preferences.dart';

/// Manages onboarding state and persistence.
/// Tracks which steps have been completed, can skip entire onboarding, etc.
class OnboardingManager {
  static const String _keyFirstRunCompleted = 'onboarding_first_run_completed';
  static const String _keyCurrentStep = 'onboarding_current_step';
  static const String _keySkipped = 'onboarding_skipped';

  final SharedPreferences _prefs;

  OnboardingManager(this._prefs);

  /// Check if this is the first run of the app (onboarding not completed)
  bool get isFirstRun => _prefs.getBool(_keyFirstRunCompleted) != true;

  /// Get the current onboarding step (1-5)
  int get currentStep => _prefs.getInt(_keyCurrentStep) ?? 1;

  /// Check if onboarding was skipped by user
  bool get wasSkipped => _prefs.getBool(_keySkipped) ?? false;

  /// Mark a specific step as current
  Future<void> setCurrentStep(int step) async {
    await _prefs.setInt(_keyCurrentStep, step);
  }

  /// Mark onboarding as completed
  Future<void> completeOnboarding() async {
    await _prefs.setBool(_keyFirstRunCompleted, true);
    await _prefs.setInt(_keyCurrentStep, 1);
  }

  /// Mark onboarding as skipped by user
  Future<void> skipOnboarding() async {
    await _prefs.setBool(_keySkipped, true);
    await _prefs.setBool(_keyFirstRunCompleted, true);
  }

  /// Reset onboarding (for development/testing)
  Future<void> reset() async {
    await _prefs.remove(_keyFirstRunCompleted);
    await _prefs.remove(_keyCurrentStep);
    await _prefs.remove(_keySkipped);
  }
}
