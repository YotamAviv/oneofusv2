import 'dart:math';
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'card_config.dart';

class IdentityCardSurface extends StatelessWidget {
  final bool isLandscape;
  final String jsonKey;
  final String moniker;

  const IdentityCardSurface({
    super.key,
    required this.isLandscape,
    required this.jsonKey,
    this.moniker = 'Me',
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final screenW = constraints.maxWidth;
        final screenH = constraints.maxHeight;

        // Using orientation-specific coefficients from CardConfig
        final vertMargin = isLandscape ? CardConfig.verticalMarginL : CardConfig.verticalMarginP;
        final horizMargin = isLandscape ? CardConfig.horizontalMarginL : CardConfig.horizontalMarginP;
        final contentPadding = isLandscape ? CardConfig.contentPaddingL : CardConfig.contentPaddingP;
        final qrRatio = isLandscape ? CardConfig.qrHeightRatioL : CardConfig.qrHeightRatioP;

        final availW = screenW * (1 - 2 * horizMargin);
        final availH = screenH * (1 - 2 * vertMargin);

        // Scale logic to ensure entire card is visible
        final scale = min(availW / CardConfig.cardW, availH / CardConfig.cardH);

        final imgW = CardConfig.imgW * scale;
        final imgH = CardConfig.imgH * scale;
        final cardW = CardConfig.cardW * scale;
        final cardH = CardConfig.cardH * scale;

        final padding = cardW * contentPadding;
        final maxQrSize = cardH - (2 * padding);
        final qrSize = min(maxQrSize, cardH * qrRatio);
        
        double fontSize = cardH;
        if (moniker.length <= 6) {
          fontSize = cardH * 0.20;
        } else if (moniker.length <= 10) {
          fontSize = cardH * 0.14;
        } else {
          fontSize = cardH * 0.10;
        }

        return Center(
          child: SizedBox(
            width: screenW,
            height: screenH,
            child: OverflowBox(
              minWidth: imgW,
              maxWidth: imgW,
              minHeight: imgH,
              maxHeight: imgH,
              child: Stack(
                children: [
                  // 1. The background image
                  Image.asset(
                    'assets/card_background.png',
                    width: imgW,
                    height: imgH,
                    fit: BoxFit.fill,
                    errorBuilder: (context, _, __) => Container(color: Colors.grey.shade300),
                  ),
                  
                  // 2. The Card Area
                  Positioned(
                    left: CardConfig.cardL * scale,
                    top: CardConfig.cardT * scale,
                    width: cardW,
                    height: cardH,
                    child: Stack(
                      children: [
                        // QR Code on the left
                        Positioned(
                          left: padding,
                          top: padding,
                          child: QrImageView(
                            data: jsonKey,
                            version: QrVersions.auto,
                            size: qrSize,
                            backgroundColor: Colors.transparent,
                            eyeStyle: const QrEyeStyle(eyeShape: QrEyeShape.square, color: Colors.black),
                            dataModuleStyle: const QrDataModuleStyle(dataModuleShape: QrDataModuleShape.square, color: Colors.black),
                          ),
                        ),
                        
                        // Moniker label on the right
                        Positioned(
                          left: padding + qrSize + (cardW * 0.05),
                          right: padding,
                          top: padding,
                          child: Text(
                            moniker,
                            textAlign: TextAlign.right,
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: fontSize,
                              fontWeight: FontWeight.w900,
                              color: Colors.black87,
                              fontFamily: 'serif',
                              height: 1.1,
                            ),
                          ),
                        ),
                        
                        // Hand-tuned quote text
                        Positioned(
                          right: padding,
                          bottom: padding,
                          width: cardW * 0.4,
                          child: Text(
                            'Human, capable, acting in good faith',
                            textAlign: TextAlign.right,
                            style: TextStyle(
                              fontSize: cardH * 0.06,
                              fontWeight: FontWeight.w800,
                              fontStyle: FontStyle.italic,
                              color: Colors.black38,
                              fontFamily: 'serif',
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
