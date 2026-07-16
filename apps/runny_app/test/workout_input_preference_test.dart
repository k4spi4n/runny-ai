import 'package:flutter_test/flutter_test.dart';
import 'package:runny_app/services/workout_input_preference.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('uses pace by default and persists the selected input mode', () async {
    SharedPreferences.setMockInitialValues({});
    expect(await WorkoutInputPreference.loadUsesPace(), isTrue);

    await WorkoutInputPreference.saveUsesPace(false);
    expect(await WorkoutInputPreference.loadUsesPace(), isFalse);
  });
}
