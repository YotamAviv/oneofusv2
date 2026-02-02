import 'dart:async';
import 'dart:convert';

import 'package:app_links/app_links.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:oneofus_common/cached_source.dart';
import 'package:oneofus_common/cloud_functions_source.dart';
import 'package:oneofus_common/direct_firestore_source.dart';
import 'package:oneofus_common/direct_firestore_writer.dart';
import 'package:oneofus_common/oou_signer.dart';
import 'package:oneofus_common/oou_verifier.dart';
import 'package:oneofus_common/statement.dart';
import 'package:oneofus_common/statement_source.dart';
import 'package:oneofus_common/trust_statement.dart';

import '../core/config.dart';
import '../core/keys.dart';
import '../core/labeler.dart';
import '../core/share_service.dart';
import '../core/sign_in_service.dart';
import '../demotest/tester.dart';
import '../features/about_screen.dart';
import '../features/advanced_screen.dart';
import '../features/blocks_screen.dart';
import '../features/card_screen.dart';
import '../features/congratulations_screen.dart';
import '../features/delegates_screen.dart';
import '../features/dev_screen.dart';
import '../features/history_screen.dart';
import '../features/import_export_screen.dart';
import '../features/intro_screen.dart';
import '../features/notifications_screen.dart';
import '../features/people_screen.dart';
import '../features/replace/replace_flow.dart';
import '../features/welcome_screen.dart';
import '../ui/interpreter.dart';
import '../util.dart';
import 'app_typography.dart';
import 'dialogs/clear_statement_dialog.dart';
import 'dialogs/edit_statement_dialog.dart';
import 'dialogs/lgtm_dialog.dart';
import 'error_dialog.dart';
import 'identity_card_surface.dart';
import 'qr_scanner.dart';

class AppShell extends StatefulWidget {
  final bool isTesting;
  final FirebaseFirestore? firestore;
  const AppShell({super.key, this.isTesting = false, this.firestore});

  static AppShellState get instance => AppShellState.instance;

  @override
  State<AppShell> createState() => AppShellState();
}

// Padding to ensure the top content clears the status bar/notch nicely.
const double _topSafeAreaPadding = 20;

class AppShellState extends State<AppShell> with SingleTickerProviderStateMixin {
  static AppShellState? _instance;
  static AppShellState get instance => _instance!;

  final PageController _pageController = PageController();
  final GlobalKey<IdentityCardSurfaceState> _cardKey = GlobalKey();
  final Keys _keys = Keys();
  final _appLinks = AppLinks();
  StreamSubscription<Uri>? _linkSubscription;
  
  int _currentPageIndex = 0;
  bool _isLoading = true;
  bool _showCongrats = false;
  bool _hasKey = false;
  List<String> _notifications = [];
  // Initialize Dev Mode based on environment; secret tap (AboutScreen) allows override.
  late bool _isDevMode = Config.fireChoice != FireChoice.prod;
  bool _showLgtm = false;
  int _devClickCount = 0;
  late final FirebaseFirestore _firestore;
  late final CachedSource<TrustStatement> _source;
  
  // Data State
  final ValueNotifier<List<TrustStatement>> myStatements = ValueNotifier([]);
  final ValueNotifier<Map<String, List<TrustStatement>>> peersStatements = ValueNotifier({});
  
  // Legacy getters (can refactor later or keep for internal use)
  List<TrustStatement> get _myStatements => myStatements.value;
  Map<String, List<TrustStatement>> get _peersStatements => peersStatements.value;

  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _instance = this;
    TrustStatement.init();

    // Initialize the statement source based on the environment
    _firestore = widget.firestore ?? 
                (Config.fireChoice == FireChoice.fake ? FakeFirebaseFirestore() : FirebaseFirestore.instance);
    
    StatementSource<TrustStatement> baseSource;
    if (Config.fireChoice != FireChoice.fake) {
      baseSource = CloudFunctionsSource<TrustStatement>(
        baseUrl: Config.exportUrl,
        verifier: OouVerifier(),
      );
    } else {
      baseSource = DirectFirestoreSource<TrustStatement>(_firestore);
    }
    _source = CachedSource<TrustStatement>(baseSource);

