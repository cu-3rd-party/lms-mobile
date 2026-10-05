import 'dart:convert';
import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

import 'package:cumobile/core/theme/app_colors.dart';

class LongreadVideo extends StatefulWidget {
  final String? title;
  final String? description;
  final String url;
  final Color themeColor;

  const LongreadVideo({
    super.key,
    required this.title,
    required this.description,
    required this.url,
    required this.themeColor,
  });

  @override
  State<LongreadVideo> createState() => _LongreadVideoState();
}

class _LongreadVideoState extends State<LongreadVideo> {
  static const _origin = 'https://my.centraluniversity.ru/';

  bool _isStarted = false;
  bool _isPlayerLoading = true;
  String? _startedUrl;

  String _playerHtml(String url) {
    final src = const HtmlEscape(HtmlEscapeMode.attribute).convert(url);
    return '''<!DOCTYPE html>
<html>
<head>
<meta name="viewport" content="width=device-width, initial-scale=1, maximum-scale=1">
<style>html,body{margin:0;padding:0;height:100%;background:#000;overflow:hidden}iframe{border:0;width:100%;height:100%;display:block}</style>
</head>
<body>
<iframe src="$src" allow="autoplay; fullscreen; picture-in-picture; encrypted-media" allowfullscreen></iframe>
</body>
</html>''';
  }

  void _start() {
    setState(() {
      _isStarted = true;
      _isPlayerLoading = true;
      _startedUrl = widget.url;
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final title = widget.title?.trim() ?? '';
    final description = widget.description?.trim() ?? '';
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: AspectRatio(
              aspectRatio: 16 / 9,
              child: _isStarted ? _buildPlayer(c) : _buildPoster(c),
            ),
          ),
          if (title.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              title,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: c.textPrimary,
              ),
            ),
          ],
          if (description.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              description,
              style: TextStyle(fontSize: 13, color: c.textSecondary),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPoster(AppColors c) {
    final isIos = Platform.isIOS;
    return GestureDetector(
      onTap: _start,
      child: Container(
        color: c.surface,
        child: Center(
          child: Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: widget.themeColor,
              shape: BoxShape.circle,
            ),
            child: Icon(
              isIos ? CupertinoIcons.play_fill : Icons.play_arrow_rounded,
              color: c.onAccent,
              size: 32,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPlayer(AppColors c) {
    final isIos = Platform.isIOS;
    return Stack(
      fit: StackFit.expand,
      children: [
        const ColoredBox(color: Colors.black),
        InAppWebView(
          key: ValueKey(_startedUrl),
          initialData: InAppWebViewInitialData(
            data: _playerHtml(_startedUrl!),
            baseUrl: WebUri(_origin),
          ),
          initialSettings: InAppWebViewSettings(
            javaScriptEnabled: true,
            mediaPlaybackRequiresUserGesture: false,
            allowsInlineMediaPlayback: true,
            allowsPictureInPictureMediaPlayback: true,
            iframeAllowFullscreen: true,
            isElementFullscreenEnabled: true,
            transparentBackground: true,
            disableContextMenu: true,
            supportZoom: false,
            useShouldOverrideUrlLoading: false,
          ),
          onLoadStop: (_, _) {
            if (mounted) setState(() => _isPlayerLoading = false);
          },
          onReceivedError: (_, _, _) {
            if (mounted) setState(() => _isPlayerLoading = false);
          },
        ),
        if (_isPlayerLoading)
          IgnorePointer(
            child: Center(
              child: isIos
                  ? const CupertinoActivityIndicator(color: Colors.white)
                  : const CircularProgressIndicator(color: Colors.white),
            ),
          ),
      ],
    );
  }
}
