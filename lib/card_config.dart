class CardConfig {
  // Pixel coordinates from your card_background_details.txt
  static const double imgW = 800;
  static const double imgH = 533;
  
  static const double cardL = 50;
  static const double cardT = 66;
  static const double cardR = 750;
  static const double cardB = 467;

  // Derived Card Dimensions (Pixels)
  static double get cardW => cardR - cardL;
  static double get cardH => cardB - cardT;

  // User Specifications (Percentages)
  static const double verticalMargin = 0.02;   // 2% top/bottom margin
  static const double horizontalMargin = 0.02; // 2% left/right margin (safety)
  static const double contentPadding = 0.03;   // 4% padding for QR and text
  
  // Ratio of QR height relative to card height
  static const double qrHeightRatio = 0.90;
}
