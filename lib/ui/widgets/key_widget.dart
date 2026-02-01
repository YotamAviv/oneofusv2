import 'package:flutter/material.dart';
import 'package:oneofus_common/trust_statement.dart';
import 'package:oneofus_common/jsonish.dart';
import '../../core/keys.dart';

class KeyWidget extends StatelessWidget {
  final TrustStatement statement;
  final Color color;
  final double size;

  const KeyWidget({
    super.key,
    required this.statement,
    required this.color,
    this.size = 20.0,
  });

  @override
  Widget build(BuildContext context) {
    // Listen to Keys changes to ensure UI updates if/when keys are loaded/deleted.
    return ListenableBuilder(
      listenable: Keys(),
      builder: (context, _) {
        final keys = Keys();
        final subjectToken = statement.subjectToken;
        final verb = statement.verb;
        final isRevoked = statement.revokeAt != null;

        // 1. Determine Key Possession (Solid vs Outline)
        final bool hasPrivateKey = keys.isDelegateToken(subjectToken) || 
                                   keys.isIdentityToken(subjectToken);

        // 2. Determine Voided Status and Tooltip
        bool isVoided = false;
        String statusTooltip;

        switch (verb) {
          case TrustVerb.delegate:
            isVoided = isRevoked;
            statusTooltip = isRevoked 
                ? 'Revoked: This delegate key is no longer authorized'
                : 'Delegate: A key authorized to act on your behalf';
            break;
          
          case TrustVerb.trust:
            isVoided = false;
            statusTooltip = 'Trusted: A human identity capable of acting in good faith';
            break;
            
          case TrustVerb.block:
            isVoided = true;
            statusTooltip = 'Blocked: An identity you have explicitly denied trust';
            break;
            
          case TrustVerb.replace:
            isVoided = true;
            statusTooltip = 'Replaced: One of your previous identity keys';
            break;
            
          default:
            statusTooltip = 'Unknown relationship';
        }

        // 3. Determine Icon
        IconData keyIcon;
        if (isVoided) {
          keyIcon = hasPrivateKey ? Icons.key_off : Icons.key_off_outlined;
        } else {
          // Using vpn_key because Icons.key_outlined appears solid in some renderers
          keyIcon = hasPrivateKey ? Icons.vpn_key : Icons.vpn_key_outlined;
        }

        return Tooltip(
          message: statusTooltip,
          child: Icon(
            keyIcon,
            size: size,
            color: color,
          ),
        );
      },
    );
  }
}
