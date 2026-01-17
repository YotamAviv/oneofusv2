import 'dart:async';
import 'dart:convert';

import 'package:app_links/app_links.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:oneofus_common/cached_statement_source.dart';
import 'package:oneofus_common/cloud_functions_source.dart';
import 'package:oneofus_common/direct_firestore_writer.dart';
import 'package:oneofus_common/firestore_source.dart';
import 'package:oneofus_common/io.dart';
import 'package:oneofus_common/jsonish.dart';
import 'package:oneofus_common/oou_signer.dart';
import 'package:oneofus_common/oou_verifier.dart';
import 'package:oneofus_common/statement.dart';
import 'package:oneofus_common/trust_statement.dart';
import 'package:oneofus_common/util.dart';

import '../core/config.dart';
import '../core/keys.dart';
import '../core/share_service.dart';
import '../core/sign_in_service.dart';
import '../demotest/tester.dart';
import '../features/about_screen.dart';
import '../features/advanced_screen.dart';
import '../features/dev_screen.dart';
import '../features/card_screen.dart';
import '../features/import_export_screen.dart';
import '../features/welcome_screen.dart';
import '../features/delegates_screen.dart';
import '../features/history_screen.dart';
import '../features/blocks_screen.dart';
import '../features/people_screen.dart';
import '../features/replace/replace_flow.dart';
import 'dialogs/edit_statement_dialog.dart';
import 'dialogs/clear_statement_dialog.dart';
import 'error_dialog.dart';
import 'qr_scanner.dart';

class AppShell extends StatefulWidget {
  final bool isTesting;
  final FirebaseFirestore? firestore;
  const AppShell({super.key, this.isTesting = false, this.firestore});

  @override
  State<AppShell> createState() => _AppShellState();
}

// It's been a struggle to get the top junk aligned...
const double heightKludge = 20;

class _AppShellState extends State<AppShell> with SingleTickerProviderStateMixin {
  final PageController _pageController = PageController();
  final Keys _keys = Keys();
  final _appLinks = AppLinks();
  StreamSubscription<Uri>? _linkSubscription;
  
  int _currentPageIndex = 0;
  bool _isLoading = true;
  bool _hasKey = false;
  bool _hasAlerts = true;
  // Initialize Dev Mode based on environment; secret tap (AboutScreen) allows override.
  late bool _isDevMode = Config.fireChoice != FireChoice.prod;
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
      baseSource = DirectFirestoreSource<TrustStatement>(_firestore);
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
    final String? myToken = _keys.identityToken;
    if (myToken == null) return;
    
    assert(mounted);
    
    // Only show the full-screen loader if we have absolutely no data yet.
    // If we're already displaying things, just set _isRefreshing.
    final bool showFullLoader = _statementsByIssuer.isEmpty && !_isRefreshing;
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
      
      myStatements.removeWhere((s) => s.verb == TrustVerb.clear);

      // 2. Extract everyone I trust (direct contacts)
      final Set<String> directContacts = myStatements
          .where((s) => s.verb == TrustVerb.trust)
          .map((s) => s.subjectToken)
          .toSet();
      
      directContacts.remove(myToken);
      
