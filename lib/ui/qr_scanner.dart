import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'app_typography.dart';

class QrScanner extends StatefulWidget {
  final String title;
  final String instruction;
  final Future<bool> Function(String) validator;

  const QrScanner({
    super.key,
    required this.title,
    required this.instruction,
    required this.validator,
  });

  @override
  State<QrScanner> createState() => _QrScannerState();

  static Future<String?> scan(
    BuildContext context, {
    String title = 'Scan QR Code',
    required String instruction,
    required Future<bool> Function(String) validator,
  }) async {
    return await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (context) =>
            QrScanner(title: title, instruction: instruction, validator: validator),
      ),
    );
  }
}

class _QrScannerState extends State<QrScanner> {
  bool _isHandled = false;

  void _onDetect(BarcodeCapture capture) async {
    if (_isHandled) return;

    final List<Barcode> barcodes = capture.barcodes;
    for (final barcode in barcodes) {
      final String? code = barcode.rawValue;
      if (code != null) {
        final isValid = await widget.validator(code);
        if (isValid && mounted) {
          _isHandled = true;
          Navigator.of(context).pop(code);
          break;
        }
      }
    }
  }

  Future<void> _handlePaste() async {
    final clipboardData = await Clipboard.getData(Clipboard.kTextPlain);
    final String? text = clipboardData?.text;
    if (text != null && mounted) {
      final isValid = await widget.validator(text);
      if (isValid && mounted) {
        _isHandled = true;
        Navigator.of(context).pop(text);
      } else if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Invalid data in clipboard')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
            child: Text(
              widget.instruction,
              textAlign: TextAlign.center,
              style: AppTypography.caption,
              maxLines: 3,
            ),
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.paste_rounded),
            onPressed: _handlePaste,
            tooltip: 'Paste from clipboard',
          ),
        ],
      ),
      body: Stack(
        children: [
          MobileScanner(onDetect: _onDetect),
          Center(
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.white, width: 2),
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          Positioned(
            bottom: 48,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Align QR code within frame',
                      textAlign: TextAlign.center,
                      style: AppTypography.body.copyWith(color: Colors.white),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '''If you have a QR code in text form, you can paste it using the paste button (top right).''',
                      textAlign: TextAlign.center,
                      style: AppTypography.caption.copyWith(color: Colors.white),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
