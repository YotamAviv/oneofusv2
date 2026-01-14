import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:oneofus_common/jsonish.dart';
import '../core/keys.dart';

class KeyManagementScreen extends StatefulWidget {
  const KeyManagementScreen({super.key});

  @override
  State<KeyManagementScreen> createState() => _KeyManagementScreenState();
}

class _KeyManagementScreenState extends State<KeyManagementScreen> {
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
      const encoder = JsonEncoder.withIndent('  ');
      if (mounted) {
        setState(() {
          _initialKeysJson = encoder.convert(allKeysJson);
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
      await Keys().importKeys(_textController.text);
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
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
                        border: Border.all(color: Colors.grey[300]!),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: TextField(
                        controller: _textController,
                        readOnly: true,
                        maxLines: null,
                        expands: true,
                        style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                        decoration: const InputDecoration(
                          contentPadding: EdgeInsets.all(12),
                          border: InputBorder.none,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  FittedBox(
                    child: ButtonBar(
                      alignment: MainAxisAlignment.center,
                      children: [
                        OutlinedButton.icon(
                          onPressed: (_isExporting || !canExport) ? null : _exportKeys,
                          icon: const Icon(Icons.download),
                          label: const Text('Export'),
                        ),
                        OutlinedButton.icon(
                          onPressed: isTextFieldEmpty ? null : _copyKeys,
                          icon: const Icon(Icons.copy),
                          label: const Text('Copy'),
                        ),
                        OutlinedButton.icon(
                          onPressed: _pasteKeys,
                          icon: const Icon(Icons.paste),
                          label: const Text('Paste'),
                        ),
                        ElevatedButton.icon(
                          onPressed: canImport ? _importKeys : null,
                          icon: _isImporting 
                              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                              : const Icon(Icons.upload),
                          label: const Text('Import'),
                        ),
                      ],
                    ),
                  ),
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
