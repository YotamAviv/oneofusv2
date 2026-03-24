import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:oneofus_common/jsonish.dart';
import 'package:oneofus_common/keys.dart' show FedKey;
import 'package:oneofus_common/trust_statement.dart';
import '../core/keys.dart';
import '../ui/identity_card_surface.dart';
import '../ui/app_shell.dart';

class CardScreen extends StatelessWidget {
  final GlobalKey<IdentityCardSurfaceState>? cardKey;
  final bool showFederatedQr;

  const CardScreen({
    super.key,
    this.cardKey,
    this.showFederatedQr = false,
  });

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<List<TrustStatement>>(
      valueListenable: AppShell.instance.myStatements,
      builder: (context, myStatements, _) {
       return ValueListenableBuilder<Map<String, List<TrustStatement>>>(
          valueListenable: AppShell.instance.peersStatements,
          builder: (context, peersStatements, _) {
            final keys = Keys();
            final bool isLandscape = MediaQuery.of(context).orientation == Orientation.landscape;

            return FutureBuilder<Json?>(
              future: keys.getIdentityPublicKeyJson(),
              builder: (context, snapshot) {
                final json = snapshot.data;
                final jsonKey = json == null
                    ? 'no-key'
                    : showFederatedQr
                        ? jsonEncode(FedKey(json).toPayload())
                        : jsonEncode(json);
                
                String myMoniker = 'Me';
                
                // Find people I trust
                final trustedByMe = myStatements
                    .where((s) => s.verb == TrustVerb.trust)
                    .map((s) => s.subjectToken)
                    .toSet();

                // Search for trusts of ME from someone I trust
                final myKeyToken = keys.identityToken!;
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
                          isVouched: true,
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
        );
      }
    );
  }
}
