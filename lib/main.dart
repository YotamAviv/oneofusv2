import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:app_links/app_links.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:oneofus_common/direct_firestore_writer.dart';
import 'package:oneofus_common/io.dart';
import 'package:oneofus_common/jsonish.dart';
import 'package:oneofus_common/cloud_functions_source.dart';
import 'package:oneofus_common/crypto.dart';
import 'package:oneofus_common/oou_verifier.dart';
import 'package:oneofus_common/trust_statement.dart';
import 'core/keys.dart';
import 'ui/identity_card_surface.dart';
import 'features/key_management_screen.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
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
  final Keys _keys = Keys();
  final _appLinks = AppLinks();
  StreamSubscription<Uri>? _linkSubscription;
  
  int _currentPageIndex = 0;
  bool _isLoading = true;
  bool _hasKey = false;
  bool _hasAlerts = true;
  bool _isDevMode = false;
  int _devClickCount = 0;
  String _testFetchResult = 'PENDING';

  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();

    TrustStatement.init();
    _testFetchStatements();

    _pageController.addListener(() {
      if (_pageController.page?.round() != _currentPageIndex) {
        setState(() {
          _currentPageIndex = _pageController.page!.round();
        });
      }
    });

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    _pulseAnimation = CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    );

    _initIdentity();
    _initDeepLinks();
  }

  Future<void> _testFetchStatements() async {
    final lisaKeyJson = {
      "crv": "Ed25519",
      "kty": "OKP",
      "x": "D6oXiGksgfL4AP6lf2vXnAoq54_t1p8k-3SXs1Bgm8g"
    };
    final lisaToken = getToken(lisaKeyJson);
    print('lisaToken=$lisaToken');
    
    try {
      final StatementSource<TrustStatement> source = CloudFunctionsSource<TrustStatement>(
        // Doesn't work: Fantasy: baseUrl: 'https://us-central1-one-of-us-net.cloudfunctions.net/v2',
        // Doesn't work: permissions, I suspect: 'http://localhost:5002/one-of-us-net/us-central1/export',
        // baseUrl: 'http://10.0.2.2:5002/one-of-us-net/us-central1/export', // Works: emulator on local machine.
        baseUrl: 'http://export.one-of-us.net', // Works: production
        verifier: OouVerifier(),
      );

      // NEXT: Verify that we can write
      // final StatementWriter writer = DirectFirestoreWriter();

      final Map<String, List<TrustStatement>> results = await source.fetch({lisaToken: null});
      print('results=$results');

      for (final MapEntry<String, List<TrustStatement>> entry in results.entries) {
        for (final TrustStatement statement in entry.value) {
          // print('statement=${statement.jsonish.ppJson}');
          print('${statement.verb.label} ${statement.moniker} ${statement.domain} ${statement.comment}');
        }
      }

      if (mounted) {
        if (results.containsKey(lisaToken)) {
          final statements = results[lisaToken]!;
          if (statements.isNotEmpty) {
            final allStatementsJson = statements.map((s) => jsonEncode(s.json)).join('\\n');
            setState(() => _testFetchResult = allStatementsJson);
          } else {
            setState(() => _testFetchResult = 'SUCCESS: Fetched 0 statements for Lisa.');
          }
        } else {
           setState(() => _testFetchResult = 'FAILURE: No statements found for Lisa.');
        }
      }
    } catch (e, stackTrace) {
      print(e);
      print(stackTrace);
      if (mounted) setState(() => _testFetchResult = 'FAILURE: ${e.toString()}');
    }
  }

  Future<void> _initIdentity() async {
    final found = await _keys.load();
    setState(() {
      _hasKey = found;
      _isLoading = false;
    });
  }

  void _initDeepLinks() {
    debugPrint('[DeepLink] Initializing deep link listeners (keymeid://)...');
    
    _linkSubscription = _appLinks.uriLinkStream.listen((uri) {
      debugPrint('[DeepLink] Received stream link: $uri');
      _handleIncomingLink(uri);
    });

    _appLinks.getInitialLink().then((uri) {
      if (uri != null) {
        debugPrint('[DeepLink] Received initial launch link: $uri');
        _handleIncomingLink(uri);
      }
    });
  }

  void _handleIncomingLink(Uri uri) {
    debugPrint('[DeepLink] Processing: scheme=${uri.scheme}, host=${uri.host}');
    
    if (uri.scheme == 'keymeid' && (uri.host == 'signin' || uri.path.contains('signin'))) {
      final params = uri.queryParameters['parameters'];
      if (params != null) {
        debugPrint('[DeepLink] Sign-in parameters found: $params');
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Received keymeid Sign-in: $params'),
            duration: const Duration(seconds: 10),
          ),
        );
      } else {
        debugPrint('[DeepLink] Error: keymeid link received but "parameters" field is missing.');
      }
    } else {
      debugPrint('[DeepLink] Link ignored: Does not match keymeid://signin path.');
    }
  }

  void _handleDevClick() {
    _devClickCount++;
    if (_devClickCount >= 7 && !_isDevMode) {
      setState(() {
        _isDevMode = true;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Developer Mode Enabled')),
      );
    }
  }

  @override
  void dispose() {
    _linkSubscription?.cancel();
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
    if (_isLoading) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    if (!_hasKey) return _buildOnboarding(context);

    final pages = [
      _buildMePage(MediaQuery.of(context).orientation == Orientation.landscape),
      const KeyManagementScreen(),
      const _SubPage(title: 'PEOPLE', icon: Icons.people_outline),
      const _SubPage(title: 'SERVICES', icon: Icons.shield_moon_outlined),
      _buildInfoPage(),
      if (_isDevMode) _buildDevPage(),
    ];

    return Scaffold(
      backgroundColor: const Color(0xFFF2F0EF),
      body: OrientationBuilder(
        builder: (context, orientation) {
          bool isLandscape = orientation == Orientation.landscape;

          return Stack(
            children: [
              PageView(
                controller: _pageController,
                children: pages,
              ),

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
              
              if (!isLandscape && _currentPageIndex == 0) ...[
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
              
              // Instrumentation for test driver
              Align(
                alignment: Alignment.bottomLeft,
                child: Text(_testFetchResult, key: const ValueKey('test_fetch_result'), style: const TextStyle(fontSize: 0)),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildMePage(bool isLandscape) {
    return FutureBuilder<Json?>(
      future: _keys.getIdentityPublicKeyJson(),
      builder: (context, snapshot) {
        final jsonKey = snapshot.data != null ? jsonEncode(snapshot.data) : 'no-key';
        return IdentityCardSurface(
          isLandscape: isLandscape,
          jsonKey: jsonKey,
        );
      }
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
            _HubTile(icon: Icons.vpn_key_outlined, title: 'KEY MANAGEMENT', onTap: () => _pageController.jumpToPage(1)),
            _HubTile(icon: Icons.people_outline, title: 'PEOPLE', onTap: () => _pageController.jumpToPage(2)),
            _HubTile(icon: Icons.shield_moon_outlined, title: 'SERVICES', onTap: () => _pageController.jumpToPage(3)),
            _HubTile(icon: Icons.info_outline_rounded, title: 'HELP & INFO', onTap: () => _pageController.jumpToPage(4)),
            if (_isDevMode) _HubTile(icon: Icons.bug_report_outlined, title: 'DEV DIAGNOSTICS', onTap: () => _pageController.jumpToPage(5)),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoPage() {
    return ListView(
      padding: const EdgeInsets.all(40),
      children: [
        const Center(
          child: Column(
            children: [
              Icon(Icons.shield_rounded, size: 80, color: Color(0xFF00897B)),
              SizedBox(height: 24),
              Text('ONE-OF-US.NET', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, letterSpacing: 4)),
            ],
          ),
        ),
        const SizedBox(height: 40),
        GestureDetector(
          onTap: _handleDevClick,
          child: const Center(
            child: Text('V2.0.0 • BUILD 80', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
          ),
        ),
        const SizedBox(height: 60),
        const ListTile(title: Text('Help Page'), subtitle: Text('https://one-of-us.net/man.html')),
        const ListTile(title: Text('Privacy Policy'), subtitle: Text('https://one-of-us.net/policy.html')),
      ],
    );
  }

  Widget _buildDevPage() {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const Text('DIAGNOSTICS (DEV)', style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 2)),
        const Divider(),
        const Text('PRIVATE KEYS', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.red)),
        const SizedBox(height: 12),
        FutureBuilder<Map<String, Json>>(
          future: _keys.getAllKeyJsons(),
          builder: (context, snapshot) {
            return SelectableText(
              const JsonEncoder.withIndent('  ').convert(snapshot.data ?? {}), 
              style: const TextStyle(fontFamily: 'monospace', fontSize: 10)
            );
          },
        ),
      ],
    );
  }

  Widget _buildOnboarding(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(48),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.shield_rounded, size: 100, color: Color(0xFF00897B)),
              const SizedBox(height: 32),
              const Text('ONE-OF-US.NET', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, letterSpacing: 4, color: Color(0xFF006064))),
              const SizedBox(height: 64),
              ElevatedButton(onPressed: () async {
                await _keys.newIdentity();
                _initIdentity();
              }, child: const Text('GENERATE NEW IDENTITY')),
            ],
          ),
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
