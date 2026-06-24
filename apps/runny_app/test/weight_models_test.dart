import 'package:flutter_test/flutter_test.dart';
import 'package:runny_app/models/weight_models.dart';

void main() {
  group('WeightGoal - tiến trình giảm cân', () {
    final goal = WeightGoal(start: 80, current: 75, target: 70);

    test('nhận diện đúng hướng giảm cân', () {
      expect(goal.hasGoal, isTrue);
      expect(goal.isLosing, isTrue);
    });

    test('tính tổng delta và phần đã đạt', () {
      expect(goal.totalDelta, 10); // 80 -> 70
      expect(goal.achievedDelta, 5); // 80 -> 75
    });

    test('tính phần còn lại và tỉ lệ hoàn thành', () {
      expect(goal.remaining, 5); // 75 -> 70
      expect(goal.progress, closeTo(0.5, 1e-9));
      expect(goal.reached, isFalse);
    });
  });

  group('WeightGoal - tiến trình tăng cân', () {
    final goal = WeightGoal(start: 60, current: 63, target: 66);

    test('nhận diện hướng tăng cân', () {
      expect(goal.isLosing, isFalse);
    });

    test('tỉ lệ hoàn thành đúng', () {
      expect(goal.totalDelta, 6);
      expect(goal.achievedDelta, 3);
      expect(goal.progress, closeTo(0.5, 1e-9));
    });
  });

  group('WeightGoal - các trường hợp biên', () {
    test('chưa đặt mục tiêu thì mọi chỉ số = 0', () {
      final g = WeightGoal(current: 70);
      expect(g.hasGoal, isFalse);
      expect(g.progress, 0);
      expect(g.remaining, 0);
      expect(g.totalDelta, 0);
    });

    test('đạt mục tiêu thì reached = true và progress clamp về 1', () {
      final g = WeightGoal(start: 80, current: 70, target: 70);
      expect(g.reached, isTrue);
      expect(g.remaining, 0);
      expect(g.progress, 1);
    });

    test('vượt mục tiêu vẫn clamp progress = 1, remaining = 0', () {
      final g = WeightGoal(start: 80, current: 68, target: 70);
      expect(g.progress, 1);
      expect(g.remaining, 0);
      expect(g.reached, isTrue);
    });

    test('fromProfile ánh xạ đúng các cột', () {
      final g = WeightGoal.fromProfile({
        'weight_kg': 75,
        'target_weight_kg': 70,
        'start_weight_kg': 80,
      });
      expect(g.current, 75);
      expect(g.target, 70);
      expect(g.start, 80);
      expect(g.hasGoal, isTrue);
    });
  });

  group('WeightLog.fromJson', () {
    test('parse đầy đủ các trường', () {
      final log = WeightLog.fromJson({
        'id': 'w1',
        'weight_kg': 72.5,
        'logged_at': '2026-06-19T08:00:00.000Z',
        'note': 'sau buổi chạy',
      });
      expect(log.id, 'w1');
      expect(log.weightKg, 72.5);
      expect(log.loggedAt.toUtc(), DateTime.utc(2026, 6, 19, 8));
      expect(log.note, 'sau buổi chạy');
    });

    test('note có thể null', () {
      final log = WeightLog.fromJson({
        'id': 'w2',
        'weight_kg': 70,
        'logged_at': '2026-06-19T08:00:00.000Z',
      });
      expect(log.note, isNull);
    });
  });
}