      Map<String, List<TrustStatement>> results2 = {};
      if (directContacts.isNotEmpty) {
        // 3. Fetch statements from direct contacts
        final Map<String, String?> keysToFetch = {
          for (final String token in directContacts) token: null
        };
        results2 = await _source.fetch(keysToFetch);
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
            for (final list in _statementsByIssuer.values) {
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

  void _handleIncomingLink(Uri uri) async {
    if (uri.scheme == 'keymeid') {
      final dataBase64 = uri.queryParameters['parameters'];
      if (dataBase64 != null) {
        try {
          final data = utf8.decode(base64Url.decode(dataBase64));
          final success = await SignInService.signIn(
            data, 
            context, 
            firestore: _firestore, 
            myStatements: _statementsByIssuer[_keys.identityToken]
          );
          if (success && mounted) {
            _loadAllData();
          }
        } catch (e) {}
      }
    } else if (uri.path.contains('sign-in')) {
      final data = uri.queryParameters['data'];
      if (data != null) {
        final success = await SignInService.signIn(
          data, 
          context, 
          firestore: _firestore, 
          myStatements: _statementsByIssuer[_keys.identityToken]
        );
        if (success && mounted) {
          _loadAllData();
        }
      }
    }
  }

  void _onScanPressed() async {
    final scanned = await QrScanner.scan(
      context,
      title: 'Scan Sign-in or Personal Key',
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
          final success = await SignInService.signIn(
            scanned, 
            context, 
            firestore: _firestore, 
            myStatements: _statementsByIssuer[_keys.identityToken]
          );
          if (success && mounted) {
            _loadAllData();
          }
        } else if (isPubKey(json)) {
          _handlePersonalKeyScan(json);
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

  void _handlePersonalKeyScan(Map<String, dynamic> publicKeyJson) async {
    try {
      final String subjectToken = getToken(publicKeyJson);
      
      if (!mounted) return;

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

      final statementMap = _statementsByIssuer;
      final String myToken = _keys.identityToken!;
      final Set<String> myIdentityKeys = {myToken};
      bool changed = true;
      while (changed) {
        changed = false;
        for (final list in statementMap.values) {
          for (final s in list) {
            if (myIdentityKeys.contains(s.iToken) && s.verb == TrustVerb.replace) {
              if (myIdentityKeys.add(s.subjectToken)) changed = true;
            }
          }
        }
      }

      if (myIdentityKeys.contains(subjectToken)) {
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

      final List<TrustStatement> existingStatement = [];
      for (final list in statementMap.values) {
        existingStatement.addAll(list.where((s) => myIdentityKeys.contains(s.iToken) && s.subjectToken == subjectToken));
      }
      existingStatement.sort((a, b) => b.time.compareTo(a.time));
      
      final TrustStatement? latest = existingStatement.firstOrNull;
      
      final TrustStatement finalStatement;
      if (latest != null) {
        finalStatement = latest;
      } else {
        final myPubKeyJson = await _keys.getIdentityPublicKeyJson();
        final json = TrustStatement.make(
          myPubKeyJson!,
          publicKeyJson,
          TrustVerb.trust,
        );
        finalStatement = TrustStatement(Jsonish(json));
      }

      await _showTrustBlockDialog(
        context: context,
        statement: finalStatement,
        publicKeyJson: publicKeyJson,
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
    TrustVerb? initialVerb,
  }) async {
    await showDialog(
      context: context,
      builder: (context) => EditStatementDialog(
        statement: statement,
        initialVerb: initialVerb,
        onSubmit: ({required verb, comment, domain, moniker, revokeAt}) async {
          await _pushTrustStatement(
            publicKeyJson: publicKeyJson,
            verb: verb,
            moniker: moniker,
            comment: comment,
            domain: domain,
            revokeAt: revokeAt,
          );
        },
      ),
    );
  }

  Future<void> _showClearStatementDialog({
    required BuildContext context,
    required TrustStatement statement,
    required Map<String, dynamic> publicKeyJson,
  }) async {
    await showDialog(
      context: context,
      builder: (context) => ClearStatementDialog(
        statement: statement,
        onSubmit: () async {
          await _pushTrustStatement(
            publicKeyJson: publicKeyJson,
            verb: TrustVerb.clear,
            domain: statement.domain,
          );
        },
      ),
    );
  }

  Future<void> _showTrustBlockDialog({
    required BuildContext context,
    required TrustStatement statement,
    required Map<String, dynamic> publicKeyJson,
    TrustVerb? lockedVerb,
  }) async {
    if (lockedVerb == TrustVerb.clear) {
      return _showClearStatementDialog(
        context: context,
        statement: statement,
        publicKeyJson: publicKeyJson,
      );
    }

    return _showEditStatementDialog(
      context: context,
      statement: statement,
      publicKeyJson: publicKeyJson,
      initialVerb: lockedVerb,
    );
  }

  Future<void> _showDelegateDialog({
    required BuildContext context,
    required String subjectToken,
    required Map<String, dynamic> publicKeyJson,
    required String? domain,
    String? initialRevokeAt,
    DateTime? existingTime,
  }) async {
    String? currentRevokeAt = initialRevokeAt;

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          final isActive = currentRevokeAt == null;
          final isFullyRevoked = currentRevokeAt == kSinceAlways;
          final isPartiallyRevoked = !isActive && !isFullyRevoked;

          return AlertDialog(
            title: const Text('Delegate Authorization'),
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('DOMAIN',
                      style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey.shade600,
                          letterSpacing: 1.2)),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Expanded(
                        child: Text(domain ?? 'Unknown',
                            style: const TextStyle(
                                fontSize: 16, fontWeight: FontWeight.bold)),
                      ),
                      if (existingTime != null)
                        Tooltip(
                          message: 'Latest statement: ${formatUiDatetime(existingTime)}',
                          child: Icon(Icons.info_outline, size: 16, color: Colors.grey.shade400),
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text('STATUS',
                      style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey.shade600,
                          letterSpacing: 1.2)),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: ChoiceChip(
                          label: const Center(child: Text('ACTIVE')),
                          selected: isActive,
                          onSelected: (val) {
                            if (val) {
                              setDialogState(() {
                                currentRevokeAt = null;
                              });
                            }
                          },
                          selectedColor: const Color(0xFF0288D1).withOpacity(0.2),
                          labelStyle: TextStyle(
                            color: isActive
                                ? const Color(0xFF0288D1)
                                : Colors.grey,
                            fontWeight: FontWeight.bold,
                            fontSize: 11,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ChoiceChip(
                          label: const Center(child: Text('FULLY REVOKED')),
                          selected: isFullyRevoked,
                          onSelected: (val) {
                            if (val) {
                              setDialogState(() {
                                currentRevokeAt = kSinceAlways;
                              });
                            }
                          },
                          selectedColor: Colors.blueGrey.withOpacity(0.2),
                          labelStyle: TextStyle(
                            color: isFullyRevoked ? Colors.blueGrey : Colors.grey,
                            fontWeight: FontWeight.bold,
                            fontSize: 11,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  SizedBox(
                    width: double.infinity,
                    child: ChoiceChip(
                      label: const Center(child: Text('REVOKED AT LAST VALID STATEMENT')),
                      selected: isPartiallyRevoked,
                      onSelected: (val) {
                        if (val) {
                          setDialogState(() {
                            if (!isPartiallyRevoked) {
                              currentRevokeAt = (initialRevokeAt != null && initialRevokeAt != kSinceAlways) 
                                ? initialRevokeAt 
                                : "";
                            }
                          });
                        }
                      },
                      selectedColor: Colors.orange.withOpacity(0.2),
                      labelStyle: TextStyle(
                        color: isPartiallyRevoked ? Colors.orange : Colors.grey,
                        fontWeight: FontWeight.bold,
                        fontSize: 11,
                      ),
                    ),
                  ),
                  if (isPartiallyRevoked) ...[
                    const SizedBox(height: 16),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('REVOKE AT STATEMENT TOKEN',
                                  style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.grey.shade600,
                                      letterSpacing: 1.2)),
                              const SizedBox(height: 4),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade100,
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(color: Colors.grey.shade300),
                                ),
                                child: SelectableText(
                                  currentRevokeAt!.isEmpty ? "(Scan Statement or Token)" : currentRevokeAt!,
                                  style: TextStyle(
                                      fontSize: 10, 
                                      fontFamily: 'monospace',
                                      color: currentRevokeAt!.isEmpty ? Colors.grey : Colors.black87),
                                  maxLines: 1,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          icon: const Icon(Icons.qr_code_scanner, size: 20),
                          onPressed: () async {
                              final scanned = await QrScanner.scan(
                                context, 
                                title: "Scan Statement or Token", 
                                validator: (s) async {
                                  if (s.isEmpty) return false;
                                  try {
                                    final json = jsonDecode(s);
                                    if (json is Map<String, dynamic>) return true;
                                  } catch (_) {}
                                  return RegExp(r'^[a-fA-F0-9]{40}$').hasMatch(s);
                                }
                              );
                              if (scanned != null) {
                                String token = scanned;
                                try {
                                  final json = jsonDecode(scanned);
                                  if (json is Map<String, dynamic>) {
                                    token = getToken(json);
                                  }
                                } catch (_) {}
                                
                                setDialogState(() {
                                  currentRevokeAt = token;
                                });
                              }
                          },
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('CANCEL',
                    style: TextStyle(
                        color: Colors.grey.shade600,
                        letterSpacing: 1.2,
                        fontWeight: FontWeight.bold)),
              ),
              ElevatedButton(
                onPressed: () {
                  final hasChanged = currentRevokeAt != initialRevokeAt;
                  final isRevokeAtValid = !isPartiallyRevoked || 
                      (currentRevokeAt != null && RegExp(r'^[a-fA-F0-9]{40}$').hasMatch(currentRevokeAt!));

                  if (!hasChanged || !isRevokeAtValid) return null;

                  return () async {
                    Navigator.pop(context);
                    await _pushTrustStatement(
                      publicKeyJson: publicKeyJson,
                      verb: TrustVerb.delegate,
                      domain: domain,
                      revokeAt: currentRevokeAt,
                    );
                  };
                }(),
                style: ElevatedButton.styleFrom(
                  backgroundColor:
                      isFullyRevoked ? Colors.blueGrey : (isActive ? const Color(0xFF0288D1) : Colors.orange),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
                child: Text(isActive ? 'UPDATE' : 'REVOKE',
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, letterSpacing: 1.2)),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _pushTrustStatement({
    required Map<String, dynamic> publicKeyJson,
    required TrustVerb verb,
    String? moniker,
    String? comment,
    String? domain,
    String? revokeAt,
  }) async {
    final identity = _keys.identity;
    if (identity == null) {
      throw StateError("Cannot push statement without an identity key.");
    }

    // Check if we need to warn about deleting a local delegate key
    final token = getToken(publicKeyJson);
    final isMyDelegate = _keys.isDelegateToken(token);
    final isRevoking = (verb == TrustVerb.delegate && revokeAt != null);
    final isClearing = (verb == TrustVerb.clear);
    
    if (isMyDelegate && (isRevoking || isClearing)) {
      final bool? proceed = await showDialog<bool>(
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
                style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      );
      
      if (proceed != true) return;
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
        revokeAt: revokeAt,
      );
      
      final writer = DirectFirestoreWriter(_firestore);
      final signer = await OouSigner.make(identity);
      
      await writer.push(statementJson, signer);

      if (isMyDelegate && (isRevoking || isClearing)) {
        await _keys.removeDelegateByToken(token);
      }
      
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
        } else if (verb == TrustVerb.replace) {
          action = 'Updated ID History';
          bgColor = Colors.green;
        } else if (verb == TrustVerb.delegate) {
          action = revokeAt == null ? 'Delegated' : 'Revoked';
          bgColor = revokeAt == null ? const Color(0xFF0288D1) : Colors.blueGrey;
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$action: Success'),
            backgroundColor: bgColor
          ),
        );
        await _loadAllData();
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

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    
    final myToken = _keys.identityToken;
    if (!_hasKey || myToken == null) return WelcomeScreen(firestore: _firestore);

    final Map<String, List<TrustStatement>> statementMap = _statementsByIssuer;

    final pages = [
      CardScreen(statementsByIssuer: statementMap, myKeyToken: myToken),
      PeopleScreen(
        statementsByIssuer: statementMap,
        myKeyToken: myToken,
        onRefresh: _loadAllData,
        onEdit: (statement) async {
          await _showTrustBlockDialog(
            context: context,
            statement: statement,
            publicKeyJson: statement.subject,
            lockedVerb: TrustVerb.trust,
          );
          if (mounted) setState(() {});
        },
        onBlock: (statement) async {
          await _showTrustBlockDialog(
            context: context,
            statement: statement,
            publicKeyJson: statement.subject,
            lockedVerb: TrustVerb.block,
          );
          if (mounted) setState(() {});
        },
        onClear: (statement) async {
          await _showTrustBlockDialog(
            context: context,
            statement: statement,
            publicKeyJson: statement.subject,
            lockedVerb: TrustVerb.clear,
          );
          if (mounted) setState(() {});
        },
      ),
      DelegatesScreen(
        statementsByIssuer: statementMap,
        myKeyToken: myToken,
        onRefresh: _loadAllData,
        onEdit: (statement) async {
          await _showDelegateDialog(
            context: context,
            subjectToken: statement.subjectToken,
            publicKeyJson: statement.subject,
            domain: statement.domain,
            initialRevokeAt: statement.revokeAt,
            existingTime: statement.time,
          );
          if (mounted) setState(() {});
        },
        onClear: (statement) async {
          await _showTrustBlockDialog(
            context: context,
            statement: statement,
            publicKeyJson: statement.subject,
            lockedVerb: TrustVerb.clear,
          );
          if (mounted) setState(() {});
        },
      ),
      const ImportExportScreen(),
      AdvancedScreen(
        onShowBlocks: () => _showBlocksModal(context),
        onShowEquivalents: () => _showEquivalentsModal(context),
        onReplaceKey: () => _showReplaceKeyDialog(context),
      ),
      AboutScreen(onDevClick: _handleDevClick),
      if (_isDevMode) DevScreen(onRefresh: _loadAllData),
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

  void _showBlocksModal(BuildContext context) {
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
                  child: BlocksScreen(
                    statementsByIssuer: _statementsByIssuer,
                    myKeyToken: _keys.identityToken!,
                    scrollController: scrollController,
                    onEdit: (s) async {
                      await _showTrustBlockDialog(
                        context: context,
                        statement: s,
                        publicKeyJson: s.subject,
                        lockedVerb: TrustVerb.block,
                      );
                      setModalState(() {});
                    },
                    onClear: (s) async {
                      await _showTrustBlockDialog(
                        context: context,
                        statement: s,
                        publicKeyJson: s.subject,
                        lockedVerb: TrustVerb.clear,
                      );
                      setModalState(() {});
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
                    statementsByIssuer: _statementsByIssuer,
                    myKeyToken: _keys.identityToken!,
                    scrollController: scrollController,
                    onEdit: (s) async {
                      await _showTrustBlockDialog(
                        context: context,
                        statement: s,
                        publicKeyJson: s.subject,
                        lockedVerb: TrustVerb.replace,
                      );
                      setModalState(() {});
                    },
                    onClear: (s) async {
                      await _showTrustBlockDialog(
                        context: context,
                        statement: s,
                        publicKeyJson: s.subject,
                        lockedVerb: TrustVerb.clear,
                      );
                      setModalState(() {});
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

  void _showReplaceKeyDialog(BuildContext context) {
    final identityToken = _keys.identityToken;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ReplaceFlow(
          firestore: _firestore,
          initialOldIdentityToken: identityToken,
        ),
      ),
    ).then((_) => _loadAllData()); // Refresh after flow completes
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
            _HubTile(icon: Icons.credit_card_outlined, title: 'CARD', onTap: () => _pageController.jumpToPage(0)),
            _HubTile(icon: Icons.people_outline, title: 'PEOPLE', onTap: () => _pageController.jumpToPage(1)),
            _HubTile(icon: Icons.shield_moon_outlined, title: 'SERVICES', onTap: () => _pageController.jumpToPage(2)),
            _HubTile(icon: Icons.vpn_key_outlined, title: 'IMPORT / EXPORT', onTap: () => _pageController.jumpToPage(3)),
            _HubTile(icon: Icons.settings_accessibility_rounded, title: 'ADVANCED', onTap: () => _pageController.jumpToPage(4)),
            _HubTile(icon: Icons.help_outline_rounded, title: 'ABOUT', onTap: () => _pageController.jumpToPage(5)),
            if (_isDevMode) _HubTile(icon: Icons.bug_report_outlined, title: 'DEV', onTap: () => _pageController.jumpToPage(6)),
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
