import 'dart:async';
import 'dart:convert';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:app_links/app_links.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:oneofus_common/jsonish.dart';
import 'package:oneofus_common/io.dart';
import 'package:oneofus_common/cloud_functions_source.dart';
import 'package:oneofus_common/firestore_source.dart';
import 'package:oneofus_common/cached_statement_source.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:oneofus_common/crypto25519.dart';
import 'package:oneofus_common/oou_verifier.dart';
import 'package:oneofus_common/oou_signer.dart';
import 'package:oneofus_common/trust_statement.dart';
import 'package:oneofus_common/direct_firestore_writer.dart';
import '../core/config.dart';
import '../core/keys.dart';
import '../core/sign_in_service.dart';
import 'identity_card_surface.dart';
import 'qr_scanner.dart';
import '../core/share_service.dart';
import '../features/key_management_screen.dart';
import '../features/people/people_screen.dart';
import '../features/people/services_screen.dart';

class MainScreen extends StatefulWidget {
  final bool isTesting;
  final FirebaseFirestore? firestore;
  const MainScreen({super.key, this.isTesting = false, this.firestore});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

// It's been a struggle to get the top junk aligned...
const double heightKludge = 20;

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
  late final CachedStatementSource<TrustStatement> _source;

  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    TrustStatement.init();

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
    
    if (mounted) {
      setState(() {
        _hasKey = found;
        _isLoading = false;
      });
    }

