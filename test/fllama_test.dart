import 'package:flutter_test/flutter_test.dart';
import 'package:fllama/fllama.dart';

void main() {
  test('fllama API verification', () {
    final fllama = Fllama.instance();
    expect(fllama, isNotNull);
  });
}
