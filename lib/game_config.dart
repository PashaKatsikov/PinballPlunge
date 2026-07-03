import 'package:flutter/material.dart';

/// Central place for asset paths and the color/sector configuration that ties
/// the rotating wheel, the balls and the hit-detection together.
class Assets {
  Assets._();

  static const String _additional = 'assets/Pinball_Plunge_additional_assets';
  static const String _gameplay = 'assets/Pinball_Plunge_gameplay_assets';

  static const String gameName = '$_additional/Game_Name.webp';
  static const String verticalLoading = '$_additional/Vertical_Loading_Screen.webp';
  static const String horizontalLoading = '$_additional/Horizontal_Loading_Screen.webp';

  static const String wheel = '$_gameplay/rotating_wheel_asset.webp';
  static const String bg1 = '$_gameplay/bg1_asset.webp';
  static const String bg2 = '$_gameplay/bg2_asset.webp';
  static const String bg3 = '$_gameplay/bg3_asset.webp';

  /// Ball sprites ordered to match [GameColors.sectors] indices.
  static const List<String> balls = <String>[
    '$_gameplay/pink_ball_asset.webp', // 0 magenta
    '$_gameplay/yellow_ball_asset.webp', // 1 yellow
    '$_gameplay/green_ball_asset.webp', // 2 green
    '$_gameplay/blue_ball_asset.webp', // 3 blue
    '$_gameplay/orange_ball_asset.webp', // 4 orange
    '$_gameplay/cyan_ball_asset.webp', // 5 cyan
  ];
}

/// Colors of the six wheel sectors.
///
/// The order matches the rotating wheel sprite when rendered without rotation:
/// index 0 sits in the top-right sector (center at 30 degrees clockwise from
/// the top) and the following indices continue clockwise every 60 degrees.
class GameColors {
  GameColors._();

  static const List<Color> sectors = <Color>[
    Color(0xFFFF2FB3), // 0 magenta / pink
    Color(0xFFFFD400), // 1 yellow
    Color(0xFF3BD62B), // 2 green
    Color(0xFF1E7BFF), // 3 blue
    Color(0xFFFF7A18), // 4 orange
    Color(0xFF23D6E0), // 5 cyan
  ];

  static const List<String> names = <String>[
    'Pink',
    'Yellow',
    'Green',
    'Blue',
    'Orange',
    'Cyan',
  ];

  static int get count => sectors.length;
}

class AppTheme {
  AppTheme._();

  static const Color background = Color(0xFF0B0B2E);
  static const Color panel = Color(0xCC15123A);
  static const Color accent = Color(0xFF7A5CFF);
  static const Color textPrimary = Colors.white;
  static const Color textSecondary = Color(0xFFB9B4E6);
}
