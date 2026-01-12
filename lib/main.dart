import 'dart:math';
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'card_config.dart';

void main() {
  runApp(const OneOfUsApp());
}

class OneOfUsApp extends StatelessWidget {
  const OneOfUsApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ONE-OF-US.NET',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF00897B),
          primary: const Color(0xFF00897B),
        ),
        useMaterial3: true,
      ),
      home: const MainScreen(),
    );
  }
}

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> with SingleTickerProviderStateMixin {
  final PageController _pageController = PageController();
  bool _hasKey = true;
  bool _hasAlerts = true;

  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    _pulseAnimation = CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  void _onScanPressed() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Encounter Scanner...'),
        action: SnackBarAction(label: 'REMOTE', onPressed: () {}),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_hasKey) return const Scaffold(body: Center(child: Text('Onboarding...')));

    return Scaffold(
      backgroundColor: const Color(0xFFF2F0EF),
      body: OrientationBuilder(
        builder: (context, orientation) {
          bool isLandscape = orientation == Orientation.landscape;

          return Stack(
            children: [
              PageView(
                controller: _pageController,
                children: [
                  _buildMePage(isLandscape),
                  const _SubPage(title: 'PEOPLE', icon: Icons.people_outline),
                  const _SubPage(title: 'SERVICES', icon: Icons.shield_moon_outlined),
                  const _SubPage(title: 'INFO & ADVANCED', icon: Icons.tune_rounded),
                ],
              ),

              // Persistent Pulse Dot (Top Right)
              Positioned(
                top: isLandscape ? 20 : 60,
                right: isLandscape ? 20 : 32,
                child: AnimatedBuilder(
                  animation: _pulseAnimation,
                  builder: (context, child) {
                    return Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _hasAlerts
                            ? Colors.redAccent.withOpacity(0.3 + (0.7 * _pulseAnimation.value))
                            : Colors.grey.withOpacity(0.2),
                        boxShadow: _hasAlerts
                            ? [
                                BoxShadow(
                                  color: Colors.redAccent.withOpacity(0.4 * _pulseAnimation.value),
                                  blurRadius: 12,
                                  spreadRadius: 4,
                                )
                              ]
                            : null,
                      ),
                    );
                  },
                ),
              ),

              if (!isLandscape) ...[
                SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(32, 24, 32, 0),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Image.asset(
                          'assets/oneofus_1024.png',
                          height: 36,
                          errorBuilder: (context, _, __) => const Icon(Icons.shield_rounded, size: 36, color: Color(0xFF00897B)),
                        ),
                        const SizedBox(width: 12),
                        const Text(
                          'ONE-OF-US.NET',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 3.0,
                            color: Color(0xFF37474F),
                            fontFamily: 'serif',
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                Positioned(
                  bottom: 30,
                  left: 30,
                  right: 30,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(
                        onPressed: () => _showShareMenu(context),
                        icon: const Icon(Icons.ios_share_rounded, size: 32, color: Color(0xFF37474F)),
                      ),
                      IconButton(
                        onPressed: () => _showManagementHub(context),
                        icon: const Icon(Icons.menu_rounded, size: 36, color: Color(0xFF37474F)),
                      ),
                    ],
                  ),
                ),

                Align(
                  alignment: Alignment.bottomCenter,
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 50),
                    child: SizedBox(
                      height: 72,
                      width: 72,
                      child: FloatingActionButton(
                        onPressed: _onScanPressed,
                        backgroundColor: const Color(0xFF37474F),
                        foregroundColor: Colors.white,
                        shape: const CircleBorder(),
                        elevation: 6,
                        child: const Icon(Icons.qr_code_scanner_rounded, size: 32),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }

  Widget _buildMePage(bool isLandscape) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final screenW = constraints.maxWidth;
        final screenH = constraints.maxHeight;

        final availW = screenW * (1 - 2 * CardConfig.horizontalMargin);
        final availH = screenH * (1 - 2 * CardConfig.verticalMargin);

        final scaleW = availW / CardConfig.cardW;
        final scaleH = availH / CardConfig.cardH;

        final scale = min(scaleW, scaleH);

        final imgW = CardConfig.imgW * scale;
        final imgH = CardConfig.imgH * scale;
        final cardW = CardConfig.cardW * scale;
        final cardH = CardConfig.cardH * scale;

        final padding = cardW * CardConfig.contentPadding;
        final maxQrSize = cardH - (2 * padding);
        final qrSize = min(maxQrSize, cardH * CardConfig.qrHeightRatio);

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
                  Image.asset(
                    'assets/card_background.png',
                    width: imgW,
                    height: imgH,
                    fit: BoxFit.fill,
                    errorBuilder: (context, _, __) => Container(color: Colors.grey.shade300),
                  ),
                  
                  // The Card Area with Temporary Blue Debug Box
                  Positioned(
                    left: CardConfig.cardL * scale,
                    top: CardConfig.cardT * scale,
                    width: cardW,
                    height: cardH,
                    child: Container(
                      // DO NOT DELETE: This debug border is useful when swapping background images.
                      // decoration: BoxDecoration(
                      //   border: Border.all(color: Colors.blue, width: 2), // Debug border
                      // ),
                      child: Stack(
                        children: [
                          Positioned(
                            left: padding,
                            top: padding,
                            child: QrImageView(
                              data: 'one-of-us:identity_token_placeholder',
                              version: QrVersions.auto,
                              size: qrSize,
                              backgroundColor: Colors.transparent,
                              eyeStyle: const QrEyeStyle(eyeShape: QrEyeShape.square, color: Colors.black),
                              dataModuleStyle: const QrDataModuleStyle(dataModuleShape: QrDataModuleShape.square, color: Colors.black),
                            ),
                          ),
                          
                          Positioned(
                            right: padding,
                            top: padding,
                            child: Text(
                              'Me',
                              style: TextStyle(
                                fontSize: cardH * 0.12,
                                fontWeight: FontWeight.w900,
                                color: Colors.black87,
                                fontFamily: 'serif',
                              ),
                            ),
                          ),
                        ],
                      ),
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

  void _showShareMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(32))),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 20),
            const Text('SHARE', style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 2)),
            ListTile(leading: const Icon(Icons.qr_code_2), title: const Text('Show My Key QR'), onTap: () => Navigator.pop(context)),
            ListTile(leading: const Icon(Icons.email_outlined), title: const Text('Email My Key (Text)'), onTap: () => Navigator.pop(context)),
            ListTile(leading: const Icon(Icons.link), title: const Text('Share Homepage'), onTap: () => Navigator.pop(context)),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  void _showManagementHub(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(40))),
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 32),
            _HubTile(icon: Icons.people_outline, title: 'PEOPLE', onTap: () => _pageController.jumpToPage(1)),
            _HubTile(icon: Icons.shield_moon_outlined, title: 'SERVICES', onTap: () => _pageController.jumpToPage(2)),
            _HubTile(icon: Icons.info_outline_rounded, title: 'HELP & INFO', onTap: () => _pageController.jumpToPage(3)),
            _HubTile(icon: Icons.tune_rounded, title: 'ADVANCED', onTap: () => _pageController.jumpToPage(3)),
          ],
        ),
      ),
    );
  }
}

class _HubTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback onTap;
  const _HubTile({required this.icon, required this.title, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: const Color(0xFF00897B), size: 28),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13, letterSpacing: 2)),
      onTap: () {
        Navigator.pop(context);
        onTap();
      },
    );
  }
}

class _SubPage extends StatelessWidget {
  final String title;
  final IconData icon;
  const _SubPage({required this.title, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 64, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          Text(title, style: TextStyle(color: Colors.grey.shade500, fontWeight: FontWeight.w900, letterSpacing: 2)),
        ],
      ),
    );
  }
}
