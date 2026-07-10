import 'package:flutter_test/flutter_test.dart';

import 'package:pinball_plunge_shell/media_library.dart';

void main() {
  test('wheel sectors and ball sprites stay in sync', () {
    expect(WheelPalette.sectors.length, MediaLibrary.balls.length);
    expect(WheelPalette.sectors.length, 6);
  });
}
