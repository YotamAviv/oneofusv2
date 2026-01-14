import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:app_links/app_links.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:oneofus_common/jsonish.dart';
import 'package:oneofus_common/io.dart';
import 'package:oneofus_common/cloud_functions_source.dart';
import 'package:oneofus_common/firestore_source.dart';
import 'package:oneofus_common/cached_statement_source.dart';
import 'package:oneofus_common/crypto.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:oneofus_common/crypto25519.dart';
import 'package:oneofus_common/oou_verifier.dart';
import 'package:oneofus_common/trust_statement.dart';
import 'core/config.dart';
import 'core/keys.dart';
import 'core/sign_in_service.dart';
import 'ui/identity_card_surface.dart';
import 'ui/qr_scanner.dart';
import 'features/key_management_screen.dart';
import 'features/people/people_screen.dart';
import 'features/people/services_screen.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  if (Config.fireChoice == FireChoice.emulator) {
    // Connect to local Firebase Emulators
    // 10.0.2.2 is the magic IP for the Android Emulator to reach the host machine
    FirebaseFirestore.instance.useFirestoreEmulator('10.0.2.2', 8081);
    // Note: Cloud Functions emulator is typically on 5002 for the one-of-us-net project in your setup
  }

  runApp(const OneOfUsApp());
}

// TODO: s/OneOfUsApp/App
class OneOfUsApp extends StatelessWidget {
  final bool isTesting;
  final FirebaseFirestore? firestore;
  const OneOfUsApp({super.key, this.isTesting = false, this.firestore});

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
      home: MainScreen(isTesting: isTesting, firestore: firestore),
    );
  }
}

// TODO: Move to its own file, probably in UI
class MainScreen extends StatefulWidget {
  final bool isTesting;
  final FirebaseFirestore? firestore;
  const MainScreen({super.key, this.isTesting = false, this.firestore});

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
  int _devClickCount = 0; // TODO: Why is this here?
  late final CachedStatementSource<TrustStatement> _source;

  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    TrustStatement.init();

    // TODO: This seems to belong somewhere higher up.
    // Initialize the statement source based on the environment
    StatementSource<TrustStatement> baseSource;
    if (widget.firestore != null) {
      baseSource = FirestoreSource<TrustStatement>(widget.firestore!);
    } else if (Config.fireChoice == FireChoice.fake) {
      baseSource = FirestoreSource<TrustStatement>(FakeFirebaseFirestore());
    } else if (Config.fireChoice == FireChoice.emulator) {
      baseSource = FirestoreSource<TrustStatement>(FirebaseFirestore.instance);
    } else {
      baseSource = CloudFunctionsSource<TrustStatement>(
        baseUrl: Config.exportUrl,
        verifier: OouVerifier(),
      );
    }
    _source = CachedStatementSource<TrustStatement>(baseSource);

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
    
    _initIdentityAndLoadData();
    
