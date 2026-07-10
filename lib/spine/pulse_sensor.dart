import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';

/// Adapters we treat as "there is a real network path". VPN is included on
/// purpose — connectivity_plus emits a VPN-only state while the tunnel is
/// being brought up and users can genuinely reach the internet through it.
const Set<ConnectivityResult> _kLiveAdapters = <ConnectivityResult>{
  ConnectivityResult.wifi,
  ConnectivityResult.mobile,
  ConnectivityResult.ethernet,
  ConnectivityResult.vpn,
  ConnectivityResult.bluetooth,
  ConnectivityResult.other,
};

/// Connectivity + DNS-probe helper. Adapter state alone is not enough —
/// captive portals and limited networks still report an active interface.
class PulseSensor {
  PulseSensor({Connectivity? connectivity})
      : _connectivity = connectivity ?? Connectivity();

  final Connectivity _connectivity;

  /// Adapter state → DNS probe. Returns true only when a real hostname
  /// resolves within the probe budget.
  ///
  /// Timeout is 7 seconds by design — genuine "no internet" throws
  /// SocketException instantly, so the larger budget is free and it prevents
  /// false-negatives when a VPN tunnel adds latency to the resolver.
  Future<bool> isOnline() async {
    final List<ConnectivityResult> adapters =
        await _connectivity.checkConnectivity();
    final bool anyLive =
        adapters.any((ConnectivityResult s) => _kLiveAdapters.contains(s));
    if (!anyLive) return false;

    try {
      final List<InternetAddress> probe = await InternetAddress.lookup(
        'cloudflare.com',
      ).timeout(const Duration(seconds: 7));
      return probe.isNotEmpty && probe.first.rawAddress.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  Stream<List<ConnectivityResult>> get updates =>
      _connectivity.onConnectivityChanged;
}
