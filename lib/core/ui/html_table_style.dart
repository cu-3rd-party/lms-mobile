import 'package:flutter/material.dart';
import 'package:flutter_html/flutter_html.dart';

import 'package:cumobile/core/theme/app_colors.dart';

Map<String, Style> htmlTableStyles(AppColors c) {
  final border = Border.all(color: c.border, width: 0.5);
  return {
    'table': Style(
      margin: Margins.symmetric(vertical: 8),
      border: Border.all(color: c.border, width: 0.5),
      backgroundColor: Colors.transparent,
    ),
    'th': Style(
      padding: HtmlPaddings.all(8),
      border: border,
      backgroundColor: c.surfaceVariant,
      fontWeight: FontWeight.w600,
      verticalAlign: VerticalAlign.top,
    ),
    'td': Style(
      padding: HtmlPaddings.all(8),
      border: border,
      verticalAlign: VerticalAlign.top,
    ),
    'tr': Style(color: c.textPrimary),
    '.tui-table-wrapper': Style(margin: Margins.zero, padding: HtmlPaddings.zero),
  };
}
