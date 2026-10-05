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

  final bgColor = styles['background-color'] ?? styles['background'];
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
        // Has non-light background, keep original color
        resultStyles.add('$key: $value');
      } else {
        // No background - check if it's a dark color
        final isDark = _isDarkColor(value);
        if (!isDark) {
          resultStyles.add('$key: $value');
        }
      }
    } else if (key == 'background-color' || key == 'background') {
      if (isLightBackground) {
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
