/// Parsed reply from the config gateway.
///
/// Backend wire format: `{ ok, url, expires, message }`. The Dart field names
/// diverge from the wire keys on purpose (fingerprint hygiene); JSON parsing
/// still maps to the exact keys the backend contract demands.
class RelayVerdict {
  const RelayVerdict({
    required this.approved,
    this.destination,
    this.diagnostic,
    this.expiresAt,
  });

  /// Backend `ok`. When true and [destination] is non-empty the WebView opens.
  final bool approved;

  /// Backend `url`. The content link to load into the WebView.
  final String? destination;

  /// Backend `message`. Diagnostic hint (e.g. "organic").
  final String? diagnostic;

  /// Backend `expires`. Unix seconds after which [destination] should be
  /// refreshed by a new config request.
  final int? expiresAt;

  factory RelayVerdict.fromJson(Map<String, dynamic> raw) {
    return RelayVerdict(
      approved: raw['ok'] as bool? ?? false,
      destination: raw['url'] as String?,
      diagnostic: raw['message'] as String?,
      expiresAt: raw['expires'] as int?,
    );
  }

  factory RelayVerdict.rejected(String reason) =>
      RelayVerdict(approved: false, diagnostic: reason);

  bool get hasDestination =>
      destination != null && destination!.isNotEmpty;
}
