import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:appsflyer_sdk/appsflyer_sdk.dart';
import 'package:flutter/foundation.dart';

import '../config/pinboard_brief.dart';
import '../config/secure_strings.dart';
import 'masked_http.dart';

/// AppsFlyer wrapper. Collects install conversion + deep-link + app-open
/// attribution payloads and folds them into the final gate request body.
///
/// Guards against the "false Organic" first-callback: when `af_status`
/// arrives as "Organic" we wait a short cooldown and re-fetch attribution
/// through the GCD REST endpoint. The last-received payload wins.
///
/// When no dev key is configured yet the bridge short-circuits: the install
/// completer fires immediately with an empty map so the shell does not stall
/// waiting 30s for attribution that will never come.
class TrackerLink {
  AppsflyerSdk? _sdk;

  Map<String, dynamic>? _installPayload;
  Map<String, dynamic>? _deepLinkPayload;
  Map<String, dynamic>? _appOpenPayload;

  final Completer<Map<String, dynamic>> _installReady =
      Completer<Map<String, dynamic>>();
  final Completer<void> _deepLinkReady = Completer<void>();

  bool _spooled = false;

  /// Initializes the SDK once. Safe to call more than once.
  Future<void> spool() async {
    if (_spooled) return;
    _spooled = true;

    final String key = PinboardBrief.trackerKey;
    if (key.isEmpty) {
      _finishInstall(<String, dynamic>{});
      _finishDeepLink();
      return;
    }

    final AppsFlyerOptions options = AppsFlyerOptions(
      afDevKey: key,
      appId: PinboardBrief.storeNumericId,
      showDebug: kDebugMode,
      timeToWaitForATTUserAuthorization: 10,
    );

    final AppsflyerSdk sdk = AppsflyerSdk(options);
    _sdk = sdk;

    sdk.onInstallConversionData((dynamic res) async {
      final Map<String, dynamic> payload = _unwrap(res);
      if (kDebugMode) {
        debugPrint('[TrackerLink] onInstallConversionData: $payload');
      }
      final String? status = payload['af_status']?.toString();
      if (status == 'Organic') {
        await Future<void>.delayed(
          Duration(seconds: PinboardBrief.organicRecheckDelay),
        );
        final Map<String, dynamic>? recheck = await _gcdRecheck();
        if (kDebugMode) {
          debugPrint('[TrackerLink] GCD retry data: $recheck');
        }
        _installPayload = recheck ?? payload;
      } else {
        _installPayload = payload;
      }
      _finishInstall(_installPayload ?? <String, dynamic>{});
    });

    sdk.onAppOpenAttribution((dynamic res) {
      _appOpenPayload = _unwrap(res);
    });

    sdk.onDeepLinking((DeepLinkResult result) {
      final Map<String, dynamic>? click = result.deepLink?.clickEvent;
      if (click != null) {
        _deepLinkPayload = Map<String, dynamic>.from(click);
        if (kDebugMode) {
          debugPrint('[TrackerLink] onDeepLinking: $_deepLinkPayload');
        }
      }
      _finishDeepLink();
    });

    try {
      await sdk.initSdk(
        registerConversionDataCallback: true,
        registerOnAppOpenAttributionCallback: true,
        registerOnDeepLinkingCallback: true,
      );
    } catch (_) {
      _finishInstall(<String, dynamic>{});
      _finishDeepLink();
    }
  }

  Future<Map<String, dynamic>> awaitInstallPayload({int seconds = 30}) {
    return _installReady.future.timeout(
      Duration(seconds: seconds),
      onTimeout: () => <String, dynamic>{},
    );
  }

  Future<void> awaitDeepLink() {
    return _deepLinkReady.future
        .timeout(const Duration(seconds: 5), onTimeout: () {});
  }

  Future<String?> deviceId() async {
    if (_sdk == null) return null;
    try {
      return await _sdk!.getAppsFlyerUID();
    } catch (_) {
      return null;
    }
  }

  /// Builds the merged gate request body. Merge order (first-write-wins for
  /// attribution keys, device-side fields overwrite last):
  ///   1. install conversion data (verbatim, every key)
  ///   2. deep-link click event (putIfAbsent)
  ///   3. app-open attribution (putIfAbsent)
  ///   4. device-side keys (overwrite)
  Future<Map<String, dynamic>> assembleGateBody({
    required String locale,
    String? pushToken,
  }) async {
    final Map<String, dynamic> body = <String, dynamic>{};

    if (_installPayload != null) body.addAll(_installPayload!);
    _deepLinkPayload
        ?.forEach((String k, dynamic v) => body.putIfAbsent(k, () => v));
    _appOpenPayload
        ?.forEach((String k, dynamic v) => body.putIfAbsent(k, () => v));

    body['af_id'] = await deviceId() ?? '';
    body['bundle_id'] = PinboardBrief.packageId;
    body['os'] = Platform.isAndroid ? 'Android' : 'iOS';
    body['store_id'] = PinboardBrief.marketId;
    body['locale'] = locale;

    // NEVER send push_token as "" or null — omit the key entirely so the
    // backend can distinguish "FCM not initialised" from "empty token".
    if (pushToken != null && pushToken.isNotEmpty) {
      body['push_token'] = pushToken;
    }
    final String project = PinboardBrief.messagingProject;
    if (project.isNotEmpty) {
      body['firebase_project_id'] = project;
    }

    if (kDebugMode) {
      debugPrint('[TrackerLink] Request body: ${jsonEncode(body)}');
    }
    return body;
  }

  Future<Map<String, dynamic>?> _gcdRecheck() async {
    try {
      final String? id = await deviceId();
      if (id == null) return null;
      final String appId = Platform.isIOS
          ? PinboardBrief.storeNumericId
          : PinboardBrief.packageId;
      final String url = revealGcdUrl(appId, id);
      if (url.isEmpty) return null;

      final dynamic response = await maskedNet.get(
        Uri.parse(url),
        headers: <String, String>{
          'authorization': 'Bearer ${PinboardBrief.trackerKey}',
        },
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
    } catch (_) {}
    return null;
  }

  void _finishInstall(Map<String, dynamic> data) {
    if (!_installReady.isCompleted) _installReady.complete(data);
  }

  void _finishDeepLink() {
    if (!_deepLinkReady.isCompleted) _deepLinkReady.complete();
  }

  static Map<String, dynamic> _unwrap(dynamic res) {
    if (res is! Map) return <String, dynamic>{};
    final dynamic inner = res['payload'] ?? res['data'] ?? res;
    if (inner is Map) {
      return inner.map(
        (dynamic k, dynamic v) =>
            MapEntry<String, dynamic>(k.toString(), v),
      );
    }
    return <String, dynamic>{};
  }
}
