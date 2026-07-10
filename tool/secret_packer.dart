// ignore_for_file: avoid_print
// Encodes secrets for PinballPlunge. Mirrors lib/mask/obfuscator.dart.
// Run with `dart run tool/secret_packer.dart` and paste the byte arrays
// into lib/config/secure_strings.dart. Never use PowerShell — 32-bit
// integer overflow corrupts the bytes.

const String seedPhrase = 'pB!7q_neonPnb2v';
const int streamLength = 32;

List<int> buildStream() {
  int hash = 0x811C9DC5;
  for (final int c in seedPhrase.codeUnits) {
    hash = (hash ^ c) & 0xFFFFFFFF;
    hash = (hash * 0x01000193) & 0xFFFFFFFF;
  }
  int state = hash == 0 ? 0x9E3779B9 : hash;
  final List<int> stream = List<int>.filled(streamLength, 0);
  for (int i = 0; i < streamLength; i++) {
    state ^= (state << 13) & 0xFFFFFFFF;
    state ^= state >> 17;
    state ^= (state << 5) & 0xFFFFFFFF;
    state &= 0xFFFFFFFF;
    stream[i] = (state >> 16) & 0xFF;
  }
  return stream;
}

final List<int> stream = buildStream();

List<int> pack(String plain) {
  final List<int> bytes = plain.codeUnits;
  final List<int> out = List<int>.filled(bytes.length, 0);
  for (int i = 0; i < bytes.length; i++) {
    out[i] = (bytes[i] ^ stream[i % streamLength] ^ (i & 0xFF)) & 0xFF;
  }
  return out;
}

void emit(String label, String plain) {
  if (plain.isEmpty) {
    print('// $label — (empty, fill in later)');
    print('const <int>[];\n');
    return;
  }
  final List<int> packed = pack(plain);
  print('// $label  <= "$plain"');
  print('const <int>[${packed.join(', ')}],\n');
}

void main() {
  // Fill these before shipping. Empty values are fine while credentials
  // are pending — the gate call short-circuits and the game path runs.
  const String relayEndpoint = 'https://pinballplunge.com/config.php';
  const String gcdBase = 'https://gcdsdk.appsflyer.com/install_data/v4.0/';

  // Chrome build/patch picked at random per project — must be unique
  // across the whole sibling app family.
  const String chromeVersion = '149.0.7842.87';
  const String webkitVersion = '537.36';

  // Provided by the manager.
  const String trackerKey = 'trYUjQjgpCuUEqkmjDRNoL';
  const String messagingProject = '315310473002';

  print('=== Pinball Plunge secret_packer ===\n');
  emit('relayEndpoint', relayEndpoint);
  emit('gcdBase', gcdBase);
  emit('chromeVersion', chromeVersion);
  emit('webkitVersion', webkitVersion);
  emit('trackerKey', trackerKey);
  emit('messagingProject', messagingProject);
}
