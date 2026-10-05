String normalizeHtmlColors(String html) {
  // Process style attributes to handle colors properly for dark theme
  final stylePattern = RegExp(r'style\s*=\s*"([^"]*)"', caseSensitive: false);

  var result = html.replaceAllMapped(stylePattern, (match) {
    final styleContent = match.group(1) ?? '';
    final processedStyle = _processStyleForDarkTheme(styleContent);
    if (processedStyle.isEmpty) {
      return '';
    }
    return 'style="$processedStyle"';
  });

  // Also handle single-quoted styles
  final singleQuotePattern = RegExp(r"style\s*=\s*'([^']*)'", caseSensitive: false);
  result = result.replaceAllMapped(singleQuotePattern, (match) {
    final styleContent = match.group(1) ?? '';
    final processedStyle = _processStyleForDarkTheme(styleContent);
    if (processedStyle.isEmpty) {
      return '';
    }
    return "style='$processedStyle'";
  });

  return result;
}

bool _isTransparent(String value) {
  final normalized = value.trim().toLowerCase();
  const keywords = {'transparent', 'inherit', 'initial', 'unset', 'none', 'currentcolor'};
  if (keywords.contains(normalized)) return true;
  final rgba = RegExp(r'rgba\s*\([^,]+,[^,]+,[^,]+,\s*([\d.]+)\s*\)').firstMatch(normalized);
  if (rgba != null) return (double.tryParse(rgba.group(1)!) ?? 1) == 0;
  return false;
}

List<int>? _rgbChannels(String value) {
  final match = RegExp(r'rgba?\s*\(\s*(\d+)\s*,\s*(\d+)\s*,\s*(\d+)').firstMatch(value);
  if (match != null) {
    return [for (var i = 1; i <= 3; i++) int.tryParse(match.group(i)!) ?? 0];
  }
  final hex = RegExp(r'#([0-9a-fA-F]{6}|[0-9a-fA-F]{3})\b').firstMatch(value)?.group(1);
  if (hex == null) return null;
  final full = hex.length == 3 ? hex.split('').map((ch) => '$ch$ch').join() : hex;
  return [for (var i = 0; i < 6; i += 2) int.parse(full.substring(i, i + 2), radix: 16)];
}

bool _isTranslucent(String value) {
  final alpha = RegExp(r'rgba\s*\([^,]+,[^,]+,[^,]+,\s*([\d.]+)\s*\)')
      .firstMatch(value.toLowerCase())
      ?.group(1);
  return alpha != null && (double.tryParse(alpha) ?? 1) < 0.8;
}

bool _isSaturated(String value) {
  final channels = _rgbChannels(value);
  if (channels == null) return false;
  final max = channels.reduce((a, b) => a > b ? a : b);
  final min = channels.reduce((a, b) => a < b ? a : b);
  return max - min >= 80;
}

String _processStyleForDarkTheme(String styleContent) {
  final styles = <String, String>{};

  // Parse style properties
  final props = styleContent.split(';');
  for (final prop in props) {
    final colonIndex = prop.indexOf(':');
    if (colonIndex == -1) continue;
    final key = prop.substring(0, colonIndex).trim().toLowerCase();
    final value = prop.substring(colonIndex + 1).trim();
    if (key.isNotEmpty && value.isNotEmpty) {
      styles[key] = value;
    }
  }

  final rawBgColor = styles['background-color'] ?? styles['background'];
  final bgColor = rawBgColor != null && _isTransparent(rawBgColor) ? null : rawBgColor;
  final resultStyles = <String>[];

  // Check if background is light and should be inverted/removed
  final bgBrightness = bgColor != null ? _getColorBrightness(bgColor) : null;
  final isLightBackground = bgBrightness != null && bgBrightness > 180;

  for (final entry in styles.entries) {
    final key = entry.key;
    final value = entry.value;

    if (key == 'color') {
      if (isLightBackground) {
        // Light background will be removed, so invert dark text to light
        final textBrightness = _getColorBrightness(value);
        if (textBrightness != null && textBrightness < 128) {
          // Dark text on light bg -> make it white for dark theme
          // Skip - let default white text show
        } else {
          resultStyles.add('$key: $value');
        }
      } else if (bgColor != null) {
        final isGrayDarkOnTranslucent =
            _isTranslucent(bgColor) && _isDarkColor(value) && !_isSaturated(value);
        if (!isGrayDarkOnTranslucent) {
          resultStyles.add('$key: $value');
        }
      } else {
        // No background - check if it's a dark color
        final isDark = _isDarkColor(value);
        if (!isDark) {
          resultStyles.add('$key: $value');
        }
      }
    } else if (key == 'background-color' || key == 'background') {
      if (bgColor == null || isLightBackground) {
        // Skip light backgrounds - they look bad on dark theme
        // Don't add to result
      } else {
        // Keep dark/colored backgrounds
        resultStyles.add('$key: $value');
      }
    } else if (key == 'font-size' || key == 'font-weight' || key == 'font-style' ||
               key == 'text-decoration' || key == 'text-align') {
      // Keep text formatting styles
      resultStyles.add('$key: $value');
    }
  }

  return resultStyles.join('; ');
}

