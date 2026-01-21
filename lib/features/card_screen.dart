import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:oneofus_common/jsonish.dart';
import 'package:oneofus_common/trust_statement.dart';
import '../core/keys.dart';
import '../ui/identity_card_surface.dart';

class CardScreen extends StatelessWidget {
  final List<TrustStatement> myStatements;
  final Map<String, List<TrustStatement>> peersStatements;
  final String myKeyToken;
  final GlobalKey<IdentityCardSurfaceState>? cardKey;

  const CardScreen({
    super.key,
    required this.myStatements,
    required this.peersStatements,
    required this.myKeyToken,
    this.cardKey,
  });

  @override
  Widget build(BuildContext context) {
    final keys = Keys();
    final bool isLandscape = MediaQuery.of(context).orientation == Orientation.landscape;

    return FutureBuilder<Json?>(
      future: keys.getIdentityPublicKeyJson(),
      builder: (context, snapshot) {
        final jsonKey = snapshot.data != null ? jsonEncode(snapshot.data) : 'no-key';
        
        String myMoniker = 'Me';
        
        // Find people I trust
        final trustedByMe = myStatements
            .where((s) => s.verb == TrustVerb.trust)
            .map((s) => s.subjectToken)
            .toSet();

        // Search for trusts of ME from someone I trust
        for (final entry in peersStatements.entries) {
          if (!trustedByMe.contains(entry.key)) continue;
          
          for (final s in entry.value) {
            if (s.subjectToken == myKeyToken && s.verb == TrustVerb.trust) {
              if (s.moniker != null && s.moniker!.isNotEmpty) {
                myMoniker = s.moniker!;
                return IdentityCardSurface(
                  key: cardKey,
                  isLandscape: isLandscape,
                  jsonKey: jsonKey,
                  moniker: myMoniker,
                );
              }
            }
          }
        }

        return IdentityCardSurface(
          key: cardKey,
          isLandscape: isLandscape,
          jsonKey: jsonKey,
          moniker: myMoniker,
        );
      }
    );
  }
}
