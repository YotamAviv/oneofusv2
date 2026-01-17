import 'dart:math';
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'card_config.dart';

class IdentityCardSurface extends StatefulWidget {
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
  State<IdentityCardSurface> createState() => IdentityCardSurfaceState();
}

class IdentityCardSurfaceState extends State<IdentityCardSurface> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<Offset> _offset; // px translation
  late final Animation<double> _rot; // radians

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 520));
    
    // Jerky "throw" animation sequence
    _offset = TweenSequence<Offset>([
      TweenSequenceItem(tween: Tween(begin: Offset.zero, end: const Offset(-8, 0)), weight: 12),
      TweenSequenceItem(
          tween: Tween(begin: const Offset(-8, 0), end: const Offset(26, -8)), weight: 22),
      TweenSequenceItem(
          tween: Tween(begin: const Offset(26, -8), end: const Offset(46, -14)), weight: 22),
      TweenSequenceItem(
          tween: Tween(begin: const Offset(46, -14), end: const Offset(0, 0)), weight: 44),
    ]).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));

    _rot = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: -3 * pi / 180), weight: 12),
      TweenSequenceItem(tween: Tween(begin: -3 * pi / 180, end: 5 * pi / 180), weight: 22),
      TweenSequenceItem(tween: Tween(begin: 5 * pi / 180, end: 8 * pi / 180), weight: 22),
      TweenSequenceItem(tween: Tween(begin: 8 * pi / 180, end: 0.0), weight: 44),
    ]).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  /// Triggers the jerky QR "throw" animation.
  Future<void> throwQr() async {
    if (!_ctrl.isAnimating) {
      await _ctrl.forward(from: 0);
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final screenW = constraints.maxWidth;
        final screenH = constraints.maxHeight;

        // Using orientation-specific coefficients from CardConfig
        final vertMargin = widget.isLandscape ? CardConfig.verticalMarginL : CardConfig.verticalMarginP;
        final horizMargin = widget.isLandscape ? CardConfig.horizontalMarginL : CardConfig.horizontalMarginP;
        final contentPadding = widget.isLandscape ? CardConfig.contentPaddingL : CardConfig.contentPaddingP;
        final qrRatio = widget.isLandscape ? CardConfig.qrHeightRatioL : CardConfig.qrHeightRatioP;

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
        
        // Define a generous area for the name
        final labelAreaHeight = cardH * 0.6; 

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
                        // QR Code on the left (with jerky animation)
                        Positioned(
                          left: padding,
                          top: padding,
                          child: AnimatedBuilder(
                            animation: _ctrl,
                            builder: (context, child) => Transform.translate(
                              offset: _offset.value,
                              child: Transform.rotate(
                                angle: _rot.value,
                                child: child,
                              ),
                            ),
                            child: QrImageView(
                              data: widget.jsonKey,
                              version: QrVersions.auto,
                              size: qrSize,
                              backgroundColor: Colors.transparent,
                              eyeStyle: const QrEyeStyle(eyeShape: QrEyeShape.square, color: Colors.black),
                              dataModuleStyle: const QrDataModuleStyle(dataModuleShape: QrDataModuleShape.square, color: Colors.black),
                            ),
                          ),
                        ),
                        
                        // Moniker label on the right
                        Positioned(
                          left: padding + qrSize + (cardW * 0.05),
                          right: padding,
                          top: padding,
                          height: labelAreaHeight,
                          child: Align(
                            alignment: Alignment.topRight,
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.topRight,
                              child: Text(
                                widget.moniker,
                                textAlign: TextAlign.right,
                                style: TextStyle(
                                  // Use a large ceiling so FittedBox handles the shrink
                                  fontSize: cardH * 0.22, 
                                  fontWeight: FontWeight.w900,
                                  color: Colors.black87,
                                  fontFamily: 'serif',
                                  height: 1.0,
                                ),
                              ),
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
