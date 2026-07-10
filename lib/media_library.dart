import 'package:flutter/material.dart';

/// Central place for asset paths and the color/sector configuration that ties
/// the rotating wheel, the balls and the hit-detection together. Keep every
/// literal path routed through here — the fingerprint folder name is
/// declared once and reused everywhere.
class MediaLibrary {
  MediaLibrary._();

  static const String _extra = 'assets/Pinball_Plunge_additional_assets';
  static const String _gameplay = 'assets/Pinball_Plunge_gameplay_assets';

  // Branding / gameplay art.
  static const String gameName = '$_extra/Game_Name.webp';
  static const String wheel = '$_gameplay/rotating_wheel_asset.webp';
  static const String bg1 = '$_gameplay/bg1_asset.webp';
  static const String bg2 = '$_gameplay/bg2_asset.webp';
  static const String bg3 = '$_gameplay/bg3_asset.webp';

  // Shell (gray-flow) screen backgrounds. Each ships portrait + landscape.
  static const String verticalLoading = '$_extra/Vertical_Loading_Screen.webp';
  static const String horizontalLoading =
      '$_extra/Horizontal_Loading_Screen.webp';
  static const String verticalNoWifi = '$_extra/Vertical_Nowifi_Screen.webp';
  static const String horizontalNoWifi =
      '$_extra/Horizontal_Nowifi_Screen.webp';
  static const String verticalAlerts =
      '$_extra/Vertical_Notifications_Screen.webp';
  static const String horizontalAlerts =
      '$_extra/Horizontal_Notifications_Screen.webp';

  /// Ball sprites ordered to match [WheelPalette.sectors] indices.
  static const List<String> balls = <String>[
    '$_gameplay/pink_ball_asset.webp', // 0 magenta
    '$_gameplay/yellow_ball_asset.webp', // 1 yellow
    '$_gameplay/green_ball_asset.webp', // 2 green
    '$_gameplay/blue_ball_asset.webp', // 3 blue
    '$_gameplay/orange_ball_asset.webp', // 4 orange
    '$_gameplay/cyan_ball_asset.webp', // 5 cyan
  ];

  /// Every image that should be precached before the arcade opens.
  static const List<String> arcadeArt = <String>[
    gameName,
    wheel,
    bg1,
    bg2,
    bg3,
    ...balls,
  ];
}

/// Six colors of the rotating wheel sectors. Index 0 sits in the top-right
/// sector when the wheel sprite is rendered without rotation; subsequent
/// indices continue clockwise every 60 degrees.
class WheelPalette {
  WheelPalette._();

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

/// Shared dark neon palette used by every screen.
class AppTheme {
  AppTheme._();

  static const Color background = Color(0xFF0B0B2E);
  static const Color panel = Color(0xCC15123A);
  static const Color accent = Color(0xFF7A5CFF);
  static const Color hot = Color(0xFFFF2FB3);
  static const Color cold = Color(0xFF23D6E0);
  static const Color gold = Color(0xFFFFD400);
  static const Color textPrimary = Colors.white;
  static const Color textSecondary = Color(0xFFB9B4E6);
}
