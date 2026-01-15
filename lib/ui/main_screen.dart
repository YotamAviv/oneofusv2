import 'dart:async';
import 'dart:convert';

import 'package:app_links/app_links.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:oneofus_common/cached_statement_source.dart';
import 'package:oneofus_common/cloud_functions_source.dart';
import 'package:oneofus_common/crypto25519.dart';
import 'package:oneofus_common/direct_firestore_writer.dart';
import 'package:oneofus_common/firestore_source.dart';
import 'package:oneofus_common/io.dart';
import 'package:oneofus_common/jsonish.dart';
import 'package:oneofus_common/oou_signer.dart';
import 'package:oneofus_common/oou_verifier.dart';
import 'package:oneofus_common/statement.dart';
import 'package:oneofus_common/trust_statement.dart';
import 'package:oneofus_common/util.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/config.dart';
import '../core/keys.dart';
import '../core/share_service.dart';
import '../core/sign_in_service.dart';
import '../demotest/tester.dart';
import '../features/key_management_screen.dart';
import '../features/people/people_screen.dart';
import '../features/people/services_screen.dart';
import 'error_dialog.dart';
import 'identity_card_surface.dart';
import 'qr_scanner.dart';

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
  // TODO: Set to false before deploying to App Stores
  bool _isDevMode = true;
  int _devClickCount = 0;
  late final FirebaseFirestore _firestore;
  late final CachedStatementSource<TrustStatement> _source;
  Map<String, List<TrustStatement>> _statementsByIssuer = {};

  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
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
      baseSource = FirestoreSource<TrustStatement>(_firestore);
    }
    _source = CachedStatementSource<TrustStatement>(baseSource);

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
    
    // TODO: I don't think this is necessary. Considerremoving.
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
        await _loadAllData();
      }
    } catch (e, stackTrace) {
      if (mounted) {
        setState(() => _isLoading = false);
        ErrorDialog.show(context, "Identity Error", e, stackTrace);
      }
    }
  }

  bool _isRefreshing = false;

  Future<void> _loadAllData() async {
    final String myToken = _keys.identityToken!;
    
    assert(mounted);
    
    // Only show full-screen loader if we have no data yet
    final bool showFullLoader = _statementsByIssuer.isEmpty;
    if (showFullLoader) {
      setState(() => _isLoading = true);
    } else {
      setState(() => _isRefreshing = true);
    }
    
    _source.clear();
    
    try {
      // 1. Fetch statements from Me
      final Map<String, List<TrustStatement>> results1 = await _source.fetch({myToken: null});
      final List<TrustStatement> myStatements = results1[myToken] ?? [];
      
      // Strip 'clear' statements immediately. A 'clear' means "say nothing about this subject".
      myStatements.removeWhere((s) => s.verb == TrustVerb.clear);

      // 2. Extract everyone I trust (direct contacts)
      final Set<String> directContacts = myStatements
          .where((s) => s.verb == TrustVerb.trust)
          .map((s) => s.subjectToken)
          .toSet();
      
      // Remove self if present (already fetched)
      directContacts.remove(myToken);
      
      Map<String, List<TrustStatement>> results2 = {};
      if (directContacts.isNotEmpty) {
        // 3. Fetch statements from direct contacts
        final Map<String, String?> keysToFetch = {
          for (final String token in directContacts) token: null
        };
        results2 = await _source.fetch(keysToFetch);
        // Strip 'clear' statements from contacts too
        for (final list in results2.values) {
          list.removeWhere((s) => s.verb == TrustVerb.clear);
        }
      }
      
      if (mounted) {
        setState(() {
          _statementsByIssuer = {
            ...results1,
            ...results2,
          };
          assert(() {
            Statement.validateOrderTypess(_statementsByIssuer.values);
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
    if (uri.scheme == 'keymeid') {
      // Legacy "Magic Sign-in" support
      final dataBase64 = uri.queryParameters['parameters'];
      if (dataBase64 != null) {
        try {
          final data = utf8.decode(base64Url.decode(dataBase64));
          SignInService.signIn(data, context, firestore: _firestore);
        } catch (e) {
        }
      }
    } else if (uri.path.contains('sign-in')) {
      // New Seamless Sign-in support
      final data = uri.queryParameters['data'];
      if (data != null) {
        SignInService.signIn(data, context, firestore: _firestore);
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
        await SignInService.signIn(scanned, context, firestore: _firestore);
      } else {
        _handlePersonalKeyScan(scanned);
      }
    }
  }

  void _handlePersonalKeyScan(String scanned) async {
    try {
      final jsonData = json.decode(scanned);
      final String? initialMoniker = jsonData['moniker'];
      final Map<String, dynamic> publicKeyJson = (jsonData['publicKey'] as Map<String, dynamic>?) ?? jsonData;
      final String subjectToken = getToken(publicKeyJson);
      
      if (!mounted) return;

      // 1. Check if it's one of my OWN keys (Identity or Delegate)
      if (_keys.isIdentityToken(subjectToken)) {
        await showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text("That's you"),
            content: const Text("Don't trust yourself."),
            actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('OKAY'))],
          ),
        );
        return;
      }

      if (_keys.isDelegateToken(subjectToken)) {
        await showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text("That's you"),
            content: const Text("That's one of your delegate keys. Don't trust your own delegate key."),
            actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('OKAY'))],
          ),
        );
        return;
      }

      // 2. Check for equivalent identity keys (former keys replaced by current) 
      // or stated delegate keys in the social graph.
      final statementMap = _statementsByIssuer;
      final String myToken = _keys.identityToken!;
      final Set<String> myIdentityKeys = {myToken};
      bool changed = true;
      while (changed) {
        changed = false;
        // Search through ALL issuers in the map for identity replacements
        for (final list in statementMap.values) {
          for (final s in list) {
            if (myIdentityKeys.contains(s.iToken) && s.verb == TrustVerb.replace) {
              if (myIdentityKeys.add(s.subjectToken)) changed = true;
            }
          }
        }
      }

      if (myIdentityKeys.contains(subjectToken)) {
        // It's a former identity key not currently in the keychain
        await showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text("This is you"),
            content: const Text("This is one of your equivalent (former) identity keys.\n\nYou should manage your identity history in settings."),
            actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('OKAY'))],
          ),
        );
        return;
      }

      // Check for stated delegate keys of mine in the graph
      final Set<String> myStatedDelegates = {};
      for (final list in statementMap.values) {
        for (final s in list) {
          if (myIdentityKeys.contains(s.iToken) && s.verb == TrustVerb.delegate) {
            myStatedDelegates.add(s.subjectToken);
          }
        }
      }

      if (myStatedDelegates.contains(subjectToken)) {
        await showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text("That's you"),
            content: const Text("This is one of your delegate keys.\n\nManage your delegates in the services section."),
            actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('OKAY'))],
          ),
        );
        return;
      }

      // 3. Check if it's someone ELSE's delegate key
      bool isDelegateOfOther = false;
      for (final list in statementMap.values) {
        if (list.any((s) => s.subjectToken == subjectToken && s.verb == TrustVerb.delegate)) {
          isDelegateOfOther = true;
          break;
        }
      }

      if (isDelegateOfOther) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Cannot vouch for or block delegate keys directly. Vouch for the primary identity instead.')),
        );
        return;
      }

      // 4. Normal path: check for existing statement and show dialog
      final List<TrustStatement> existingStatement = [];
      for (final list in statementMap.values) {
        existingStatement.addAll(list.where((s) => myIdentityKeys.contains(s.iToken) && s.subjectToken == subjectToken));
      }
      existingStatement.sort((a, b) => b.time.compareTo(a.time));
      
      final TrustStatement? latest = existingStatement.firstOrNull;
      
      await _showTrustBlockDialog(
        context: context,
        subjectToken: subjectToken,
        publicKeyJson: publicKeyJson,
        initialMoniker: latest?.moniker ?? initialMoniker,
        initialComment: latest?.comment,
        initialVerb: latest?.verb,
        allowClear: latest != null, // Only allow clear if it's not a new key
        existingTime: latest?.time,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error parsing scanned key: $e')),
        );
      }
    }
  }

  Future<void> _showTrustBlockDialog({
    required BuildContext context,
    required String subjectToken,
    required Map<String, dynamic> publicKeyJson,
    String? initialMoniker,
    String? initialComment,
    TrustVerb? initialVerb,
    TrustVerb? lockedVerb,
    bool allowClear = false,
    DateTime? existingTime,
  }) async {
    final monikerController = TextEditingController(text: initialMoniker);
    final commentController = TextEditingController(text: initialComment);
    TrustVerb selectedVerb = lockedVerb ?? initialVerb ?? TrustVerb.trust;
    
    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          final isTrust = selectedVerb == TrustVerb.trust;
          final isBlock = selectedVerb == TrustVerb.block;
          final isClear = selectedVerb == TrustVerb.clear;
          
          String title = isTrust 
              ? (initialVerb == null ? 'Trust' : 'Update Trust') 
              : (isBlock ? 'Block' : 'Clear');
          if (lockedVerb == null) {
            title = initialVerb == null ? 'Identity Vouching' : 'Update Disposition';
          }

          return AlertDialog(
            title: Text(title),
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Trust: "human, capable of acting in good faith"', 
                    style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic)),
                  const Text('Block: "Bots, spammers, bad actors, careless, confused.."', 
                    style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic)),
                  const SizedBox(height: 16),
                  
                  if (lockedVerb == null) ...[
                    // Toggle between Trust, Block, and potentially Clear
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: ChoiceChip(
                            label: const Center(child: Text('TRUST')),
                            selected: isTrust,
                            onSelected: (val) => setDialogState(() {
                              if (val) selectedVerb = TrustVerb.trust;
                            }),
                            selectedColor: const Color(0xFF00897B).withOpacity(0.2),
                            labelStyle: TextStyle(
                              color: isTrust ? const Color(0xFF00897B) : Colors.grey,
                              fontWeight: FontWeight.bold,
                              fontSize: 11,
                            ),
                          ),
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: ChoiceChip(
                            label: const Center(child: Text('BLOCK')),
                            selected: isBlock,
                            onSelected: (val) => setDialogState(() {
                              if (val) selectedVerb = TrustVerb.block;
                            }),
                            selectedColor: Colors.red.withOpacity(0.2),
                            labelStyle: TextStyle(
                              color: isBlock ? Colors.red : Colors.grey,
                              fontWeight: FontWeight.bold,
                              fontSize: 11,
                            ),
                          ),
                        ),
                        if (allowClear) ...[
                          const SizedBox(width: 4),
                          Expanded(
                            child: ChoiceChip(
                              label: const Center(child: Text('CLEAR')),
                              selected: isClear,
                              onSelected: (val) => setDialogState(() {
                                if (val) selectedVerb = TrustVerb.clear;
                              }),
                              selectedColor: Colors.orange.withOpacity(0.2),
                              labelStyle: TextStyle(
                                color: isClear ? Colors.orange : Colors.grey,
                                fontWeight: FontWeight.bold,
                                fontSize: 11,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 16),
                  ],
                  
                  // MONIKER FIELD (Show if TRUST, or if we have a former value to cross out)
                  if (isTrust || initialMoniker != null) ...[
                    Text('NAME ${isTrust ? "(REQUIRED)" : ""}', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey.shade600, letterSpacing: 1.2)),
                    const SizedBox(height: 4),
                    TextField(
                      controller: monikerController,
                      enabled: isTrust,
                      style: isTrust ? null : const TextStyle(decoration: TextDecoration.lineThrough, color: Colors.grey),
                      decoration: InputDecoration(
                        hintText: '',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                      onChanged: (_) => setDialogState(() {}),
                    ),
                    const SizedBox(height: 12),
                  ],
                  
                  // COMMENT FIELD (Show if TRUST or BLOCK, or if we have a former value to cross out)
                  if (isTrust || isBlock || initialComment != null) ...[
                    Text('COMMENT ${(isTrust || isBlock) ? "(OPTIONAL)" : ""}', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey.shade600, letterSpacing: 1.2)),
                    const SizedBox(height: 4),
                    TextField(
                      controller: commentController,
                      enabled: isTrust || isBlock,
                      style: (isTrust || isBlock) ? null : const TextStyle(decoration: TextDecoration.lineThrough, color: Colors.grey),
                      maxLines: 2,
                      decoration: InputDecoration(
                        hintText: '',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                      onChanged: (_) => setDialogState(() {}),
                    ),
                    const SizedBox(height: 12),
                  ],

                  if (isClear) ...[
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8.0),
                      child: Text(
                        'This will issue a CLEAR statement, effectively removing this person from your collections.',
                        style: TextStyle(fontSize: 12, color: Colors.orange, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                  
                  if (existingTime != null) ...[
                    const SizedBox(height: 12),
                    Text('LATEST STATEMENT', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey.shade600, letterSpacing: 1.2)),
                    Text(formatUiDatetime(existingTime), style: const TextStyle(fontSize: 12)),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('CANCEL', style: TextStyle(color: Colors.grey.shade600, letterSpacing: 1.2, fontWeight: FontWeight.bold)),
              ),
              ElevatedButton(
                onPressed: () {
                  final curVerb = selectedVerb;
                  final curMoniker = monikerController.text.trim();
                  final curComment = commentController.text.trim();
                  
                  final hasChanged = initialVerb == null ||
                                    curVerb != initialVerb ||
                                    (curVerb == TrustVerb.trust && curMoniker != (initialMoniker ?? '')) ||
                                    (curVerb != TrustVerb.clear && curComment != (initialComment ?? ''));
                  
                  final isMonikerValid = curVerb != TrustVerb.trust || curMoniker.isNotEmpty;
                  final canSubmit = hasChanged && isMonikerValid;

                  if (!canSubmit) return null;

                  return () async {
                    Navigator.pop(context);
                    await _pushTrustStatement(
                      publicKeyJson: publicKeyJson,
                      verb: curVerb,
                      moniker: curVerb == TrustVerb.trust ? curMoniker : null,
                      comment: curVerb != TrustVerb.clear ? curComment : null,
                    );
                  };
                }(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: isBlock ? Colors.red : (isClear ? Colors.orange : const Color(0xFF00897B)),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: Text(isBlock ? 'BLOCK' : (isClear ? 'CLEAR' : 'TRUST'), style: const TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.2)),
              ),
            ],
          );
        }
      ),
    );
  }

  Future<void> _pushTrustStatement({
    required Map<String, dynamic> publicKeyJson,
    required TrustVerb verb,
    String? moniker,
    String? comment,
    String? domain,
  }) async {
    final identity = _keys.identity;
    if (identity == null) {
      throw StateError("Cannot push statement without an identity key.");
    }

    try {
      final myPubKeyJson = await (await identity.publicKey).json;
      
      final statementJson = TrustStatement.make(
        myPubKeyJson,
        publicKeyJson,
        verb,
        moniker: moniker,
        comment: comment,
        domain: domain,
      );
      
      final writer = DirectFirestoreWriter(_firestore);
      final signer = await OouSigner.make(identity);
      
      await writer.push(statementJson, signer);
      
      if (mounted) {
        String action = 'Updated';
        Color bgColor = const Color(0xFF00897B);
        
        if (verb == TrustVerb.trust) {
          action = 'Trusted';
        } else if (verb == TrustVerb.block) {
          action = 'Blocked';
          bgColor = Colors.red;
        } else if (verb == TrustVerb.clear) {
          action = 'Cleared';
          bgColor = Colors.orange;
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$action: Success'),
            backgroundColor: bgColor
          ),
        );
        _loadAllData();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error pushing statement: $e')),
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
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    
    final myToken = _keys.identityToken;
    if (!_hasKey || myToken == null) return _buildOnboarding(context);

    final Map<String, List<TrustStatement>> statementMap = _statementsByIssuer;

    final pages = [
      _buildMePage(MediaQuery.of(context).orientation == Orientation.landscape, myToken, statementMap),
      const KeyManagementScreen(),
      PeopleScreen(
        statementsByIssuer: statementMap,
        myKeyToken: _keys.identityToken!,
        onRefresh: _loadAllData,
        onEdit: (statement) {
          _showTrustBlockDialog(
            context: context,
            subjectToken: statement.subjectToken,
            publicKeyJson: statement.subject,
            initialMoniker: statement.moniker,
            initialComment: statement.comment,
            initialVerb: statement.verb,
            lockedVerb: TrustVerb.trust,
            existingTime: statement.time,
          );
        },
        onBlock: (statement) {
          _showTrustBlockDialog(
            context: context,
            subjectToken: statement.subjectToken,
            publicKeyJson: statement.subject,
            initialMoniker: statement.moniker,
            initialComment: statement.comment,
            initialVerb: statement.verb,
            lockedVerb: TrustVerb.block,
            existingTime: statement.time,
          );
        },
        onClear: (statement) {
          _showTrustBlockDialog(
            context: context,
            subjectToken: statement.subjectToken,
            publicKeyJson: statement.subject,
            initialMoniker: statement.moniker,
            initialComment: statement.comment,
            initialVerb: statement.verb,
            lockedVerb: TrustVerb.clear,
            existingTime: statement.time,
          );
        },
      ),
      ServicesScreen(
        statementsByIssuer: statementMap,
        myKeyToken: myToken,
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
                                        color: (_hasAlerts || _isRefreshing)
                                            ? (_isRefreshing ? const Color(0xFF00897B) : Colors.redAccent).withOpacity(0.3 + (0.7 * _pulseAnimation.value))
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

  Widget _buildMePage(bool isLandscape, String myKeyToken, Map<String, List<TrustStatement>> statementMap) {
    return FutureBuilder<Json?>(
      future: _keys.getIdentityPublicKeyJson(),
      builder: (context, snapshot) {
        final jsonKey = snapshot.data != null ? jsonEncode(snapshot.data) : 'no-key';
        
        String myMoniker = 'Me';
        
        // Find people I trust
        final trustedByMe = (statementMap[myKeyToken] ?? [])
            .where((s) => s.verb == TrustVerb.trust)
            .map((s) => s.subjectToken)
            .toSet();

        // Search for trusts of ME from someone I trust
        for (final entry in statementMap.entries) {
          if (!trustedByMe.contains(entry.key)) continue;
          
          for (final s in entry.value) {
            if (s.subjectToken == myKeyToken && s.verb == TrustVerb.trust) {
              if (s.moniker != null && s.moniker!.isNotEmpty) {
                myMoniker = s.moniker!;
                return IdentityCardSurface(
                  isLandscape: isLandscape,
                  jsonKey: jsonKey,
                  moniker: myMoniker,
                );
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
            _HubTile(icon: Icons.account_circle_outlined, title: 'ID', onTap: () => _pageController.jumpToPage(0)),
            _HubTile(icon: Icons.vpn_key_outlined, title: 'IMPORT / EXPORT', onTap: () => _pageController.jumpToPage(1)),
            _HubTile(icon: Icons.people_outline, title: 'PEOPLE', onTap: () => _pageController.jumpToPage(2)),
            _HubTile(icon: Icons.shield_moon_outlined, title: 'SERVICES', onTap: () => _pageController.jumpToPage(3)),
            _HubTile(icon: Icons.help_outline_rounded, title: 'ABOUT', onTap: () => _pageController.jumpToPage(4)),
            if (_isDevMode) _HubTile(icon: Icons.bug_report_outlined, title: 'DEV', onTap: () => _pageController.jumpToPage(5)),
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
        const Divider(),
        const Text('DEMO DATA', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.blue)),
        const SizedBox(height: 12),
        ...Tester.tests.entries.map((entry) => Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: ElevatedButton(
            onPressed: () async {
              try {
                await entry.value();
                if (mounted) {
                  setState(() {});
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Test "${entry.key}" completed and identity imported.')),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error running ${entry.key}: $e')),
                  );
                }
              }
            },
            child: Text('RUN ${entry.key.toUpperCase()}'),
          ),
        )).toList(),
        if (Tester.name2key.isNotEmpty) ...[
          const Divider(),
          const Text('SWITCH KEYS', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.green)),
          const SizedBox(height: 12),
          ...Tester.name2key.keys.map((name) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: ElevatedButton(
              onPressed: () async {
                try {
                  await Tester.useKey(name);
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Switched to key: $name')),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Error switching to $name: $e')),
                    );
                  }
                }
              },
              child: Text('USE KEY: ${name.toUpperCase()}'),
            ),
          )).toList(),
        ],
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
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('PASTE KEYS JSON', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 1.2)),
                TextButton.icon(
                  onPressed: () async {
                    Navigator.pop(context);
                    final scanned = await QrScanner.scan(
                      context, 
                      title: 'Scan Identity QR',
                      validator: (s) async => s.contains('identity'),
                    );
                    if (scanned != null) {
                      try {
                        await _keys.importKeys(scanned);
                      } catch (e, stackTrace) {
                        if (context.mounted) {
                          ErrorDialog.show(context, 'Import Error', e, stackTrace);
                        }
                      }
                    }
                  },
                  icon: const Icon(Icons.qr_code_scanner_rounded, size: 16),
                  label: const Text('SCAN', style: TextStyle(fontSize: 10)),
                  style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: Size.zero, tapTargetSize: MaterialTapTargetSize.shrinkWrap),
                ),
              ],
            ),
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
              style: const TextStyle(fontFamily: 'monospace', fontSize: 12, color: Color(0xFF37474F)),
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
                }
              } catch (e, stackTrace) {
                if (context.mounted) {
                  ErrorDialog.show(context, 'Import Error', e, stackTrace);
                }
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
