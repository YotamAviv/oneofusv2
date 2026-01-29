import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:oneofus/ui/app_shell.dart';
import 'package:oneofus_common/util.dart';
import 'package:oneofus_common/jsonish.dart';
import 'package:oneofus_common/trust_statement.dart';
import 'package:oneofus_common/crypto.dart';
import 'package:oneofus_common/crypto25519.dart';
import 'package:oneofus_common/oou_signer.dart';
import 'package:oneofus_common/direct_firestore_writer.dart';
import 'package:oneofus_common/cloud_functions_source.dart';
import 'package:oneofus_common/oou_verifier.dart';
import '../../ui/app_typography.dart';
import '../../core/config.dart';
import '../../core/keys.dart';
import '../../ui/error_dialog.dart';
import '../../ui/qr_scanner.dart';

/// CONSIDER: Clean up the KLUDGEY stuff.
/// There are actuall 3 modes, not 2 (claimMode true/false)
/// 1. Claiming old identity into current one. (Clacker impl)
/// 2. Replacing current identity with a new one. (Clacker impl)
/// 3. Welcome screen. Create a new identity and claim the old one. (I (human) kludged it to
///    work and make AppShell.loadAllData public)

class ReplaceFlow extends StatefulWidget {
  final FirebaseFirestore firestore;
  final String? initialOldIdentityToken;

  // true: claiming an old identity into the current one.
  // false: replacing current identity with a new one.
  final bool claimMode;

  const ReplaceFlow({
    super.key,
    required this.firestore,
    this.initialOldIdentityToken,
    this.claimMode = false,
  });

  @override
  State<ReplaceFlow> createState() => _ReplaceFlowState();
}

class _ReplaceFlowState extends State<ReplaceFlow> {
  final PageController _pageController = PageController();

  String token6(String token) => token.length > 6 ? token.substring(0, 6) : token;

  String? _oldIdentityToken;
  Json? _oldIdentityPubKeyJson;

  @override
  void initState() {
    super.initState();
    _oldIdentityToken = widget.initialOldIdentityToken;
    if (_oldIdentityToken != null && _oldIdentityToken == Keys().identityToken) {
      Keys().getIdentityPublicKeyJson().then((json) {
        if (mounted) setState(() => _oldIdentityPubKeyJson = json);
      });
    }
  }

