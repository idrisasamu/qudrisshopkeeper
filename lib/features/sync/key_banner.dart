import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../staff/shop_join_fallback_page.dart';
import 'drive_client.dart';

class KeyBanner extends StatelessWidget {
  final int? requiredVersion;
  const KeyBanner({super.key, this.requiredVersion});

  @override
  Widget build(BuildContext context) {
    return MaterialBanner(
      content: Text(
        requiredVersion == null
            ? 'Missing shop key. Ask the owner to re-share (scan QR).'
            : 'Shop key rotated to v$requiredVersion. Scan the new QR from the owner to continue.',
      ),
      actions: [
        TextButton(
          onPressed: () {
            // Navigate to QR/manual join fallback
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ShopJoinFallbackPage(
                  dc: DriveClient(
                    GoogleSignIn(
                      scopes: const [
                        'email',
                        'profile',
                        'https://www.googleapis.com/auth/drive',
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
          child: const Text('Scan QR'),
        ),
      ],
    );
  }
}
