class PeerInfo {
  final String deviceId;
  final String username; // sales/admin display
  final String? phone;   // for SMS
  final String? email;   // for Email
  final bool isAdmin;    // true if this is the admin device (hub)

  const PeerInfo({
    required this.deviceId,
    required this.username,
    required this.isAdmin,
    this.phone,
    this.email,
  });
}
