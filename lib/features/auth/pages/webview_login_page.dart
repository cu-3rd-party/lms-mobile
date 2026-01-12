import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:logging/logging.dart';

import 'package:cumobile/data/services/api_service.dart';

class WebViewLoginPage extends StatefulWidget {
  final VoidCallback onLogin;

  const WebViewLoginPage({super.key, required this.onLogin});

  @override
  State<WebViewLoginPage> createState() => _WebViewLoginPageState();
}

class _WebViewLoginPageState extends State<WebViewLoginPage> {
  static final Logger _log = Logger('WebViewLoginPage');

  final CookieManager _cookieManager = CookieManager.instance();
  InAppWebViewController? _webViewController;

  bool _isLoading = true;
  double _progress = 0;
  String? _error;

  static const String _authUrl = 'https://my.centraluniversity.ru';
  static const String _targetCookieName = 'bff.cookie';

  static const List<String> _callbackPatterns = [
    '/api/account/signin/callback',
  ];

  @override
  void initState() {
    super.initState();
    _clearCookies();
  }

  Future<void> _clearCookies() async {
    await _cookieManager.deleteAllCookies();
    _log.info('Cleared all cookies before login');
  }

  Future<void> _checkForAuthCookie(WebUri? url) async {
    if (url == null || !mounted) return;

    try {
      final cookies = await _cookieManager.getCookies(url: url);
      for (final cookie in cookies) {
        final preview = cookie.value != null
            ? '${cookie.value!.substring(0, cookie.value!.length.clamp(0, 20))}...'
            : 'null';
        _log.fine('Cookie found: ${cookie.name} = $preview');

        if (cookie.name == _targetCookieName && cookie.value != null) {
          _log.info('Found $_targetCookieName cookie!');
          await _handleSuccessfulAuth(cookie.value!);
          return;
        }
      }

      final domainCookies = await _cookieManager.getCookies(
        url: WebUri('https://my.centraluniversity.ru'),
      );
      for (final cookie in domainCookies) {
        if (cookie.name == _targetCookieName && cookie.value != null) {
          _log.info('Found $_targetCookieName cookie from domain!');
          await _handleSuccessfulAuth(cookie.value!);
          return;
        }
      }
    } catch (e, st) {
      _log.warning('Error checking cookies', e, st);
    }
  }

  Future<void> _handleSuccessfulAuth(String cookieValue) async {
    _log.info('Saving cookie and verifying...');

    await apiService.setCookie(cookieValue);
    final profile = await apiService.fetchProfile();

    if (profile != null) {
      _log.info('Auth successful for: ${profile.fullName}');
      if (mounted) {
        Navigator.of(context).pop();
        widget.onLogin();
      }
    } else {
      _log.warning('Cookie found but profile fetch failed');
      await apiService.clearCookie();
      if (mounted) {
        setState(() {
          _error = 'Не удалось подтвердить авторизацию. Попробуйте снова.';
        });
      }
    }
  }

  bool _isCallbackUrl(String url) {
    for (final pattern in _callbackPatterns) {
      if (url.contains(pattern)) {
        return true;
      }
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final isIos = Platform.isIOS;

    final appBar = isIos
        ? CupertinoNavigationBar(
            middle: const Text('Авторизация'),
            leading: CupertinoButton(
              padding: EdgeInsets.zero,
              onPressed: () => Navigator.of(context).pop(),
              child: const Icon(CupertinoIcons.back),
            ),
            trailing: CupertinoButton(
              padding: EdgeInsets.zero,
              onPressed: _refreshPage,
              child: const Icon(CupertinoIcons.refresh),
            ),
          )
        : AppBar(
            title: const Text('Авторизация'),
            actions: [
              IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: _refreshPage,
              ),
            ],
          );

    final body = Stack(
      children: [
        InAppWebView(
          initialUrlRequest: URLRequest(url: WebUri(_authUrl)),
          initialSettings: InAppWebViewSettings(
            useShouldOverrideUrlLoading: true,
            javaScriptEnabled: true,
            domStorageEnabled: true,
            databaseEnabled: true,
            clearCache: false,
            cacheEnabled: true,
            thirdPartyCookiesEnabled: true,
            sharedCookiesEnabled: true,
            userAgent: _getUserAgent(),
          ),
          onWebViewCreated: (controller) {
            _webViewController = controller;
          },
          onLoadStart: (controller, url) {
            _log.fine('Load start: $url');
            if (mounted) {
              setState(() {
                _isLoading = true;
                _error = null;
              });
            }
          },
          onLoadStop: (controller, url) async {
            _log.fine('Load stop: $url');
            if (mounted) {
              setState(() => _isLoading = false);
            }

            if (url != null) {
              await _checkForAuthCookie(url);
            }
          },
          onProgressChanged: (controller, progress) {
            if (mounted) {
              setState(() => _progress = progress / 100);
            }
          },
          onReceivedHttpError: (controller, request, response) async {
            _log.fine('HTTP ${response.statusCode}: ${request.url}');

            if (_isCallbackUrl(request.url.toString())) {
              _log.info('Callback URL detected, checking cookies...');
              await Future.delayed(const Duration(milliseconds: 500));
              await _checkForAuthCookie(request.url);
            }
          },
          shouldOverrideUrlLoading: (controller, action) async {
            final url = action.request.url?.toString() ?? '';
            _log.fine('Navigation: $url');

            if (_isCallbackUrl(url)) {
              _log.info('Intercepted callback URL');
              await Future.delayed(const Duration(milliseconds: 300));
              await _checkForAuthCookie(action.request.url);
            }

            return NavigationActionPolicy.ALLOW;
          },
          onReceivedServerTrustAuthRequest: (controller, challenge) async {
            return ServerTrustAuthResponse(
              action: ServerTrustAuthResponseAction.PROCEED,
            );
          },
        ),
        if (_isLoading)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: LinearProgressIndicator(
              value: _progress > 0 ? _progress : null,
              backgroundColor: Colors.grey[800],
              valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF00E676)),
            ),
          ),
        if (_error != null)
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              color: Colors.red.withValues(alpha: 0.9),
              padding: const EdgeInsets.all(16),
              child: Text(
                _error!,
                style: const TextStyle(color: Colors.white),
                textAlign: TextAlign.center,
              ),
            ),
          ),
      ],
    );

    if (isIos) {
      return CupertinoPageScaffold(
        navigationBar: appBar as ObstructingPreferredSizeWidget,
        child: SafeArea(child: body),
      );
    }

    return Scaffold(
      appBar: appBar as PreferredSizeWidget,
      body: body,
    );
  }

  void _refreshPage() {
    _webViewController?.reload();
  }

  String _getUserAgent() {
    if (Platform.isIOS) {
      return 'Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1';
    }
    return 'Mozilla/5.0 (Linux; Android 14) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36';
  }
}
