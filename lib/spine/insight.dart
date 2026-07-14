import 'package:clarity_flutter/clarity_flutter.dart';

import '../config/insight_env.dart';

/// Crash-safe facade over Microsoft Clarity.
///
/// Session replay captures the native Flutter surface (loading screen,
/// push-invite screen, the game, and the WebView *container*). These calls
/// add funnel signals that answer "where did the user drop off?".
///
/// Rule: NEVER call the Clarity SDK directly — always go through this class.
/// A Clarity failure must never crash the gray flow.
class Insight {
  const Insight._();

  static ClarityConfig get config => ClarityConfig(
        projectId: kClarityProjectId,
        // Verbose while wiring the project so `adb logcat -s Clarity` shows
        // "session uploaded / HTTP 204". Switch to LogLevel.None once the
        // Clarity dashboard confirms the first sessions.
        logLevel: LogLevel.Verbose,
      );

  /// Group the session by AppsFlyer id and attach attribution tags.
  /// No-op on empty id so a missing af_id never wipes a good user id.
  static void identify(String? aid, {Map<String, String> tags = const {}}) {
    if (aid != null && aid.isNotEmpty) {
      _guard(() => Clarity.setCustomUserId(_clip(aid, 255)));
      tag('aid', aid);
    }
    tags.forEach(tag);
  }

  /// Mark the current native screen: sets the screen label AND emits a
  /// stable per-screen event so both replay and the funnel chart work.
  static void screen(String name) {
    screenName(name);
    event('screen_$name');
  }

  /// Sets the Clarity screen label + mirrors it into the persistent
  /// `last_screen` tag (filtering by last_screen = the drop-off screen).
  static void screenName(String name) => _guard(() {
        Clarity.setCurrentScreenName(_clip(name, 255));
        Clarity.setCustomTag('last_screen', _clip(name, 255));
      });

  /// Emit a custom event. Keep names STABLE and few; put high-cardinality
  /// values (urls, labels, error text) in tags, not event names.
  static void event(String name) =>
      _guard(() => Clarity.sendCustomEvent(_clip(name, 254)));

  /// Attach a key-value tag to the session. Empty values are silently
  /// dropped so callers never have to guard against empty strings.
  static void tag(String key, String value) {
    if (value.isEmpty) return;
    _guard(() => Clarity.setCustomTag(key, _clip(value, 255)));
  }

  // ── internals ──────────────────────────────────────────────────────────

  static String _clip(String v, int max) =>
      v.length <= max ? v : v.substring(0, max);

  static void _guard(void Function() body) {
    try {
      body();
    } catch (_) {}
  }
}
