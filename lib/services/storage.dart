import 'package:shared_preferences/shared_preferences.dart';

/// Lightweight persistence for the player's records.
class Storage {
  Storage._();

  static const String _kBestScore = 'best_score';
  static const String _kBestStreak = 'best_streak';
  static const String _kTotalHits = 'total_hits';
  static const String _kGamesPlayed = 'games_played';

  static SharedPreferences? _prefs;

  static Future<void> init() async {
    _prefs ??= await SharedPreferences.getInstance();
  }

  static int get bestScore => _prefs?.getInt(_kBestScore) ?? 0;
  static int get bestStreak => _prefs?.getInt(_kBestStreak) ?? 0;
  static int get totalHits => _prefs?.getInt(_kTotalHits) ?? 0;
  static int get gamesPlayed => _prefs?.getInt(_kGamesPlayed) ?? 0;

  static Future<void> saveResult({
    required int score,
    required int streak,
    required int hits,
  }) async {
    final prefs = _prefs;
    if (prefs == null) return;
    if (score > bestScore) await prefs.setInt(_kBestScore, score);
    if (streak > bestStreak) await prefs.setInt(_kBestStreak, streak);
    await prefs.setInt(_kTotalHits, totalHits + hits);
    await prefs.setInt(_kGamesPlayed, gamesPlayed + 1);
  }
}
