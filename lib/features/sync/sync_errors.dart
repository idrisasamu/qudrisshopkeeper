String friendlySyncError(Object e) {
  final s = e.toString();
  if (s.contains('Missing shop key')) return 'Missing shop key. Ask the owner to re-share (scan QR).';
  if (s.contains('cipher too short') || s.contains('MAC')) return 'Can\'t decrypt message. Your shop key may be outdated.';
  if (s.contains('insufficientPermissions')) return 'Drive permission denied. Ask owner to add your email.';
  if (s.contains('network_error') || s.contains('SocketException')) return 'Network problem. Try again when online.';
  return 'Sync error: $s';
}