    if (_isDevMode) {
      Tester.init(DirectFirestoreWriter(_firestore));
    }

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
    );
    
    if (!widget.isTesting) {
      _pulseController.repeat(reverse: true);
    }
    _pulseAnimation = CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    );
    
    _keys.addListener(_initIdentityAndLoadData);
    _initIdentityAndLoadData();
    
    if (!widget.isTesting) {
      _initDeepLinks();
    }
  }

  @override
  void dispose() {
    _keys.removeListener(_initIdentityAndLoadData);
    _linkSubscription?.cancel();
    _pulseController.dispose();
    _pageController.dispose();
    super.dispose();
  }
  
  Future<void> _initIdentityAndLoadData() async {
    try {
      final found = await _keys.load();
      
      if (mounted) {
        setState(() {
          _hasKey = found;
          _isLoading = false;
        });
      }

      if (found) {
        await loadAllData();
      }
    } catch (e, stackTrace) {
      if (mounted) {
        setState(() => _isLoading = false);
        ErrorDialog.show(context, "Identity Error", e, stackTrace);
      }
    }
  }

  bool _isRefreshing = false;

  Future<void> loadAllData() async {
    final String? myToken = _keys.identityToken;
    if (myToken == null) return;
    
    assert(mounted);
    
    // Only show the full-screen loader if we have absolutely no data yet.
    // If we're already displaying things, just set _isRefreshing.
    final bool showFullLoader = _myStatements.isEmpty && !_isRefreshing;
    if (showFullLoader) {
      setState(() => _isLoading = true);
    } else {
      setState(() => _isRefreshing = true);
    }
    
    _source.clear();
      
    try {
      // Fetch statements authored by the current user
      final Map<String, List<TrustStatement>> myStatementsMap = await _source.fetch({myToken: null});
      // The source returns unmodifiable lists, so we must copy them before modification.
      final List<TrustStatement> newMyStatements = List.from(myStatementsMap[myToken] ?? []);
      
      newMyStatements.removeWhere((s) => s.verb == TrustVerb.clear);

      // Identify direct contacts (identities trusted by the user)
      final Set<String> directContacts = newMyStatements
          .where((s) => s.verb == TrustVerb.trust)
          .map((s) => s.subjectToken)
          .toSet();
      
      directContacts.remove(myToken);
      
      Map<String, List<TrustStatement>> newPeersStatements = {};
      if (directContacts.isNotEmpty) {
        // Fetch statements from all direct contacts
        final Map<String, String?> keysToFetch = {
          for (final String token in directContacts) token: null
        };
        // Fetch checks out immutable lists. We need to replace them with mutable ones.
        final rawPeersStatements = await _source.fetch(keysToFetch);
        newPeersStatements = rawPeersStatements.map((key, value) {
          final mutableList = List<TrustStatement>.from(value);
          mutableList.removeWhere((s) => s.verb == TrustVerb.clear);
          return MapEntry(key, mutableList);
        });
      }
      
      if (mounted) {
        // Calculate notifications
        final List<String> activeNotifications = [];
        
        // 1. No vouches
        final myVouches = newMyStatements.where((s) => s.verb == TrustVerb.trust).toList();
        if (myVouches.isEmpty) {
          activeNotifications.add('''You're the only one in your network.
You should vouch for a capable human.
(This is why your card calls you "Me".)''');
        }

        // 2. Unrequited vouches
        bool hasUnrequited = false;
        for (final vouch in myVouches) {
          final peerStmts = newPeersStatements[vouch.subjectToken] ?? [];
          final vouchedBack = peerStmts.any((s) => s.subjectToken == myToken && s.verb == TrustVerb.trust);
          if (!vouchedBack) {
            hasUnrequited = true;
            break;
          }
        }
        if (hasUnrequited) {
          activeNotifications.add('''Some folks you've vouched for haven't vouched for you.
You can see who those are by looking for the confirmation check mark to the right of their names on the PEOPLE screen.''');
        }

        setState(() {
          // Update internal and public state
          myStatements.value = newMyStatements;
          peersStatements.value = newPeersStatements;
          _notifications = activeNotifications;

          assert(() {
            Statement.validateOrderTypes(_myStatements);
            for (final list in _peersStatements.values) {
              Statement.validateOrderTypes(list);
            }
            return true;
          }());
          _isLoading = false;
          _isRefreshing = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isRefreshing = false;
        });
      }
    }
  }

  Future<void> editStatement(TrustStatement s, {TrustVerb? lockedVerb}) async {
    await _showEditStatementDialog(
      context: context,
      statement: s,
      existingStatement: s,
      publicKeyJson: s.subject,
      lockedVerb: lockedVerb,
    );
    loadAllData();
  }

  Future<void> clearStatement(TrustStatement s) async {
    await _showClearStatementDialog(
      context: context,
      statement: s,
      publicKeyJson: s.subject,
    );
    loadAllData();
  }

  Future<void> scan(TrustVerb targetVerb) async {
    await _onScanPressed(targetVerb: targetVerb);
    loadAllData();
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

  Future<void> _executeSignIn(String data) async {
    try {
      // 1. Ensure we are on the Card Screen (Page 0) so the user sees the animation
      if (mounted && _pageController.hasClients) {
        _pageController.jumpToPage(0);
      }
      // 2. Wait a brief moment for the UI to settle/render/focus
      await Future.delayed(const Duration(milliseconds: 500));

      final success = await SignInService.signIn(
        data,
        context,
        firestore: _firestore,
        myStatements: _myStatements,
        onSending: () => _cardKey.currentState?.throwQr(),
      );
      if (success && mounted) {
        loadAllData();
      }
    } catch (e) {
      // Logic might catch errors during sign-in
    }
  }

  void _handleIncomingLink(Uri uri) async {
    // Wait for the app to finish its initial loading sequence (keys + cloud data)
    // to ensure we have the identity token and latest trust statements.
    while (_isLoading && mounted) {
      await Future.delayed(const Duration(milliseconds: 200));
    }

    if (!mounted || !_hasKey) return;

    if (uri.scheme == 'keymeid') {
      final dataBase64 = uri.queryParameters['parameters'];
      if (dataBase64 != null) {
        try {
          final data = utf8.decode(base64Url.decode(dataBase64));
          await _executeSignIn(data);
        } catch (e) {}
      }
    } else if (uri.path.contains('sign-in')) {
      final dataParam = uri.queryParameters['data'];
      final paramsParam = uri.queryParameters['parameters'];

      if (paramsParam != null) {
        try {
          final data = utf8.decode(base64Url.decode(paramsParam));
          await _executeSignIn(data);
        } catch (e) {}
      } else if (dataParam != null) {
        await _executeSignIn(dataParam);
      }
    }
  }

  Future<void> _onScanPressed({TrustVerb targetVerb = TrustVerb.trust}) async {
    String title;
    String instruction;

    switch (targetVerb) {
      case TrustVerb.delegate:
        title = 'Scan Key QR';
        instruction = 'Scan a delegate key to state that it represents you.';
        break;
      case TrustVerb.block:
        title = 'Scan key QR';
        instruction = 'Scan the key to block.';
        break;
      case TrustVerb.trust:
      default:
        title = 'Scan Identity or Sign-in';
        instruction = 'Scan someone\'s identity key to vouch for them, or scan a services sign-in parameters to identify yourself and sign in.';
        break;
    }

    final scanned = await QrScanner.scan(
      context,
      title: title,
      instruction: instruction,
      validator: (data) async {
        try {
          final json = jsonDecode(data);
          if (json is! Map<String, dynamic>) return false;
          if (await SignInService.validateSignIn(data)) return true;
          return isPubKey(json);
        } catch (_) {
          return false;
        }
      },
    );

    if (scanned != null && mounted) {
      try {
        final Map<String, dynamic> json = jsonDecode(scanned);
        
        if (await SignInService.validateSignIn(scanned)) {
          await _executeSignIn(scanned);
        } else if (isPubKey(json)) {
          await _handlePublicKeyScan(json, targetVerb: targetVerb);
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Invalid scan data: $e')),
          );
        }
      }
    }
  }

  Future<void> _handlePublicKeyScan(Map<String, dynamic> publicKeyJson, {TrustVerb targetVerb = TrustVerb.trust}) async {
    try {
      final String subjectToken = getToken(publicKeyJson);
      
      if (!mounted) return;

      if (_keys.isIdentityToken(subjectToken)) {
        await showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text("That's you"),
            content: Text("Don't ${targetVerb.label} yourself."),
            actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('OKAY'))],
          ),
        );
        return;
      }

      // Check if I have already issued a statement for this subject
      final TrustStatement? existing = _myStatements
          .where((s) => s.subjectToken == subjectToken)
          .firstOrNull;

      final TrustStatement template;
      if (existing != null && existing.verb == targetVerb) {
        template = existing;
      } else {
        final myPubKeyJson = await _keys.getIdentityPublicKeyJson();
        final json = TrustStatement.make(
          myPubKeyJson!,
          publicKeyJson,
          targetVerb,
        );
        template = TrustStatement(Jsonish(json));
      }

      await _showEditStatementDialog(
        context: context,
        statement: template,
        existingStatement: existing,
        publicKeyJson: publicKeyJson,
        isNewScan: true,
        // If we are initiating a Block or Delegate scan, we lock the verb.
        // If Trust, EditStatementDialog logic permits switch to Block if no conflict.
        lockedVerb: targetVerb == TrustVerb.trust ? null : targetVerb,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error parsing scanned key: $e')),
        );
      }
    }
  }

  Future<void> _showEditStatementDialog({
    required BuildContext context,
    required TrustStatement statement,
    required Map<String, dynamic> publicKeyJson,
    TrustStatement? existingStatement,
    bool isNewScan = false,
    TrustVerb? lockedVerb,
  }) async {
    await showDialog(
      context: context,
      builder: (context) => EditStatementDialog(
        proposedStatement: statement,
        existingStatement: existingStatement,
        isNewScan: isNewScan,
        onSubmit: _pushTrustStatement,
      ),
    );
  }

  Future<void> _showClearStatementDialog({
    required BuildContext context,
    required TrustStatement statement,
    required Map<String, dynamic> publicKeyJson,
  }) async {
    final myPubKeyJson = await _keys.getIdentityPublicKeyJson();
    if (!mounted) return;
    
    await showDialog(
      context: context,
      builder: (context) => ClearStatementDialog(
        statement: statement,
        onSubmit: () async {
          final json = TrustStatement.make(
            myPubKeyJson!,
            publicKeyJson,
            TrustVerb.clear,
            domain: statement.domain,
          );
          
          await _pushTrustStatement(TrustStatement(Jsonish(json)));
        },
      ),
    );
  }

  Future<void> _pushTrustStatement(TrustStatement statement) async {
    bool confirmed = true;

    if (_showLgtm) {
      // Build interpreter for LGTM dialog
      final Map<String, List<TrustStatement>> combined = {
        _keys.identityToken!: _myStatements,
      };
      combined.addAll(_peersStatements);
      final labeler = Labeler(combined, _keys.identityToken!);
      final interpreter = OneOfUsInterpreter(labeler);
      // Show LGTM confirmation
      final result = await showDialog<bool>(
        context: context,
        builder: (context) {
          return LgtmDialog(statement: statement, interpreter: interpreter);
        },
      );
      confirmed = result == true;
    }

    if (!confirmed) {
      throw Exception('UserCancelled');
    }

    final publicKeyJson = statement[statement.verb.label];
    final token = getToken(publicKeyJson);
    final isMyDelegate = _keys.isDelegateToken(token);
    final isRevoking = (statement.verb == TrustVerb.delegate && statement.revokeAt != null);
    final isClearing = (statement.verb == TrustVerb.clear);
    
    if (isMyDelegate && (isRevoking || isClearing)) {
      final bool proceed = await _confirmDeleteDelegate(isRevoking);
      if (!proceed) return;
    }

    try {
      await _executePush(statement, isMyDelegate, isRevoking, isClearing, token);
      
      if (mounted) {
        _showSuccessSnackBar(statement);
        await loadAllData();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error pushing statement: $e')),
        );
      }
    }
  }

  Future<bool> _confirmDeleteDelegate(bool isRevoking) async {
    return await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove Local Key?'),
        content: Text(
          'You are ${isRevoking ? "revoking" : "clearing"} a delegate authorization '
          'for which you have the private key stored on this device.\n\n'
          'If you proceed, this key will be PERMANENTLY deleted from your local keyring after the network statement is published.'
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('CANCEL'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              isRevoking ? 'REVOKE & DELETE' : 'CLEAR & DELETE',
              style: AppTypography.label.copyWith(color: Colors.red),
            ),
          ),
        ],
      ),
    ) ?? false;
  }

  Future<void> _executePush(TrustStatement statement, bool isMyDelegate, bool isRevoking, bool isClearing, String token) async {
    final writer = DirectFirestoreWriter(_firestore);
    final identity = _keys.identity!; // Checked in caller
    final signer = await OouSigner.make(identity);
    
    final mutableJson = Map<String, dynamic>.from(statement.json);
    await writer.push(mutableJson, signer);

    if (isMyDelegate && (isRevoking || isClearing)) {
      await _keys.removeDelegateByToken(token);
    }
  }

  void _showSuccessSnackBar(TrustStatement statement) {
    // Determine label and color
    final (String label, Color color) = switch (statement.verb) {
      TrustVerb.trust    => ('Trusted', const Color(0xFF00897B)),
      TrustVerb.block    => ('Blocked', Colors.red),
      TrustVerb.clear    => ('Cleared', Colors.orange),
      TrustVerb.replace  => ('Updated ID History', Colors.green),
      TrustVerb.delegate => statement.revokeAt == null 
          ? ('Delegated', const Color(0xFF0288D1)) 
          : ('Revoked', Colors.blueGrey),
    };

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$label: Success'), backgroundColor: color),
    );
  }

  void _handleDevClick() {
    _devClickCount++;
    if (_devClickCount >= 3 && !_isDevMode) {
      if (Tester.writer == null) {
        Tester.init(DirectFirestoreWriter(_firestore));
      }
      setState(() {
        _isDevMode = true;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Developer Mode Enabled')),
      );
    }
  }

  List<Widget> get _pages {
    return [
      CardScreen(
        cardKey: _cardKey,
      ),
      const PeopleScreen(),
      const DelegatesScreen(),
      const ImportExportScreen(),
      AdvancedScreen(
        onShowBlocks: () => _showBlocksModal(context),
        onShowEquivalents: () => _showEquivalentsModal(context),
        onReplaceKey: () => _showReplaceKeyDialog(context),
      ),
      IntroScreen(
        onShowWelcome: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => CongratulationsScreen(
                onContinue: () => Navigator.pop(context),
              ),
            ),
          );
        },
      ),
      if (_notifications.isNotEmpty)
        NotificationsScreen(notifications: _notifications),
      AboutScreen(onDevClick: _handleDevClick),
      if (_isDevMode)
        DevScreen(
          onRefresh: loadAllData,
          showLgtm: _showLgtm,
          onLgtmChanged: (v) => setState(() => _showLgtm = v),
        ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    
    final myToken = _keys.identityToken;
    if (!_hasKey || myToken == null) {
      return WelcomeScreen(
        firestore: _firestore,
        onIdentityCreated: () => setState(() => _showCongrats = true),
      );
    }

    if (_showCongrats) {
      return CongratulationsScreen(
        onContinue: () => setState(() => _showCongrats = false),
      );
    }

    final pages = _pages;

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
                    padding: const EdgeInsets.fromLTRB(24, _topSafeAreaPadding, 24, 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
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
                                Text(
                                  'ONE-OF-US.NET',
                                  style: AppTypography.header.copyWith(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w800,
                                    fontFamily: 'serif',
                                  ),
                                ),
                              ],
                            )
                          : const SizedBox.shrink(),

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
                                  child: Icon(Icons.badge_outlined, color: Color(0xFF37474F), size: 24),
                                ),
                              ),
                              const SizedBox(width: 6),
                            ],
                            GestureDetector(
                              onTap: loadAllData,
                              child: const SizedBox(
                                width: 24,
                                height: 24,
                                child: Icon(Icons.refresh_rounded, color: Color(0xFF00897B), size: 24),
                              ),
                            ),
                            const SizedBox(width: 6),
                            GestureDetector(
                              onTap: () {
                                if (_notifications.isNotEmpty) {
                                  final index = pages.indexWhere((p) => p is NotificationsScreen);
                                  if (index != -1) {
                                    _pageController.animateToPage(index, duration: const Duration(milliseconds: 500), curve: Curves.easeInOut);
                                  }
                                }
                              },
                              child: SizedBox(
                                width: 20,
                                height: 20,
                                child: Center(
                                  child: (_isRefreshing || _notifications.isNotEmpty)
                                      ? AnimatedBuilder(
                                          animation: _pulseAnimation,
                                          builder: (context, child) {
                                            return Container(
                                              width: 10,
                                              height: 10,
                                              decoration: BoxDecoration(
                                                shape: BoxShape.circle,
                                                color: (_isRefreshing
                                                        ? const Color(0xFF00897B)
                                                        : Colors.redAccent)
                                                    .withOpacity(0.3 + (0.7 * _pulseAnimation.value)),
                                              ),
                                            );
                                          },
                                        )
                                      : const SizedBox.shrink(),
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
              const Text('SHARE', style: AppTypography.header),
              const SizedBox(height: 12),
              
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                child: Text('MY IDENTITY KEY', style: AppTypography.labelSmall),
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
              
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                child: Text('ONE-OF-US.NET LINK', style: AppTypography.labelSmall),
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

  void _showBlocksModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(32))),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 1.0,
        minChildSize: 0.9,
        maxChildSize: 1.0,
        expand: false,
        builder: (context, scrollController) => Column(
          children: [
            Align(
              alignment: Alignment.centerRight,
              child: IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(context),
              ),
            ),
            Expanded(
              child: BlocksScreen(scrollController: scrollController),
            ),
          ],
        ),
      ),
    );
  }

  void _showEquivalentsModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(32))),
      builder: (modalContext) => StatefulBuilder(
        builder: (context, setModalState) {
          return DraggableScrollableSheet(
            initialChildSize: 1.0,
            minChildSize: 0.9,
            maxChildSize: 1.0,
            expand: false,
            builder: (context, scrollController) => Column(
              children: [
                const SizedBox(height: 12),
                Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(2))),
                Expanded(
                  child: HistoryScreen(
                    scrollController: scrollController,
                    onClaimKey: () {
                      Navigator.pop(context); // Close modal
                      _showReplaceKeyDialog(context, claimMode: true);
                    },
                  ),
                ),
              ],
            ),
          );
        }
      ),
    );
  }

  void _showReplaceKeyDialog(BuildContext context, {bool claimMode = false}) {
    final identityToken = _keys.identityToken;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ReplaceFlow(
          firestore: _firestore,
          initialOldIdentityToken: claimMode ? null : identityToken,
          claimMode: claimMode,
        ),
      ),
    ).then((_) => loadAllData()); // Refresh after flow completes
  }

  void _showManagementHub(BuildContext context) {
    void jumpTo(bool Function(Widget) predicate) {
      final index = _pages.indexWhere(predicate);
      if (index != -1) {
        _pageController.jumpToPage(index);
      }
    }

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
            _HubTile(icon: Icons.credit_card_outlined, title: 'CARD', onTap: () => jumpTo((w) => w is CardScreen)),
            _HubTile(icon: Icons.people_outline, title: 'PEOPLE', onTap: () => jumpTo((w) => w is PeopleScreen)),
            _HubTile(icon: Icons.shield_moon_outlined, title: 'SERVICES', onTap: () => jumpTo((w) => w is DelegatesScreen)),
            _HubTile(icon: Icons.vpn_key_outlined, title: 'IMPORT / EXPORT', onTap: () => jumpTo((w) => w is ImportExportScreen)),
            _HubTile(icon: Icons.settings_accessibility_rounded, title: 'ADVANCED', onTap: () => jumpTo((w) => w is AdvancedScreen)),
            _HubTile(icon: Icons.menu_book_rounded, title: 'INTRO', onTap: () => jumpTo((w) => w is IntroScreen)),
            if (_notifications.isNotEmpty)
              _HubTile(icon: Icons.notifications_none, title: 'NOTIFICATIONS', onTap: () => jumpTo((w) => w is NotificationsScreen)),
            _HubTile(icon: Icons.help_outline_rounded, title: 'ABOUT', onTap: () => jumpTo((w) => w is AboutScreen)),
            if (_isDevMode) _HubTile(icon: Icons.bug_report_outlined, title: 'DEV', onTap: () => jumpTo((w) => w is DevScreen)),
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
      title: Text(title, style: AppTypography.header),
      onTap: () {
        Navigator.pop(context);
        onTap();
      },
    );
  }
}
