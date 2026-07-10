import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:http/http.dart' as http;

import '../config/secure_strings.dart';

/// http.Client that stamps every outbound request with a forged Chrome
/// User-Agent derived from real device info. The same UA is applied to the
/// WebView so partner backends see a consistent identity across both
/// channels.
class MaskedHttp extends http.BaseClient {
  final http.Client _delegate = http.Client();
  String _ua = 'Mozilla/5.0';

  String get userAgent => _ua;

  /// Reads device info + resolved Chrome/WebKit fragments and assembles the
  /// UA. Must be called once during bootstrap, before any request goes out.
  Future<void> stitch() async {
    final String chrome = _fallback(revealChromeVersion(), '149.0.0.0');
    final String webkit = _fallback(revealWebkitVersion(), '537.36');

    try {
      final DeviceInfoPlugin plugin = DeviceInfoPlugin();
      if (Platform.isAndroid) {
        final AndroidDeviceInfo info = await plugin.androidInfo;
        final String build = info.display.isNotEmpty ? info.display : info.id;
        _ua = 'Mozilla/5.0 (Linux; Android ${info.version.release}; '
            '${info.brand} ${info.model} Build/$build) '
            'AppleWebKit/$webkit (KHTML, like Gecko) '
            'Chrome/$chrome Mobile Safari/$webkit';
      } else if (Platform.isIOS) {
        final IosDeviceInfo info = await plugin.iosInfo;
        final String os = info.systemVersion.replaceAll('.', '_');
        _ua = 'Mozilla/5.0 (iPhone; CPU iPhone OS $os like Mac OS X) '
            'AppleWebKit/$webkit (KHTML, like Gecko) '
            'Version/${info.systemVersion} Mobile/15E148 Safari/$webkit';
      }
    } catch (_) {
      _ua = 'Mozilla/5.0 (Linux; Android 14; Pixel 8 Build/UP1A) '
          'AppleWebKit/$webkit (KHTML, like Gecko) '
          'Chrome/$chrome Mobile Safari/$webkit';
    }
  }

  static String _fallback(String value, String backup) =>
      value.isNotEmpty ? value : backup;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    request.headers.putIfAbsent('User-Agent', () => _ua);
    return _delegate.send(request);
  }

  @override
  void close() => _delegate.close();
}

/// Single shared HTTP client used by every spine bridge.
final MaskedHttp maskedNet = MaskedHttp();
