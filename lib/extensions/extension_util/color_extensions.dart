import 'package:flutter/material.dart';

// Color Extensions
extension Hex on Color {
  /// return hex String
  String toHex({bool leadingHashSign = true, bool includeAlpha = false}) {
    final r = (this.r * 255).round().clamp(0, 255);
    final g = (this.g * 255).round().clamp(0, 255);
    final b = (this.b * 255).round().clamp(0, 255);
    final a = (this.a * 255).round().clamp(0, 255);

    return '${leadingHashSign ? '#' : ''}'
        '${includeAlpha ? a.toRadixString(16).padLeft(2, '0') : ''}'
        '${r.toRadixString(16).padLeft(2, '0')}'
        '${g.toRadixString(16).padLeft(2, '0')}'
        '${b.toRadixString(16).padLeft(2, '0')}';
  }

  /// Return true if given Color is dark
  bool isDark() => getBrightness() < 128.0;

  /// Return true if given Color is light
  bool isLight() => !isDark();

  /// Returns Brightness of given Color
  double getBrightness() {
    final r = this.r * 255;
    final g = this.g * 255;
    final b = this.b * 255;

    return (r * 299 + g * 587 + b * 114) / 1000;
  }

  /// Returns Luminance of given Color
  double getLuminance() => computeLuminance();
}