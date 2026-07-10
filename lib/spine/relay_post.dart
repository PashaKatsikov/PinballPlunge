import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../config/pinboard_brief.dart';
import '../schema/relay_verdict.dart';
import 'local_stash.dart';
import 'masked_http.dart';

/// Posts the assembled attribution body to the gate endpoint and parses the
/// verdict. Successful responses are cached (link + expiry) so returning
/// launches can fall back to the last-known-good URL if the network later
/// fails.
class RelayPost {
  RelayPost(this._stash);

  final LocalStash _stash;

  Future<RelayVerdict> query(Map<String, dynamic> body) async {
    final String endpoint = PinboardBrief.relayEndpoint;
    if (endpoint.isEmpty) {
      return RelayVerdict.rejected('no-endpoint');
    }

    try {
      final dynamic response = await maskedNet
          .post(
            Uri.parse(endpoint),
            headers: <String, String>{
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 15));

      if (kDebugMode) {
        debugPrint(
          '[RelayPost] status=${response.statusCode} body=${response.body}',
        );
      }
      if (response.statusCode != 200) {
        return RelayVerdict.rejected('http-${response.statusCode}');
      }

      final Map<String, dynamic> map =
          jsonDecode(response.body) as Map<String, dynamic>;
      final RelayVerdict verdict = RelayVerdict.fromJson(map);

      if (verdict.approved && verdict.hasDestination) {
        await _stash.writeCachedLink(verdict.destination!);
        if (verdict.expiresAt != null) {
          await _stash.writeLinkExpiry(verdict.expiresAt!);
        }
      }
      return verdict;
    } catch (e) {
      return RelayVerdict.rejected(e.toString());
    }
  }
}
