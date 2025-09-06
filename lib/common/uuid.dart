import 'dart:math';

/// Simple ULID-like sortable id (not cryptographically secure).
String newId() {
  final millis = DateTime.now().toUtc().millisecondsSinceEpoch;
  final rand = Random.secure();
  final r = List<int>.generate(10, (_) => rand.nextInt(256));
  final b = <int>[]
    ..addAll(_toBase32Time(millis))
    ..addAll(_toBase32(r));
  return String.fromCharCodes(b);
}

const _alphabet = '0123456789ABCDEFGHJKMNPQRSTVWXYZ';

List<int> _toBase32Time(int ms) {
  final out = List<int>.filled(10, 0);
  var v = ms;
  for (var i = 9; i >= 0; i--) {
    out[i] = _alphabet.codeUnitAt(v % 32);
    v ~/= 32;
  }
  return out;
}

List<int> _toBase32(List<int> bytes) {
  // 10 random bytes -> 16 base32 chars
  int buffer = 0, bits = 0;
  final out = <int>[];
  for (final b in bytes) {
    buffer = (buffer << 8) | (b & 0xff);
    bits += 8;
    while (bits >= 5) {
      bits -= 5;
      final idx = (buffer >> bits) & 31;
      out.add(_alphabet.codeUnitAt(idx));
    }
  }
  if (bits > 0) {
    final idx = (buffer << (5 - bits)) & 31;
    out.add(_alphabet.codeUnitAt(idx));
  }
  // ensure 16 chars
  while (out.length < 16) out.add(_alphabet.codeUnitAt(0));
  return out.take(16).toList();
}
