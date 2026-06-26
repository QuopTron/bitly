import 'package:flutter/material.dart';

class ColorUtils {
  static Color textColorFor(Color bg) {
    return bg.computeLuminance() > 0.5 ? Colors.black : Colors.white;
  }

  static Color overlayFor(Color bg) {
    final luminance = bg.computeLuminance();
    final double alpha;
    if (luminance > 0.7) {
      alpha = 0.05;
    } else if (luminance > 0.4) {
      alpha = 0.15;
    } else {
      alpha = 0.35;
    }
    return luminance > 0.5
        ? Colors.white.withValues(alpha: alpha)
        : Colors.black.withValues(alpha: alpha);
  }

  static Color surfaceFor(Color bg) {
    final luminance = bg.computeLuminance();
    return luminance > 0.5
        ? Colors.black.withValues(alpha: 0.08)
        : Colors.white.withValues(alpha: 0.08);
  }

  static Color mutedTextFor(Color bg) {
    final text = textColorFor(bg);
    return text.withValues(alpha: 0.55);
  }

  static List<Color> generatePlaceholderGradient(int index) {
    const palettes = [
      [Color(0xFF667eea), Color(0xFF764ba2)],
      [Color(0xFFf093fb), Color(0xFFf5576c)],
      [Color(0xFF4facfe), Color(0xFF00f2fe)],
      [Color(0xFF43e97b), Color(0xFF38f9d7)],
      [Color(0xFFfa709a), Color(0xFFfee140)],
      [Color(0xFFa18cd1), Color(0xFFfbc2eb)],
      [Color(0xFFfccb90), Color(0xFFd57eeb)],
      [Color(0xFFe0c3fc), Color(0xFF8ec5fc)],
      [Color(0xFF0ba360), Color(0xFF3cba92)],
      [Color(0xFFff758c), Color(0xFFff7eb3)],
      [Color(0xFF3b82f6), Color(0xFF8b5cf6)],
      [Color(0xFFf59e0b), Color(0xFFef4444)],
    ];
    return palettes[index % palettes.length];
  }
}
