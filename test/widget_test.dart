import 'package:flutter_test/flutter_test.dart';

import 'package:pinballplunge/game_config.dart';

void main() {
  test('wheel sectors and ball sprites stay in sync', () {
    expect(GameColors.sectors.length, Assets.balls.length);
    expect(GameColors.sectors.length, 6);
  });
}
