import 'package:flutter_test/flutter_test.dart';
import 'package:oasyara_1/core/utils/time_utils.dart';

void main() {
  group('Greeting Logic Tests', () {
    test('Morning greeting (05:00 - 11:59)', () {
      expect(getGreeting(DateTime(2026, 8, 20, 5, 0)), 'Good morning');
      expect(getGreeting(DateTime(2026, 8, 20, 11, 59)), 'Good morning');
    });

    test('Afternoon greeting (12:00 - 16:59)', () {
      expect(getGreeting(DateTime(2026, 8, 20, 12, 0)), 'Good afternoon');
      expect(getGreeting(DateTime(2026, 8, 20, 16, 59)), 'Good afternoon');
    });

    test('Evening greeting (17:00 - 20:59)', () {
      expect(getGreeting(DateTime(2026, 8, 20, 17, 0)), 'Good evening');
      expect(getGreeting(DateTime(2026, 8, 20, 20, 59)), 'Good evening');
    });

    test('Night greeting (21:00 - 04:59)', () {
      expect(getGreeting(DateTime(2026, 8, 20, 21, 0)), 'Good night');
      expect(getGreeting(DateTime(2026, 8, 20, 0, 0)), 'Good night');
      expect(getGreeting(DateTime(2026, 8, 20, 4, 59)), 'Good night');
    });
  });
}
