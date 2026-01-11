import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

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
  final bool _hasKey = true;
  final bool _hasAlerts = true;

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
    super.dispose();
  }

  void _onScanPressed() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Initializing Encounter...')),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_hasKey) return const Scaffold(body: Center(child: Text('Onboarding...')));

    return Scaffold(
      backgroundColor: const Color(0xFFF2F0EF), 
      body: Stack(
        children: [
          // 1. Branding (Top Left)
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Image.asset(
                    'assets/oneofus_1024.png',
                    height: 32,
                    errorBuilder: (context, _, __) => const Icon(Icons.shield_rounded, size: 32, color: Color(0xFF00897B)),
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    'ONE-OF-US.NET',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 2.0,
                      color: Color(0xFF37474F),
                      fontFamily: 'serif',
                    ),
                  ),
                ],
              ),
            ),
          ),

          // 2. Pulsing Alert Dot (Top Right)
          Positioned(
            top: 60,
            right: 24,
            child: AnimatedBuilder(
              animation: _pulseAnimation,
              builder: (context, child) {
                return Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _hasAlerts
                        ? Colors.redAccent.withOpacity(0.3 + (0.7 * _pulseAnimation.value))
                        : Colors.transparent,
                  ),
                );
              },
            ),
          ),

          // 3. Background Image & QR Code
          Center(
            child: LayoutBuilder(
              builder: (context, constraints) {
                // Background image touching edges
                return Stack(
                  alignment: Alignment.center,
                  children: [
                    Image.asset(
                      'assets/card_background.png',
                      width: double.infinity,
                      fit: BoxFit.fitWidth,
                      errorBuilder: (context, _, __) => Container(height: 300, color: Colors.grey.shade200),
                    ),
                    // QR Code (Transparent over the image)
                    // Move it 20% left, 2% up, and make it 20% smaller (from 200 to 160)
                    Transform.translate(
                      offset: Offset(
                        -constraints.maxWidth * 0.22, // 20% to the left
                        -constraints.maxHeight * 0.01, // 2% up
                      ),
                      child: QrImageView(
                        data: 'one-of-us:4a5b29c8d7e6f5a4b3c2d1e0f9a8b7c6d5e4f3a2',
                        version: QrVersions.auto,
                        size: 200, // 20% smaller than previous 200
                        backgroundColor: Colors.transparent,
                        eyeStyle: const QrEyeStyle(eyeShape: QrEyeShape.square, color: Colors.black),
                        dataModuleStyle: const QrDataModuleStyle(dataModuleShape: QrDataModuleShape.square, color: Colors.black),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),

          // 4. One Button for all functionality (Bottom Right)
          Align(
            alignment: Alignment.bottomRight,
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: IconButton(
                onPressed: () => _showManagementHub(context),
                icon: const Icon(Icons.menu_rounded, size: 36, color: Color(0xFF37474F)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showManagementHub(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(32))),
      builder: (context) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 32),
            _HubTile(icon: Icons.qr_code_scanner_rounded, title: 'ENCOUNTER (SCAN)'),
            _HubTile(icon: Icons.account_tree_rounded, title: 'TRUSTED LEDGER'),
            _HubTile(icon: Icons.ios_share_rounded, title: 'SHARE IDENTITY'),
            _HubTile(icon: Icons.tune_rounded, title: 'ADVANCED'),
            _HubTile(icon: Icons.info_outline_rounded, title: 'HELP & ABOUT'),
          ],
        ),
      ),
    );
  }
}

class _HubTile extends StatelessWidget {
  final IconData icon;
  final String title;
  const _HubTile({required this.icon, required this.title});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: const Color(0xFF00897B), size: 28),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13, letterSpacing: 2)),
      onTap: () {},
    );
  }
}
