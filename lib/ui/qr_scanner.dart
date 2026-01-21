import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'app_typography.dart';

class QrScanner extends StatefulWidget {
  final String title;
  final Future<bool> Function(String) validator;

  const QrScanner({
    super.key,
    required this.title,
    required this.validator,
  });

  @override
  State<QrScanner> createState() => _QrScannerState();

  static Future<String?> scan(
    BuildContext context, {
    String title = 'Scan QR Code',
    required Future<bool> Function(String) validator,
  }) async {
    return await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (context) => QrScanner(title: title, validator: validator),
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
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Invalid data in clipboard')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
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
          MobileScanner(
            onDetect: _onDetect,
          ),
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
                child: Text(
                  'Align QR code within frame',
                  style: AppTypography.body.copyWith(color: Colors.white),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
