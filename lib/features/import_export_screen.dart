import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:oneofus_common/trust_statement.dart';
import '../core/keys.dart';


/* 
"identity" vs "one-of-us.net" Label Swapping

Initially, the app used "one-of-us.net" as the internal storage key for the 
primary identity. 
After I had already launched and had some users, I decided that it's better to display
a person's identity as "identity" (not as "one-of-us.net").
This is visible and stored, as it is the exported JSON text.

To maintain parity with V1 and ensure all legacy backups remain valid:
1. EXPORT: Swap "one-of-us.net" -> "identity" for display.
2. IMPORT: Swap "identity" -> "one-of-us.net" for internal storage.
   Note: We accept both labels on import to support early V1 backups that 
   may still use the raw domain label.

Internal storage in V2 continues to use "one-of-us.net" (kOneofusDomain).

In the future, we may want to phase out "one-of-us.net" entirely and store "identity" internally.
We'll prepare for that now (in case users don't upgrade their phone apps for a long time) by starting
to accept both labels on import.

TODO: In a future major release, migrate internal storage from "one-of-us.net" to "identity" 
across all layers (Keys service, Secure Storage) to simplify this mapping.
*/
class ImportExportScreen extends StatefulWidget {
  const ImportExportScreen({super.key});

  @override
  State<ImportExportScreen> createState() => _ImportExportScreenState();
}

class _ImportExportScreenState extends State<ImportExportScreen> {
  final _textController = TextEditingController();
  String _initialKeysJson = '';
  bool _isImporting = false;
  bool _isExporting = false;

  @override
  void initState() {
    super.initState();
    _loadInitialKeys();
    _textController.addListener(_validateInput);
  }

  void _validateInput() {
    setState(() {});
  }

  Future<void> _loadInitialKeys() async {
    try {
      final keys = Keys();
      final allKeysJson = await keys.getAllKeyJsons();
      final displayKeys = _internal2display(allKeysJson);
      const encoder = JsonEncoder.withIndent('  ');
      if (mounted) {
        setState(() {
          _initialKeysJson = encoder.convert(displayKeys);
        });
      }
    } catch (e) {
      _showError(e.toString());
    }
  }

  Future<void> _exportKeys() async {
    setState(() { _isExporting = true; });
    await _loadInitialKeys();
    
    _textController.clear();
    const chunkSize = 50; 
    const delay = Duration(milliseconds: 1);
    for (int i = 0; i < _initialKeysJson.length; i += chunkSize) {
      if (!mounted) return;
      _textController.text = _initialKeysJson.substring(0, i + chunkSize > _initialKeysJson.length ? _initialKeysJson.length : i + chunkSize);
      await Future.delayed(delay);
    }
    
    if (mounted) setState(() { _isExporting = false; });
  }

  Future<void> _copyKeys() async {
    await Clipboard.setData(ClipboardData(text: _textController.text));
    _showSnackbar('Keys copied to clipboard.');
  }

  Future<void> _pasteKeys() async {
    final clipboardData = await Clipboard.getData(Clipboard.kTextPlain);
    if (clipboardData != null && clipboardData.text != null) {
      _textController.text = clipboardData.text!;
      _showSnackbar('Keys pasted from clipboard.');
    }
  }

  Future<void> _importKeys() async {
    setState(() { _isImporting = true; });
    try {
      final input = _textController.text;
      final Map<String, dynamic> jsonMap = jsonDecode(input) as Map<String, dynamic>;
      final internalMap = _display2internal(jsonMap);
      final internalJson = jsonEncode(internalMap);
      
      await Keys().importKeys(internalJson);
      await _loadInitialKeys();
      _textController.clear();
      _showSnackbar('Import successful!');
    } catch (e) {
      _showError(e.toString());
    } finally {
      if (mounted) setState(() { _isImporting = false; });
    }
  }

  void _showSnackbar(String message) {
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  void _showError(String message) {
    debugPrint('OPERATION FAILED: $message');
    if (mounted) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Operation Failed'),
          content: const Text('See the debug console for details.'),
          actions: [TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('OK'))],
        ),
      );
    }
  }

  Map<String, dynamic> _internal2display(Map<String, dynamic> keys) {
    final result = Map<String, dynamic>.from(keys);
    if (result.containsKey(kOneofusDomain)) {
      result['identity'] = result.remove(kOneofusDomain);
    }
    return result;
  }

  Map<String, dynamic> _display2internal(Map<String, dynamic> keys) {
    final result = Map<String, dynamic>.from(keys);
    // V1 legacy support: prefer 'identity', but accept 'one-of-us.net' if present
    if (result.containsKey('identity')) {
      result[kOneofusDomain] = result.remove('identity');
    }
    return result;
  }

  @override
  Widget build(BuildContext context) {
    final isTextFieldEmpty = _textController.text.isEmpty;
    final canImport = !isTextFieldEmpty && _textController.text != _initialKeysJson;
    final canExport = _textController.text != _initialKeysJson;

    return SafeArea(
      child: Column(
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(24, 24, 24, 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'IMPORT / EXPORT',
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
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 8.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: TextField(
                          controller: _textController,
                          readOnly: false,
                          maxLines: null,
                          expands: true,
                          style: const TextStyle(fontFamily: 'monospace', fontSize: 11, color: Color(0xFF37474F)),
                          decoration: InputDecoration(
                            hintText: 'Keys JSON will appear here...',
                            hintStyle: TextStyle(color: Colors.grey.shade400, fontFamily: 'sans-serif'),
                            contentPadding: const EdgeInsets.all(16),
                            border: InputBorder.none,
                            fillColor: Colors.white,
                            filled: true,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: _ManagementButton(
                          label: 'EXPORT',
                          icon: Icons.download_rounded,
                          onPressed: (_isExporting || !canExport) ? null : _exportKeys,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _ManagementButton(
                          label: 'COPY',
                          icon: Icons.copy_rounded,
                          onPressed: isTextFieldEmpty ? null : _copyKeys,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _ManagementButton(
                          label: 'PASTE',
                          icon: Icons.paste_rounded,
                          onPressed: _pasteKeys,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _ManagementButton(
                          label: 'IMPORT',
                          icon: Icons.upload_rounded,
                          color: const Color(0xFF00897B),
                          textColor: Colors.white,
                          isLoading: _isImporting,
                          onPressed: canImport ? _importKeys : null,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'These keys are secrets. Only export for backup or to port them to another trusted service device.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.blueGrey.shade300,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }
}

class _ManagementButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback? onPressed;
  final Color? color;
  final Color? textColor;
  final bool isLoading;

  const _ManagementButton({
    required this.label,
    required this.icon,
    this.onPressed,
    this.color,
    this.textColor,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    final bool isDisabled = onPressed == null;
    final Color effectiveColor = color ?? Colors.white;
    final Color effectiveTextColor = textColor ?? const Color(0xFF37474F);

    return SizedBox(
      height: 52,
      child: ElevatedButton(
        onPressed: isLoading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: effectiveColor,
          foregroundColor: effectiveTextColor,
          disabledBackgroundColor: Colors.grey.shade100,
          disabledForegroundColor: Colors.grey.shade400,
          elevation: isDisabled ? 0 : 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          padding: EdgeInsets.zero,
        ),
        child: isLoading
            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, size: 18),
                  const SizedBox(width: 8),
                  Text(
                    label,
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 12,
                      letterSpacing: 1.2,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
