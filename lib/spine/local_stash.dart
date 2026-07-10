import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../schema/run_mode.dart';

/// Persistence layer for the shell. Non-sensitive flags live in
/// SharedPreferences; content URLs live in encrypted secure storage.
///
/// Storage keys are deliberately opaque strings — they should not reveal
/// intent when someone dumps the prefs file.
class LocalStash {
  LocalStash({FlutterSecureStorage? secure})
      : _secure = secure ?? const FlutterSecureStorage();

  static const String _kRunMode = 'pin_run_mode_v1';
  static const String _kCachedLink = 'pin_cache_lnk';
  static const String _kLinkExpiry = 'pin_cache_ttl';
  static const String _kAlertUntil = 'pin_alert_gate';
  static const String _kAlertGranted = 'pin_alert_ok';
  static const String _kAlertBlockedByOs = 'pin_alert_no';
  static const String _kPendingLink = 'pin_pending_lnk';

  late final SharedPreferences _prefs;
  final FlutterSecureStorage _secure;

  Future<void> warmUp() async {
    _prefs = await SharedPreferences.getInstance();
  }

  // ── Run mode ──
  RunMode readMode() => RunMode.fromStorage(_prefs.getString(_kRunMode));

  Future<void> writeMode(RunMode mode) =>
      _prefs.setString(_kRunMode, mode.toStorage());

  // ── Cached content link (secure) ──
  Future<String?> readCachedLink() => _secure.read(key: _kCachedLink);

  Future<void> writeCachedLink(String link) =>
      _secure.write(key: _kCachedLink, value: link);

  // ── Link expiry ──
  int? readLinkExpiry() => _prefs.getInt(_kLinkExpiry);

  Future<void> writeLinkExpiry(int unixSeconds) =>
      _prefs.setInt(_kLinkExpiry, unixSeconds);

  bool isLinkExpired() {
    final int? ttl = readLinkExpiry();
    if (ttl == null) return true;
    return _nowSeconds() >= ttl;
  }

  // ── Alert (push) permission state ──
  bool isAlertAllowed() => _prefs.getBool(_kAlertGranted) ?? false;

  Future<void> setAlertAllowed(bool value) =>
      _prefs.setBool(_kAlertGranted, value);

  /// True once the OS-level "denied" was recorded — no further prompts should
  /// be attempted for the lifetime of this install.
  bool isAlertBlockedByOs() =>
      _prefs.getBool(_kAlertBlockedByOs) ?? false;

  Future<void> setAlertBlockedByOs() =>
      _prefs.setBool(_kAlertBlockedByOs, true);

  int? readAlertPromptCooldown() => _prefs.getInt(_kAlertUntil);

  Future<void> writeAlertPromptCooldown(int unixSeconds) =>
      _prefs.setInt(_kAlertUntil, unixSeconds);

  /// Decides whether the notification-permission promo should be shown
  /// before the WebView on this launch.
  bool shouldOfferAlertPrompt() {
    if (isAlertAllowed()) return false;
    if (isAlertBlockedByOs()) return false;
    final int? until = readAlertPromptCooldown();
    if (until == null) return true;
    return _nowSeconds() >= until;
  }

  // ── One-time push link (secure) ──
  Future<void> stashPendingLink(String? link) async {
    if (link == null) {
      await _secure.delete(key: _kPendingLink);
    } else {
      await _secure.write(key: _kPendingLink, value: link);
    }
  }

  Future<String?> takePendingLink() async {
    final String? link = await _secure.read(key: _kPendingLink);
    if (link != null) await _secure.delete(key: _kPendingLink);
    return link;
  }

  static int _nowSeconds() =>
      DateTime.now().millisecondsSinceEpoch ~/ 1000;
}
