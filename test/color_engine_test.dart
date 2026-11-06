import 'package:flutter_test/flutter_test.dart';
import 'package:pindou_studio/services/color_engine.dart';

void main() {
  test('CIEDE2000 returns zero for identical Lab values', () {
    final engine = ColorEngine();
    expect(engine.deltaE2000([50, 2.5, -10], [50, 2.5, -10]), closeTo(0, 0.0001));
  });
}

