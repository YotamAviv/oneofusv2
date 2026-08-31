import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'app_typography.dart';
import 'error_dialog.dart';

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
  bool _captured = false;

  /// How long to hold on the moment of recognition before moving on.
  static const Duration _captureHold = Duration(milliseconds: 850);

  void _onDetect(BarcodeCapture capture) async {
    if (_isHandled) return;

    final List<Barcode> barcodes = capture.barcodes;
    for (final barcode in barcodes) {
      final String? code = barcode.rawValue;
      if (code != null) {
        final isValid = await widget.validator(code);
        if (isValid && mounted) {
          _isHandled = true;
          // Mark the capture, then wait, before leaving the scanner.
          //
          // Decoding is instant and the screen used to change on the same
          // frame, so there was nothing to connect the thing you pointed the
          // camera at with the dialog that appeared -- the scan had already
          // happened by the time you noticed it was happening. A beat here says
          // "got it", the way a shutter does.
          setState(() => _captured = true);
          await Future.delayed(_captureHold);
          if (!mounted) return;
          Navigator.of(context).pop(code);
          return;
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
        ErrorDialog.show(context, 'Invalid Clipboard Data', 'The clipboard does not contain valid scan data');
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
          // The flash of a capture: the frame goes bright for an instant and
          // the reticle turns green and closes on what it found.
          IgnorePointer(
            child: AnimatedOpacity(
              opacity: _captured ? 1 : 0,
              duration: const Duration(milliseconds: 120),
              child: Container(color: Colors.white.withValues(alpha: 0.55)),
            ),
          ),
          Center(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOut,
              width: _captured ? 220 : 250,
              height: _captured ? 220 : 250,
              decoration: BoxDecoration(
                border: Border.all(
                  color: _captured ? Colors.greenAccent.shade400 : Colors.white,
                  width: _captured ? 4 : 2,
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: _captured
                  ? const Center(
                      child: Icon(Icons.check_rounded, color: Colors.white, size: 88))
                  : null,
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
                      '''You can paste text instead of scanning a QR code using the paste button (top right).''',
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