    if (!widget.isTesting) {
      _initDeepLinks();
    }
  }
  
  Future<void> _initIdentityAndLoadData() async {
    final found = await _keys.load();
    setState(() {
      _hasKey = found;
      _isLoading = false;
    });

    if (found) {
      await _loadAllData();
    }
  }

  // TODO: Do or don't scatter "refresh" all over the place.
  // TODO: This seems to belong somewhere higher up.
  Future<void> _loadAllData() async {
    final myToken = await _keys.getIdentityToken();
    if (myToken == null) return;
    
    setState(() => _isLoading = true);
    _source.clear();
    
    try {
      // 1. Fetch statements from Me
      final results1 = await _source.fetch({myToken: null});
      final myStatements = results1[myToken] ?? [];
      
      // 2. Extract everyone I trust (direct contacts)
      final Set<String> directContacts = myStatements
          .where((s) => s.verb == TrustVerb.trust)
          .map((s) => s.subjectToken)
          .toSet();
      
      // TODO: assert that I don't trust myself, instead
      // Remove self if present (already fetched)
      directContacts.remove(myToken);
      
      if (directContacts.isNotEmpty) {
        // 3. Fetch statements from direct contacts
        final Map<String, String?> keysToFetch = {
          for (var token in directContacts) token: null
        };
        await _source.fetch(keysToFetch);
      }
      
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Error loading data: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _initDeepLinks() {
    _linkSubscription = _appLinks.uriLinkStream.listen((uri) {
      _handleIncomingLink(uri);
    });

    _appLinks.getInitialLink().then((uri) {
      if (uri != null) {
        _handleIncomingLink(uri);
      }
    });
  }

  void _handleIncomingLink(Uri uri) {
    debugPrint("[DeepLink] Received: $uri");
    if (uri.scheme == 'keymeid') {
      // Legacy "Magic Sign-in" support
      final dataBase64 = uri.queryParameters['parameters'];
      if (dataBase64 != null) {
        try {
          final data = utf8.decode(base64Url.decode(dataBase64));
          SignInService.signIn(data, context);
        } catch (e) {
          debugPrint("[DeepLink] Error decoding legacy magic link: $e");
        }
      }
    } else if (uri.path.contains('sign-in')) {
      // New Seamless Sign-in support
      final data = uri.queryParameters['data'];
      if (data != null) {
        SignInService.signIn(data, context);
      }
    }
  }

  void _onScanPressed() async {
    final scanned = await QrScanner.scan(
      context,
      title: 'Scan Sign-in or Personal Key',
      validator: (data) async {
        if (await SignInService.validateSignIn(data)) return true;
        try {
          final json = jsonDecode(data);
          await const CryptoFactoryEd25519().parsePublicKey(json);
          return true; // It's a valid public key
        } catch (_) {
          return false;
        }
      },
    );

    if (scanned != null && mounted) {
      if (await SignInService.validateSignIn(scanned)) {
        await SignInService.signIn(scanned, context);
      } else {
        _handlePersonalKeyScan(scanned);
      }
    }
  }

  void _handlePersonalKeyScan(String scanned) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Personal key scanned. Vouching flow (v2) coming soon.')),
    );
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

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    if (!_hasKey) return _buildOnboarding(context);

    return FutureBuilder<String?>(
      future: _keys.getIdentityToken(),
      builder: (context, tokenSnapshot) {
        final myKeyToken = tokenSnapshot.data;
        final allStatements = _source.allCachedStatements;

        final pages = [
          _buildMePage(MediaQuery.of(context).orientation == Orientation.landscape, myKeyToken, allStatements),
          const KeyManagementScreen(),
          PeopleScreen(
            statements: allStatements,
            myKeyToken: myKeyToken,
            onRefresh: _loadAllData,
          ),
          ServicesScreen(
            statements: allStatements,
            onRefresh: _loadAllData,
          ),
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
                ],
              );
            },
          ),
        );
      }
    );
  }

  Widget _buildMePage(bool isLandscape, String? myKeyToken, List<TrustStatement> allStatements) {
    return FutureBuilder<Json?>(
      future: _keys.getIdentityPublicKeyJson(),
      builder: (context, snapshot) {
        final jsonKey = snapshot.data != null ? jsonEncode(snapshot.data) : 'no-key';
        
        String myMoniker = 'Me';
        if (myKeyToken != null) {
          // Find people I trust
          final trustedByMe = allStatements
              .where((s) => s.iToken == myKeyToken && s.verb == TrustVerb.trust)
              .map((s) => s.subjectToken)
              .toSet();

          // Find the most recent trust of ME from someone I trust
          for (final s in allStatements) {
            if (s.subjectToken == myKeyToken && trustedByMe.contains(s.iToken)) {
              // TODO: assert(s.moniker!.isNotEmpty);
              if (s.moniker != null && s.moniker!.isNotEmpty) {
                myMoniker = s.moniker!;
                break;
              }
            }
          }
        }

        return IdentityCardSurface(
          isLandscape: isLandscape,
          jsonKey: jsonKey,
          moniker: myMoniker,
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
            _HubTile(icon: Icons.account_circle_outlined, title: 'IDENTITY CARD', onTap: () => _pageController.jumpToPage(0)),
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
                _initIdentityAndLoadData();
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
