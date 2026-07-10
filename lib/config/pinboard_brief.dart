import 'legal_links.dart';
import 'secure_strings.dart';

/// Central bag of app-wide constants. Plain identity values are inline,
/// sensitive endpoints/credentials flow through the obfuscator so plaintext
/// never lands in the compiled binary.
class PinboardBrief {
  PinboardBrief._();

  /// Android applicationId + iOS bundle id. Must match
  /// android/app/build.gradle.kts (applicationId + namespace) and the
  /// google-services.json package_name.
  static const String packageId = 'com.pinplunge.pinballplunge';

  /// Store id. Android == packageId; iOS would prefix the numeric App Store
  /// id with literal `id`. Sent to the backend as `store_id`.
  static const String marketId = 'com.pinplunge.pinballplunge';

  /// Human-readable name — must match android:label + Play Console listing.
  static const String displayName = 'Pinball Plunge';

  /// iOS numeric App Store id (unused on Android — kept empty on purpose).
  static const String storeNumericId = '';

  /// Resolved sensitive values.
  static String get relayEndpoint => revealRelayEndpoint();
  static String get trackerKey => revealTrackerKey();
  static String get messagingProject => revealMessagingProject();

  /// Public non-sensitive links.
  static const String privacyUrl = kPrivacyPolicyUrl;
  static const String helpUrl = kSupportUrl;
  static const String homeUrl = kSiteHome;

  /// Re-prompt the push invite this many seconds after a Skip (3 days).
  static const int alertPromptCooldown = 3 * 24 * 60 * 60;

  /// Delay before re-checking attribution via GCD when the SDK reported
  /// `af_status: Organic` on the first callback.
  static const int organicRecheckDelay = 5;
}
