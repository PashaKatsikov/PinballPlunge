import 'dart:typed_data';

// PinballPlunge string mask — same construction as the template's obfuscator
// (FNV-1a seeded xorshift keystream, positional XOR) but with a fresh seed
// and a different stream length so the bytes at rest differ from any sibling
// project shipping the same architecture.
//
// If you touch _seedPhrase or _streamLength you MUST regenerate every byte
// array in `lib/config/secure_strings.dart` by re-running
// `dart run tool/secret_packer.dart`. Old arrays are silently mis-decoded.

const String _seedPhrase = 'pB!7q_neonPnb2v';
const int _streamLength = 32;

Uint8List _buildStream() {
  int hash = 0x811C9DC5;
  for (final int c in _seedPhrase.codeUnits) {
    hash = (hash ^ c) & 0xFFFFFFFF;
    hash = (hash * 0x01000193) & 0xFFFFFFFF;
  }
  int state = hash == 0 ? 0x9E3779B9 : hash;
  final Uint8List stream = Uint8List(_streamLength);
  for (int i = 0; i < _streamLength; i++) {
    state ^= (state << 13) & 0xFFFFFFFF;
    state ^= state >> 17;
    state ^= (state << 5) & 0xFFFFFFFF;
    state &= 0xFFFFFFFF;
    stream[i] = (state >> 16) & 0xFF;
  }
  return stream;
}

final Uint8List _stream = _buildStream();

/// Decodes an encoded byte list into its original string. Returns "" for
/// an empty payload so the template compiles + runs cleanly before real
/// credentials are packed.
String peel(List<int> packed) {
  if (packed.isEmpty) return '';
  final Uint8List out = Uint8List(packed.length);
  for (int i = 0; i < packed.length; i++) {
    out[i] = (packed[i] ^ _stream[i % _streamLength] ^ (i & 0xFF)) & 0xFF;
  }
  return String.fromCharCodes(out);
}
