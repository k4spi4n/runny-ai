import 'package:shared_preferences/shared_preferences.dart';

/// Stores the calculation method shared by manual activity and workout forms.
class WorkoutInputPreference {
  static const _usesPaceKey = 'workout_input_uses_pace';

  static Future<bool> loadUsesPace() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_usesPaceKey) ?? true;
  }

  static Future<void> saveUsesPace(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_usesPaceKey, value);
  }
}