  void _nextPage() {
    _pageController.nextPage(duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
  }

  // ignore: unused_element
  void _previousPage() {
    _pageController.previousPage(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final List<Widget> steps = [
      _buildIntroScreen(),
      if (widget.claimMode) _buildIdentifyScreen(),
      _buildReviewScreen(),
      _buildProcessingScreen(),
      _buildSuccessScreen(),
    ];

    return Scaffold(
      backgroundColor: const Color(0xFFF2F0EF),
      appBar: AppBar(
        title: Text(
          widget.claimMode ? 'CLAIM OLD IDENTITY' : 'REPLACE IDENTITY',
          style: AppTypography.header,
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: const Color(0xFF37474F),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: PageView(
        controller: _pageController,
        physics: const NeverScrollableScrollPhysics(),
        children: steps,
      ),
    );
  }

  Widget _buildIntroScreen() {
    if (widget.claimMode) {
      return SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'The process of claiming an old key to merge its history into your current identity has these steps:',
              style: AppTypography.body,
            ),
            const SizedBox(height: 24),
            _buildStepItem(1, 'Identify Old Key', 'Scan or verify the key you want to claim.'),
            _buildStepItem(
              2,
              'Re-sign Content',
              'Your current key will re-publish all active trusts, blocks, and delegate assignments issued by the old key.',
            ),
            _buildStepItem(
              3,
              'Claim & Revoke',
              'Your current key will sign and publish a replace statement, formally claiming and revoking the old key.',
            ),
            _buildStepItem(
              4,
              'Web-of-Trust Verification',
              'At this point, your new key is unknown, and so you\'ll have to ask those who\'ve vouched for you in the past to vouch for you again, this time referencing your new key.',
            ),
            _buildStepItem(
              5,
              'Equivalence',
              'The network should now recognize this new key as you. Your old key will be recognized as an equivalent and will be visible in your Equivalent Keys section of the Advanced Screen.',
            ),
            const SizedBox(height: 40),
            ElevatedButton(
              onPressed: _nextPage,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 20),
                backgroundColor: const Color(0xFF37474F),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: Text(
                'I UNDERSTAND, PROCEED',
                style: AppTypography.label.copyWith(color: Colors.white),
              ),
            ),
          ],
        ),
      );
    } else {
      return SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'The process of claiming (replacing) your old key and starting to use a new one will go like this:',
              style: AppTypography.body,
            ),
            const SizedBox(height: 24),
            _buildStepItem(
              1,
              'Generate Identity Key',
              'Create a new key to serve as your new primary identity.',
            ),
            _buildStepItem(
              2,
              'Re-sign Content',
              'Use your new key to re-publish all active trusts, blocks, and delegate assignments issued by the old key.\n\n- In case your old key was compromised: you\'ll be able to re-publish only what\'s valid.',
            ),
            _buildStepItem(
              3,
              'Claim & Revoke',
              'Your current key will sign and publish a replace statement, formally claiming and revoking the old key.',
            ),
            _buildStepItem(
              4,
              'Web-of-Trust Verification',
              'At this point, your new key is unknown, and so you\'ll have to ask those who\'ve vouched for you in the past to vouch for you again, this time referencing your new key.',
            ),
            _buildStepItem(
              5,
              'Equivalence',
              'The network should now recognize this new key as you. Your old key will be recognized as an equivalent and will be visible in your Equivalent Keys section of the Advanced Screen.',
            ),
            const SizedBox(height: 40),
            ElevatedButton(
              onPressed: _nextPage,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 20),
                backgroundColor: const Color(0xFF37474F),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: Text(
                'I UNDERSTAND, PROCEED',
                style: AppTypography.label.copyWith(color: Colors.white),
              ),
            ),
          ],
        ),
      );
    }
  }

  Widget _buildStepItem(int num, String title, String description) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 14,
            backgroundColor: const Color(0xFF00897B),
            child: Text('$num', style: AppTypography.body.copyWith(color: Colors.white)),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppTypography.itemTitle),
                const SizedBox(height: 4),
                Text(description, style: AppTypography.body),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIdentifyScreen() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Icon(Icons.qr_code_scanner_rounded, size: 80, color: Color(0xFF00897B)),
          const SizedBox(height: 32),
          Text(
            widget.claimMode
                ? 'Identify the key you want to claim.'
                : 'Identify your old identity.',
            textAlign: TextAlign.center,
            style: AppTypography.header,
          ),
          const SizedBox(height: 12),
          Text(
            widget.claimMode
                ? 'Scan the QR code of the identity you want to merge into this one.'
                : 'Scan the QR code of your old identity from another device or a backup.',
            textAlign: TextAlign.center,
            style: AppTypography.caption,
          ),
          const SizedBox(height: 48),
          ElevatedButton.icon(
            onPressed: _scanOldIdentity,
            icon: const Icon(Icons.qr_code_scanner),
            label: const Text('SCAN OLD IDENTITY QR'),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 20),
              backgroundColor: const Color(0xFF37474F),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
          if (_oldIdentityToken != null) ...[
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.check_circle, color: Colors.green),
                const SizedBox(width: 8),
                Text('Identified: ${token6(_oldIdentityToken!)}', style: AppTypography.body),
              ],
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _nextPage,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 20),
                backgroundColor: const Color(0xFF00897B),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: Text(
                'FOUND IT, PROCEED',
                style: AppTypography.label.copyWith(color: Colors.white),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _scanOldIdentity() async {
    final result = await QrScanner.scan(
      context,
      title: 'Scan Old Identity',
      instruction: '''Scan a previous identity key that you've used to claim that it represents you.''',
      validator: (s) async {
        try {
          final map = jsonDecode(s);
          return map is Map;
        } catch (_) {
          return false;
        }
      },
    );

    if (result != null) {
      try {
        final json = jsonDecode(result);

        if (json is Map<String, dynamic> && isPubKey(json)) {
          final token = getToken(json);
          final exists = await _verifyIdentityExists(token);
          if (exists) {
            setState(() {
              _oldIdentityToken = token;
              _oldIdentityPubKeyJson = json;
            });
          } else {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Identity found, but it has no history on the network.'),
                ),
              );
            }
          }
        } else {
          throw Exception('Could not find identity token in the scanned QR code.');
        }
      } catch (e) {
        if (mounted) ErrorDialog.show(context, 'Identification Error', e, null);
      }
    }
  }

  Future<bool> _verifyIdentityExists(String token) async {
    debugPrint('[ReplaceFlow] _verifyIdentityExists (via HTTP): token=$token');
    try {
      final source = CloudFunctionsSource<TrustStatement>(
        baseUrl: Config.exportUrl,
        verifier: OouVerifier(),
        // We only need to know if at least one exists
        paramsOverride: {"distinct": "true", "includeId": "false", "checkPrevious": "false"},
      );
      final results = await source.fetch({token: null});
      final exists = results[token]?.isNotEmpty ?? false;
      debugPrint('[ReplaceFlow] _verifyIdentityExists result: $exists');
      return exists;
    } catch (e) {
      debugPrint('[ReplaceFlow] _verifyIdentityExists error: $e');
      return false;
    }
  }

  List<TrustStatement>? _allStatements;
  TrustStatement? _selectedLastValid;
  bool _isLoadingHistory = false;

  Future<void> _fetchHistory() async {
    if (_oldIdentityToken == null) {
      debugPrint('[ReplaceFlow] _fetchHistory: _oldIdentityToken is null');
      return;
    }

    setState(() {
      _isLoadingHistory = true;
      _allStatements = null;
    });

    try {
      final source = CloudFunctionsSource<TrustStatement>(
        baseUrl: Config.exportUrl,
        verifier: OouVerifier(),
        paramsOverride: {
          "distinct": "false",
          "includeId": "false",
          "checkPrevious": "false",
          "omit": [], // Don't omit anything so we can see full records in logs
        },
      );

      debugPrint(
        '[ReplaceFlow] Executing HTTP fetch via CloudFunctionsSource for $_oldIdentityToken',
      );
      final results = await source.fetch({_oldIdentityToken!: null});
      final List<TrustStatement> statements = results[_oldIdentityToken!] ?? [];

      debugPrint('[ReplaceFlow] _fetchHistory: statements=${statements.length}');

      // Sort manually to ensure descending order by time
      statements.sort((a, b) => b.time.compareTo(a.time));

      if (mounted) {
        setState(() {
          _allStatements = statements;
          _selectedLastValid = statements.firstOrNull;
          _isLoadingHistory = false;
        });
      }
    } catch (e) {
      debugPrint('[ReplaceFlow] _fetchHistory ERROR: $e');
      if (mounted) {
        setState(() => _isLoadingHistory = false);
        ErrorDialog.show(context, 'Error fetching history', e, null);
      }
    }
  }

  Widget _buildReviewScreen() {
    if (_allStatements == null && !_isLoadingHistory) {
      // Trigger fetch on first enter
      Future.microtask(_fetchHistory);
    }

    if (_isLoadingHistory) {
      return const Center(child: CircularProgressIndicator());
    }

    // Identify which statements are distinct up to the selection
    final distinctTokens = _getDistinctStatementTokens();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            (_allStatements?.isEmpty ?? true)
                ? 'No history found for this identity. You can proceed to purely rotate your key.'
                : 'Select your last valid statement. \nAny statements made after this (e.g., by a compromise) will be ignored.',
            textAlign: TextAlign.center,
            style: AppTypography.caption,
          ),
        ),
        if (_allStatements != null && _allStatements!.isNotEmpty)
          Expanded(
            child: ListView.builder(
              itemCount: _allStatements!.length,
              itemBuilder: (context, index) {
                final s = _allStatements![index];
                final bool isInvalid =
                    _selectedLastValid != null && s.time.compareTo(_selectedLastValid!.time) > 0;
                final bool isNotDistinct = !isInvalid && !distinctTokens.contains(s.token);
                final bool isSelected = s == _selectedLastValid;

                Color textColor = const Color(0xFF37474F);
                if (isInvalid) {
                  textColor = Colors.grey.shade400; // Light gray
                } else if (isNotDistinct) {
                  textColor = Colors.grey.shade600; // Darker gray
                }

                return ListTile(
                  selected: isSelected,
                  selectedTileColor: const Color(0xFF00897B).withValues(alpha: 0.1),
                  isThreeLine: s.jsonish['comment'] != null,
                  leading: _buildStatementIcon(s, isInvalid, isNotDistinct),
                  title: Text(
                    _getStatementLabel(s),
                    style: AppTypography.body.copyWith(
                      color: textColor,
                      decoration: isInvalid ? TextDecoration.lineThrough : null,
                    ),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${s.time} • ${token6(s.token)}',
                        style: AppTypography.labelSmall.copyWith(
                          color: textColor.withValues(alpha: 0.7),
                        ),
                      ),
                      if (s.jsonish['comment'] != null)
                        Text(
                          s.jsonish['comment'],
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.labelSmall.copyWith(
                            color: textColor.withValues(alpha: 0.6),
                          ),
                        ),
                    ],
                  ),
                  onTap: () => setState(() => _selectedLastValid = s),
                );
              },
            ),
          )
        else
          const Expanded(
            child: Center(child: Icon(Icons.history_toggle_off, size: 64, color: Colors.grey)),
          ),

        Padding(
          padding: const EdgeInsets.all(24),
          child: ElevatedButton(
            onPressed: (_allStatements != null) ? _startRecovery : null,
            // TODO: factor out common style
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 20),
              backgroundColor: const Color(0xFF37474F),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              minimumSize: const Size(double.infinity, 50),
            ),
            child: Text('START RECOVERY', style: AppTypography.label.copyWith(color: Colors.white)),
          ),
        ),
      ],
    );
  }

  bool _isProcessing = false;
  String _processingStatus = '';
  double _processingProgress = 0.0;

  Future<void> _startRecovery() async {
    if (_allStatements == null) return;

    _nextPage(); // Move to processing screen
    setState(() {
      _isProcessing = true;
      _processingStatus = 'Initializing...';
      _processingProgress = 0.0;
    });

    try {
      final keys = Keys();
      if (keys.identity == null) {
        // KLUDGEY: This helps on the Welcome screen.
        await keys.newIdentity();
      }

      final OouKeyPair? oldIdentity = (_oldIdentityToken == keys.identityToken)
          ? keys.identity
          : null;

      final OouSigner signer;
      final Json newPubKeyJson;
      final OouKeyPair? newKeyPair; // Only used if not claiming

      if (widget.claimMode) {
        // 1. Load Current Identity
        setState(() => _processingStatus = 'Loading current identity...');
        final kp = keys.identity;
        if (kp == null) throw Exception("Current identity key pair not found");
        newKeyPair = null;
        signer = await OouSigner.make(kp);
        newPubKeyJson = await (await kp.publicKey).json;
      } else {
        // 1. Generate new identity key
        setState(() => _processingStatus = 'Generating new identity key...');
        newKeyPair = await const CryptoFactoryEd25519().createKeyPair();
        newPubKeyJson = await (await newKeyPair.publicKey).json;
        signer = await OouSigner.make(newKeyPair);
      }

      final writer = DirectFirestoreWriter(widget.firestore);

      // 2. Filter valid statements and re-publish
      final validStatements = _allStatements!
          .where(
            (s) => _selectedLastValid == null || s.time.compareTo(_selectedLastValid!.time) <= 0,
          )
          .toList()
          .reversed // Oldest first
          .toList();

      final distinctTokens = _getDistinctStatementTokens();
      final toPublish = validStatements.where((s) => distinctTokens.contains(s.token)).toList();

      for (int i = 0; i < toPublish.length; i++) {
        final s = toPublish[i];
        setState(() {
          _processingStatus = 'Re-publishing: ${_getStatementLabel(s)}';
          _processingProgress = (i / (toPublish.length + 1)) * 0.8;
        });

        final oldJson = Map<String, dynamic>.from(s.jsonish.json);
        oldJson['I'] = newPubKeyJson;
        oldJson.remove('signature');
        oldJson.remove('previous');
        oldJson['time'] = clock.nowIso; // Set fresh timestamp for re-published content

        await writer.push(oldJson, signer);

        await Future.delayed(const Duration(milliseconds: 100));
      }

      // 3. Issue Replace + Revoke
      setState(() {
        _processingStatus = 'Publishing replacement claim...';
        _processingProgress = 0.9;
      });

      final oldPubKeyJson = oldIdentity != null
          ? await (await oldIdentity.publicKey).json
          : (_allStatements!.isNotEmpty
                ? validStatements.last.jsonish['I']
                : _oldIdentityPubKeyJson);

      if (oldPubKeyJson == null) {
        throw Exception('Could not determine the public key of the identity being replaced.');
      }

      final replaceJson = TrustStatement.make(
        newPubKeyJson,
        oldPubKeyJson,
        TrustVerb.replace,
        revokeAt: kSinceAlways,
        comment: widget.claimMode ? 'Identity claim.' : 'Identity recovery/rotation.',
      );

      await writer.push(replaceJson, signer);

      // 4. Switch local storage (Only if replacing with NEW key)
      if (!widget.claimMode && newKeyPair != null) {
        setState(() {
          _processingStatus = 'Finalizing...';
          _processingProgress = 1.0;
        });

        final allKeyJsons = await keys.getAllKeyJsons();
        allKeyJsons[kOneofusDomain] = await newKeyPair.json;
        await keys.importKeys(jsonEncode(allKeyJsons));
      }

      if (mounted) {
        setState(() => _isProcessing = false);
        _nextPage(); // Move to success screen
      }

      await AppShell.instance.loadAllData();
    } catch (e) {
      if (mounted) {
        setState(() {
          _isProcessing = false;
          _processingStatus = 'Error: $e';
        });
        ErrorDialog.show(context, 'Recovery Failed', e, null);
      }
    }
  }

  Set<String> _getDistinctStatementTokens() {
    if (_allStatements == null) return {};

    final distincts = <String, TrustStatement>{};
    // Work chronologically from start of time up to selection
    final chronList = _allStatements!
        .where((s) => _selectedLastValid == null || s.time.compareTo(_selectedLastValid!.time) <= 0)
        .toList()
        .reversed
        .toList();

    for (final s in chronList) {
      distincts[s.subjectToken] = s;
    }
    return distincts.values.map((s) => s.token).toSet();
  }

  Widget _buildStatementIcon(TrustStatement s, bool isInvalid, bool isNotDistinct) {
    IconData icon;
    Color color;

    switch (s.verb) {
      case TrustVerb.trust:
        icon = Icons.check_circle_outline;
        color = Colors.teal;
        break;
      case TrustVerb.block:
        icon = Icons.block;
        color = Colors.red;
        break;
      case TrustVerb.clear:
        icon = Icons.delete_outline;
        color = Colors.grey;
        break;
      case TrustVerb.delegate:
        icon = Icons.key;
        color = Colors.orange;
        break;
      default:
        icon = Icons.help_outline;
        color = Colors.blueGrey;
    }

    if (isInvalid) {
      color = Colors.grey.shade300;
    } else if (isNotDistinct) {
      color = Colors.grey.shade500;
    }

    return Icon(icon, color: color);
  }

  String _getStatementLabel(TrustStatement s) {
    final verbStr = s.verb.name.toUpperCase();
    final subject = s.moniker ?? token6(s.subjectToken);
    return '$verbStr: $subject';
  }

  Widget _buildProcessingScreen() {
    return Padding(
      padding: const EdgeInsets.all(48),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 120,
            height: 120,
            child: CircularProgressIndicator(
              value: _isProcessing ? _processingProgress : null,
              strokeWidth: 8,
              backgroundColor: Colors.teal.withValues(alpha: 0.1),
              valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF00897B)),
            ),
          ),
          const SizedBox(height: 48),
          Text(_processingStatus, textAlign: TextAlign.center, style: AppTypography.body),
          const SizedBox(height: 12),
          Text(
            'Keep the app open until the process is complete.',
            textAlign: TextAlign.center,
            style: AppTypography.caption,
          ),
        ],
      ),
    );
  }

  Widget _buildSuccessScreen() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.check_circle_rounded, size: 100, color: Color(0xFF00897B)),
          const SizedBox(height: 32),
          Text(
            widget.claimMode ? 'Key Claimed!' : 'Identity Recovered!',
            style: AppTypography.hero,
          ),
          const SizedBox(height: 16),
          Text(
            widget.claimMode
                ? 'The old key history has been merged into your current identity.\n\nAll valid statements have been re-issued by you and the network will now recognize the old key as an equivalent to your current key.'
                : 'Your new key is now active. \n\nIMPORTANT: Since this is a new key, you MUST contact your trusted network and ask them to vouch for you again.',
            textAlign: TextAlign.center,
            style: AppTypography.body,
          ),
          const SizedBox(height: 48),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 40),
              backgroundColor: const Color(0xFF37474F),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: Text('DONE', style: AppTypography.label.copyWith(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}
