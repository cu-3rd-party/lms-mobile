import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

enum AttachmentCardSize { regular, compact }

class AttachmentCard extends StatelessWidget {
  final String fileName;
  final String extension;
  final String? formattedSize;
  final bool isDownloading;
  final double? progress;
  final bool isDownloaded;
  final Color themeColor;
  final VoidCallback? onTap;
  final AttachmentCardSize size;

  const AttachmentCard({
    super.key,
    required this.fileName,
    required this.extension,
    this.formattedSize,
    required this.isDownloading,
    this.progress,
    required this.isDownloaded,
    required this.themeColor,
    this.onTap,
    this.size = AttachmentCardSize.regular,
  });

  @override
  Widget build(BuildContext context) {
    final isIos = Platform.isIOS;
    final isCompact = size == AttachmentCardSize.compact;
    final iconSize = isCompact ? 32.0 : 40.0;
    final borderRadius = isCompact ? 6.0 : 8.0;
    final padding = isCompact ? 10.0 : 12.0;
    final fontSize = isCompact ? 12.0 : 13.0;
    final iconFontSize = 10.0;
    final downloadIconSize = isCompact ? 18.0 : 20.0;
    final backgroundColor = isCompact ? const Color(0xFF2A2A2A) : const Color(0xFF1E1E1E);

    final content = Container(
      margin: EdgeInsets.only(bottom: isCompact ? 6 : 8),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(isCompact ? 8 : 12),
      ),
      child: Padding(
        padding: EdgeInsets.all(padding),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: iconSize,
              height: iconSize,
              decoration: BoxDecoration(
                color: themeColor.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(borderRadius),
              ),
              child: Center(
                child: Text(
                  extension.length > 4 ? extension.substring(0, 4) : extension,
                  style: TextStyle(
                    fontSize: iconFontSize,
                    fontWeight: FontWeight.bold,
                    color: themeColor,
                  ),
                ),
              ),
            ),
            SizedBox(width: isCompact ? 8 : 12),
            Expanded(
              child: Text(
                fileName,
                style: TextStyle(
                  fontSize: fontSize,
                  fontWeight: FontWeight.w500,
                  color: Colors.white,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (isDownloading) ...[
              const SizedBox(width: 8),
              SizedBox(
                width: 50,
                child: isIos
                    ? _CupertinoProgressBar(value: progress)
                    : LinearProgressIndicator(
                        value: progress,
                        minHeight: 3,
                        color: const Color(0xFF00E676),
                        backgroundColor: const Color(0xFF3A3A3A),
                      ),
              ),
            ] else if (formattedSize != null && formattedSize!.isNotEmpty) ...[
              const SizedBox(width: 8),
              Text(
                formattedSize!,
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey[500],
                ),
              ),
            ],
            const SizedBox(width: 8),
            Icon(
              isDownloaded
                  ? (isIos ? CupertinoIcons.check_mark_circled : Icons.check_circle)
                  : (isIos ? CupertinoIcons.arrow_down_circle : Icons.download),
              color: isDownloaded ? const Color(0xFF00E676) : Colors.grey[500],
              size: downloadIconSize,
            ),
          ],
        ),
      ),
    );

    return isIos
        ? GestureDetector(
            onTap: isDownloading ? null : onTap,
            child: content,
          )
        : InkWell(
            onTap: isDownloading ? null : onTap,
            borderRadius: BorderRadius.circular(isCompact ? 8 : 12),
            child: content,
          );
  }
}

class _CupertinoProgressBar extends StatelessWidget {
  final double? value;

  const _CupertinoProgressBar({this.value});

  @override
  Widget build(BuildContext context) {
    if (value == null) {
      return const CupertinoActivityIndicator(radius: 8);
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        return Container(
          height: 3,
          decoration: BoxDecoration(
            color: const Color(0xFF3A3A3A),
            borderRadius: BorderRadius.circular(3),
          ),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Container(
              width: width * value!.clamp(0.0, 1.0),
              decoration: BoxDecoration(
                color: const Color(0xFF00E676),
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ),
        );
      },
    );
  }
}