double? _getColorBrightness(String colorValue) {
  final rgbMatch = RegExp(r'rgb\s*\(\s*(\d+)\s*,\s*(\d+)\s*,\s*(\d+)\s*\)').firstMatch(colorValue);
  if (rgbMatch != null) {
    final r = int.tryParse(rgbMatch.group(1) ?? '') ?? 0;
    final g = int.tryParse(rgbMatch.group(2) ?? '') ?? 0;
    final b = int.tryParse(rgbMatch.group(3) ?? '') ?? 0;
    return (r * 299 + g * 587 + b * 114) / 1000;
  }

  final rgbaMatch = RegExp(r'rgba\s*\(\s*(\d+)\s*,\s*(\d+)\s*,\s*(\d+)').firstMatch(colorValue);
  if (rgbaMatch != null) {
    final r = int.tryParse(rgbaMatch.group(1) ?? '') ?? 0;
    final g = int.tryParse(rgbaMatch.group(2) ?? '') ?? 0;
    final b = int.tryParse(rgbaMatch.group(3) ?? '') ?? 0;
    return (r * 299 + g * 587 + b * 114) / 1000;
  }

  final hexMatch = RegExp(r'#([0-9a-fA-F]{6}|[0-9a-fA-F]{3})').firstMatch(colorValue);
  if (hexMatch != null) {
    final hex = hexMatch.group(1)!;
    int r, g, b;
    if (hex.length == 3) {
      r = int.parse('${hex[0]}${hex[0]}', radix: 16);
      g = int.parse('${hex[1]}${hex[1]}', radix: 16);
      b = int.parse('${hex[2]}${hex[2]}', radix: 16);
    } else {
      r = int.parse(hex.substring(0, 2), radix: 16);
      g = int.parse(hex.substring(2, 4), radix: 16);
      b = int.parse(hex.substring(4, 6), radix: 16);
    }
    return (r * 299 + g * 587 + b * 114) / 1000;
  }

  // Named colors
  const namedBrightness = {
    'white': 255.0, 'snow': 255.0, 'ivory': 255.0,
    'black': 0.0, 'navy': 30.0, 'darkblue': 35.0,
  };
  return namedBrightness[colorValue.toLowerCase()];
}

bool _isDarkColor(String colorValue) {
  // Check if color is dark (would be invisible on dark background)
  final rgbMatch = RegExp(r'rgb\s*\(\s*(\d+)\s*,\s*(\d+)\s*,\s*(\d+)\s*\)').firstMatch(colorValue);
  if (rgbMatch != null) {
    final r = int.tryParse(rgbMatch.group(1) ?? '') ?? 0;
    final g = int.tryParse(rgbMatch.group(2) ?? '') ?? 0;
    final b = int.tryParse(rgbMatch.group(3) ?? '') ?? 0;
    // Calculate perceived brightness (standard formula)
    final brightness = (r * 299 + g * 587 + b * 114) / 1000;
    return brightness < 128; // Dark if brightness is less than 50%
  }

  final rgbaMatch = RegExp(r'rgba\s*\(\s*(\d+)\s*,\s*(\d+)\s*,\s*(\d+)').firstMatch(colorValue);
  if (rgbaMatch != null) {
    final r = int.tryParse(rgbaMatch.group(1) ?? '') ?? 0;
    final g = int.tryParse(rgbaMatch.group(2) ?? '') ?? 0;
    final b = int.tryParse(rgbaMatch.group(3) ?? '') ?? 0;
    final brightness = (r * 299 + g * 587 + b * 114) / 1000;
    return brightness < 128;
  }

  // Check hex colors
  final hexMatch = RegExp(r'#([0-9a-fA-F]{6}|[0-9a-fA-F]{3})').firstMatch(colorValue);
  if (hexMatch != null) {
    final hex = hexMatch.group(1)!;
    int r, g, b;
    if (hex.length == 3) {
      r = int.parse('${hex[0]}${hex[0]}', radix: 16);
      g = int.parse('${hex[1]}${hex[1]}', radix: 16);
      b = int.parse('${hex[2]}${hex[2]}', radix: 16);
    } else {
      r = int.parse(hex.substring(0, 2), radix: 16);
      g = int.parse(hex.substring(2, 4), radix: 16);
      b = int.parse(hex.substring(4, 6), radix: 16);
    }
    final brightness = (r * 299 + g * 587 + b * 114) / 1000;
    return brightness < 128;
  }

  // Check named colors that are dark
  final darkColors = {'black', 'darkblue', 'darkgreen', 'darkred', 'navy', 'maroon', 'purple'};
  return darkColors.contains(colorValue.toLowerCase());
}
