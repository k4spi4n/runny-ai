import 'package:flutter_test/flutter_test.dart';
import 'package:runny_app/models/readiness_models.dart';

void main() {
  test('readiness snapshot exposes low-confidence and check-in flags', () {
    final snapshot = ReadinessSnapshot.fromJson({'readiness_score': 65, 'readiness_status': 'caution', 'acute_load': 240, 'chronic_load': 180, 'acwr': 1.33, 'has_sufficient_load_data': false, 'pain_flag': false, 'factors': {'needs_checkin': true}});
    expect(snapshot.acwr, 1.33);
    expect(snapshot.hasSufficientLoadData, isFalse);
    expect(snapshot.needsCheckin, isTrue);
  });
}
