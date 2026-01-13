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

  // Portrait Specifications
  static const double verticalMarginP = 0.02;
  static const double horizontalMarginP = 0.02;
  static const double contentPaddingP = 0.03;
  static const double qrHeightRatioP = 0.90;

  // Landscape Specifications (Initially identical, can be tuned)
  static const double verticalMarginL = 0.02;
  static const double horizontalMarginL = 0.02;
  static const double contentPaddingL = 0.06;
  static const double qrHeightRatioL = 0.85;
}
