import 'package:flutter/material.dart';

class AppTypography {
  // Brand Colors used in Text
  static const _colorPrimary = Color(0xFF37474F); // BlueGrey 800
  static const _colorAccent = Color(0xFF00897B);  // Teal 600

  /// 1. SCREEN HEADERS
  /// Usage: "INTRO", "PEOPLE", "SERVICES", "CLAIM OLD IDENTITY"
  static const header = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w900,
    letterSpacing: 3.0,
    color: _colorPrimary,
  );

  /// 2. HERO TITLES
  /// Usage: "Congratulations!", "Our Own Decentralized Network..."
  static const hero = TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.bold,
    color: _colorPrimary,
    height: 1.2,
  );

  static const display = TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.w900,
    color: _colorPrimary,
  );

  /// 3. ITEM TITLES
  /// Usage: Names in Statement Cards, Dialog Titles
  static const itemTitle = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.bold,
    color: _colorPrimary,
  );

  /// 4. BODY TEXT
  /// Usage: Main reading text (Intro, Block descriptions)
  static const body = TextStyle(
    fontSize: 15,
    height: 1.5,
    color: _colorPrimary,
  );

  /// 5. CAPTION / SECONDARY
  /// Usage: Helper text, empty state descriptions, subtext
  static const caption = TextStyle(
    fontSize: 13,
    height: 1.4,
    color: _colorPrimary,
  );

  /// 6. UI LABELS
  /// Usage: "SCAN", "SHARE", "ENTER NETWORK", "MY IDENTITY KEY"
  static const label = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w900,
    letterSpacing: 1.2,
    color: _colorPrimary,
  );

  /// 9. SMALL UI LABELS
  /// Usage: Section dividers, footer info (where 12px is too big)
  static const labelSmall = TextStyle(
    fontSize: 10,
    fontWeight: FontWeight.w900,
    letterSpacing: 1.2,
    color: Colors.black87, // Often used with grey in dividers
  );

  /// 7. TECHNICAL / MONOSPACE
  /// Usage: Cryptographic keys, Short IDs
  static const mono = TextStyle(
    fontFamily: 'monospace',
    fontSize: 12,
    color: _colorPrimary,
  );

  /// 8. LINKS
  /// Usage: Clickable URLs
  static const link = TextStyle(
    fontSize: 15,
    height: 1.5,
    color: _colorAccent,
    decoration: TextDecoration.underline,
  );
}
