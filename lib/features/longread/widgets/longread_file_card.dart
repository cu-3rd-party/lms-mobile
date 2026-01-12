import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class LongreadFileCard extends StatelessWidget {
  final String fileName;
  final String extension;
  final String formattedSize;
  final bool isDownloading;
  final double? progress;
  final String speed;
  final bool isDownloaded;
  final Color themeColor;
  final VoidCallback? onTap;

  const LongreadFileCard({
    super.key,
    required this.fileName,
    required this.extension,
    required this.formattedSize,
    required this.isDownloading,
    required this.progress,
    required this.speed,
    required this.isDownloaded,
    required this.themeColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isIos = Platform.isIOS;
    final content = Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: themeColor.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Center(
                child: Text(
                  extension.length > 4 ? extension.substring(0, 4) : extension,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: themeColor,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    fileName,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: Colors.white,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (formattedSize.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      formattedSize,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[500],
                      ),
                    ),
                  ],
                  if (isDownloading) ...[
                    const SizedBox(height: 8),
                    isIos
                        ? _CupertinoProgressBar(value: progress)
                        : LinearProgressIndicator(
                            value: progress,
                            minHeight: 4,
                            color: const Color(0xFF00E676),
                            backgroundColor: const Color(0xFF2A2A2A),
                          ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Text(
                          progress == null
                              ? 'Загрузка...'
                              : '${(progress! * 100).toStringAsFixed(0)}%',
                          style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                        ),
                        const Spacer(),
                        if (speed.isNotEmpty)
                          Text(
                            speed,
                            style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                          ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            isDownloading
                ? const SizedBox(width: 24, height: 24)
                : Icon(
                    isDownloaded
                        ? (isIos ? CupertinoIcons.check_mark_circled : Icons.check_circle)
                        : (isIos ? CupertinoIcons.arrow_down_circle : Icons.download),
                    color: isDownloaded ? const Color(0xFF00E676) : Colors.grey[500],
                    size: 24,
                  ),
          ],
        ),
      ),
    );

    return isIos
        ? GestureDetector(onTap: onTap, child: content)
        : InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(12),
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
          height: 4,
          decoration: BoxDecoration(
            color: const Color(0xFF2A2A2A),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Container(
              width: width * value!.clamp(0.0, 1.0),
              decoration: BoxDecoration(
                color: const Color(0xFF00E676),
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
        );
      },
    );
  }
}