    if (found) {
      await _loadAllData();
    }
  }

  Future<void> _loadAllData() async {
    final myToken = _keys.identityToken;
    if (myToken == null) return;
    
    // Only show full-screen loader if we have no data yet
    bool showFullLoader = _source.allCachedStatements.isEmpty;
    if (showFullLoader) {
      setState(() => _isLoading = true);
    }
    
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

  void _handlePersonalKeyScan(String scanned) async {
    try {
      final jsonData = json.decode(scanned);
      final String? moniker = jsonData['moniker'];
      final String? domain = jsonData['domain'];
      final Map<String, dynamic> publicKeyJson = (jsonData['publicKey'] as Map<String, dynamic>?) ?? jsonData;
      
      final String subjectToken = getToken(publicKeyJson);
      
      if (!mounted) return;
      
      final bool? trust = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(moniker != null ? 'Trust $moniker?' : 'Trust Person?'),
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (moniker != null) ...[
                Text('NAME', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey.shade600, letterSpacing: 1.2)),
                Text(moniker, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
              ],
              if (domain != null) ...[
                Text('DOMAIN', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey.shade600, letterSpacing: 1.2)),
                Text(domain, style: const TextStyle(fontSize: 14)),
                const SizedBox(height: 12),
              ],
              Text('IDENTITY TOKEN', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey.shade600, letterSpacing: 1.2)),
              Text('${subjectToken.substring(0, 12)}...', style: TextStyle(fontSize: 12, fontFeatures: const [FontFeature.tabularFigures()], color: Colors.grey.shade800)),
              const SizedBox(height: 16),
              Text(
                'By trusting this person, you exchange contact information and can verify their identity in the future.',
                style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text('CANCEL', style: TextStyle(color: Colors.grey.shade600, letterSpacing: 1.2, fontWeight: FontWeight.bold)),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00897B),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: const Text('TRUST', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.2)),
            ),
          ],
        ),
      );
      
      if (trust == true) {
        final identity = _keys.identity!;
        final myPubKeyJson = await (await identity.publicKey).json;
        
        final statementJson = TrustStatement.make(
          myPubKeyJson,
          publicKeyJson,
          TrustVerb.trust,
          moniker: moniker,
          domain: domain,
        );
        
        final writer = DirectFirestoreWriter(widget.firestore ?? FirebaseFirestore.instance);
        final signer = await OouSigner.make(identity);
        await writer.push(statementJson, signer);
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Succesfully matched with ${moniker ?? 'this person'}'),
              backgroundColor: const Color(0xFF00897B),
            ),
          );
          _loadAllData(); // Refresh to see them in PEOPLE list
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error parsing scanned key: $e')),
        );
      }
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

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    if (!_hasKey || _keys.identityToken == null) return _buildOnboarding(context);

    final allStatements = _source.allCachedStatements;

    final pages = [
      _buildMePage(MediaQuery.of(context).orientation == Orientation.landscape, _keys.identityToken!, allStatements),
      const KeyManagementScreen(),
      PeopleScreen(
        statements: allStatements,
        myKeyToken: _keys.identityToken!,
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
                physics: const BouncingScrollPhysics(),
                children: pages,
              ),

              // Global Header Row
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: SafeArea(
                  bottom: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(24, heightKludge, 24, 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        // Logo and Title (Only on Home Page)
                        _currentPageIndex == 0 
                          ? Row(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.center,
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
                                    fontSize: 14,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 3.0,
                                    color: Color(0xFF37474F),
                                    fontFamily: 'serif',
                                  ),
                                ),
                              ],
                            )
                          : const SizedBox.shrink(),

                        // Action Buttons & Pulse (Perfectly packed and even)
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            if (_currentPageIndex != 0) ...[
                              GestureDetector(
                                onTap: () => _pageController.animateToPage(0, duration: const Duration(milliseconds: 500), curve: Curves.easeInOut),
                                child: const SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: Icon(Icons.home_rounded, color: Color(0xFF37474F), size: 24),
                                ),
                              ),
                              const SizedBox(width: 6),
                            ],
                            GestureDetector(
                              onTap: _loadAllData,
                              child: const SizedBox(
                                width: 24,
                                height: 24,
                                child: Icon(Icons.refresh_rounded, color: Color(0xFF00897B), size: 24),
                              ),
                            ),
                            const SizedBox(width: 6),
                            SizedBox(
                              width: 20,
                              height: 20,
                              child: Center(
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
                                            : Colors.grey.withOpacity(0.2),
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              
              if (!isLandscape && _currentPageIndex == 0) ...[
                Positioned(
                  bottom: 30,
                  left: 30,
                  right: 30,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(
                        onPressed: () => _showShareMenu(context),
                        icon: const Icon(Icons.share, size: 32, color: Color(0xFF37474F)),
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

  Widget _buildMePage(bool isLandscape, String myKeyToken, List<TrustStatement> allStatements) {
    return FutureBuilder<Json?>(
      future: _keys.getIdentityPublicKeyJson(),
      builder: (context, snapshot) {
        final jsonKey = snapshot.data != null ? jsonEncode(snapshot.data) : 'no-key';
        
        String myMoniker = 'Me';
        
        // Find people I trust
        final trustedByMe = allStatements
            .where((s) => s.iToken == myKeyToken && s.verb == TrustVerb.trust)
            .map((s) => s.subjectToken)
            .toSet();

        // Find the most recent trust of ME from someone I trust
        for (final s in allStatements) {
          if (s.subjectToken == myKeyToken && trustedByMe.contains(s.iToken)) {
            if (s.moniker != null && s.moniker!.isNotEmpty) {
              myMoniker = s.moniker!;
              break;
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
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('SHARE', style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 2)),
              const SizedBox(height: 12),
              
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                child: Text('MY IDENTITY KEY', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 1.5)),
              ),
              ListTile(
                leading: const Icon(Icons.qr_code_2_rounded),
                title: const Text('Share as QR Image'),
                onTap: () {
                  Navigator.pop(context);
                  ShareService.shareIdentityQr();
                },
              ),
              ListTile(
                leading: const Icon(Icons.code_rounded),
                title: const Text('Share as JSON Text'),
                onTap: () {
                  Navigator.pop(context);
                  ShareService.shareIdentityText();
                },
              ),
              
              const Divider(indent: 24, endIndent: 24),
              
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                child: Text('ONE-OF-US.NET LINK', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 1.5)),
              ),
              ListTile(
                leading: const Icon(Icons.qr_code_rounded),
                title: const Text('Show QR Code'),
                onTap: () {
                  Navigator.pop(context);
                  ShareService.showQrDialog(context, ShareService.homeUrl, 'ONE-OF-US.NET');
                },
              ),
              ListTile(
                leading: const Icon(Icons.link_rounded),
                title: const Text('Share Text Link'),
                onTap: () {
                  Navigator.pop(context);
                  ShareService.shareHomeLink();
                },
              ),
            ],
          ),
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
            _HubTile(icon: Icons.help_outline_rounded, title: 'HELP & INFO', onTap: () => _pageController.jumpToPage(4)),
            if (_isDevMode) _HubTile(icon: Icons.bug_report_outlined, title: 'DEV DIAGNOSTICS', onTap: () => _pageController.jumpToPage(5)),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoPage() {
    return SafeArea(
      child: Column(
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(24, 24, 24, 8),
            child: Row(
              children: [
                Text(
                  'ONE-OF-US.NET',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 4,
                    color: Color(0xFF37474F),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
              children: [
                const _InfoCategory(title: 'RESOURCES'),
                _InfoLinkTile(
                  icon: Icons.home_outlined, 
                  title: 'Home', 
                  subtitle: 'https://one-of-us.net', 
                  url: 'https://one-of-us.net'
                ),
                _InfoLinkTile(
                  icon: Icons.menu_book_outlined, 
                  title: 'Manual', 
                  subtitle: 'Guides and documentation', 
                  url: 'https://one-of-us.net/man.html'
                ),
                
                const SizedBox(height: 24),
                const _InfoCategory(title: 'LEGAL & PRIVACY'),
                _InfoLinkTile(
                  icon: Icons.privacy_tip_outlined, 
                  title: 'Privacy Policy', 
                  url: 'https://one-of-us.net/policy.html'
                ),
                _InfoLinkTile(
                  icon: Icons.gavel_outlined, 
                  title: 'Terms & Conditions', 
                  url: 'https://one-of-us.net/terms.html'
                ),

                const SizedBox(height: 24),
                const _InfoCategory(title: 'SUPPORT'),
                _InfoLinkTile(
                  icon: Icons.email_outlined, 
                  title: 'Contact Support', 
                  subtitle: 'contact@one-of-us.net', 
                  url: 'mailto:contact@one-of-us.net'
                ),
                _InfoLinkTile(
                  icon: Icons.report_problem_outlined, 
                  title: 'Report Abuse', 
                  subtitle: 'abuse@one-of-us.net', 
                  url: 'mailto:abuse@one-of-us.net'
                ),
                
                const SizedBox(height: 60),
                GestureDetector(
                  onTap: _handleDevClick,
                  child: const Center(
                    child: Column(
                      children: [
                        Text(
                          'With ♡ from Clacker;)',
                          style: TextStyle(color: Colors.grey, fontSize: 10, letterSpacing: 0.5),
                        ),
                        SizedBox(height: 8),
                        Text('V2.0.0 • BUILD 80', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
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
      backgroundColor: const Color(0xFFF2F0EF),
      body: Stack(
        children: [
          // Header (matching card page)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, heightKludge, 24, 8),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.center,
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
          ),
          
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 48),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 40),
                  ElevatedButton(
                    onPressed: () async {
                      await _keys.newIdentity();
                      _initIdentityAndLoadData();
                    },
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 20),
                      backgroundColor: const Color(0xFF37474F),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 4,
                    ),
                    child: const Text('CREATE NEW IDENTITY KEY', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.2)),
                  ),
                  const SizedBox(height: 20),
                  OutlinedButton(
                    onPressed: () => _showImportDialog(context),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 20),
                      side: const BorderSide(color: Color(0xFF37474F), width: 1.5),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('IMPORT IDENTITY KEY', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF37474F), letterSpacing: 1.2)),
                  ),
                  const SizedBox(height: 20),
                  OutlinedButton(
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Claim/Replace identity coming soon.')),
                      );
                    },
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 20),
                      side: const BorderSide(color: Color(0xFF37474F), width: 1.5),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('CLAIM (REPLACE) IDENTITY KEY', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF37474F), letterSpacing: 1.2)),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showImportDialog(BuildContext context) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('IMPORT IDENTITY'),
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('PASTE KEYS JSON', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 1.2)),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              maxLines: 6,
              decoration: InputDecoration(
                hintText: '{"identity": ...}',
                hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 13),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                filled: true,
                fillColor: Colors.grey.shade50,
              ),
              style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('CANCEL', style: TextStyle(color: Colors.grey.shade600, fontWeight: FontWeight.bold)),
          ),
          ElevatedButton(
            onPressed: () async {
              try {
                await _keys.importKeys(controller.text);
                if (mounted) {
                  Navigator.pop(context);
                  _initIdentityAndLoadData();
                }
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Import failed: $e')));
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF00897B),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('IMPORT'),
          ),
        ],
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

class _InfoCategory extends StatelessWidget {
  final String title;
  const _InfoCategory({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: Colors.blueGrey.shade300,
          letterSpacing: 2.0,
        ),
      ),
    );
  }
}

class _InfoLinkTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final String url;

  const _InfoLinkTile({
    required this.icon,
    required this.title,
    this.subtitle,
    required this.url,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: const Color(0xFF00897B)),
      title: Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF37474F))),
      subtitle: subtitle != null ? Text(subtitle!, style: TextStyle(fontSize: 12, color: Colors.blueGrey.shade600)) : null,
      trailing: const Icon(Icons.open_in_new_rounded, size: 16, color: Colors.grey),
      onTap: () => launchUrl(Uri.parse(url)),
    );
  }
}
