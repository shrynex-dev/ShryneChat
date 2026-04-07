import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:go_router/go_router.dart';

class GeminiLoginScreen extends StatefulWidget {
  const GeminiLoginScreen({super.key});

  @override
  State<GeminiLoginScreen> createState() => _GeminiLoginScreenState();
}

class _GeminiLoginScreenState extends State<GeminiLoginScreen> {
  static const _storage = FlutterSecureStorage();

  double _progress = 0;
  bool _capturedLogin = false;
  bool _cookiesCaptured = false;
  bool _authCaptured = false;
  String _status = 'Waiting for Google AI Studio to finish sign-in...';

  @override
  void initState() {
    super.initState();
    _resetStoredSession();
  }

  Future<void> _resetStoredSession() async {
    await _storage.delete(key: 'gemini_cookies');
    await _storage.delete(key: 'gemini_auth');
    await _storage.delete(key: 'gemini_visit_id');
    await _storage.delete(key: 'gemini_request_headers');
    await _storage.delete(key: 'gemini_request_url');
    await _storage.delete(key: 'gemini_request_body_template');
  }

  void _setStatus(String status) {
    if (!mounted) {
      return;
    }
    setState(() {
      _status = status;
    });
  }

  Map<String, String> _normalizeHeaders(Map<dynamic, dynamic>? headers) {
    if (headers == null) {
      return const {};
    }
    return {
      for (final entry in headers.entries)
        entry.key.toString().toLowerCase(): entry.value.toString(),
    };
  }

  bool _isGenerateContentRequest(String url) {
    return url.contains('MakerSuiteService/GenerateContent') ||
        url.contains('GenerateContent');
  }

  Future<void> _captureCookies(WebUri? url) async {
    if (url == null) {
      return;
    }

    final cookies = await CookieManager.instance().getCookies(url: url);
    final cookieString = cookies
        .where((cookie) => cookie.name.isNotEmpty)
        .map((cookie) => '${cookie.name}=${cookie.value}')
        .join('; ');

    if (cookieString.isEmpty) {
      return;
    }

    await _storage.write(key: 'gemini_cookies', value: cookieString);
    if (!_cookiesCaptured) {
      _cookiesCaptured = true;
      _setStatus(
        _authCaptured
            ? 'Cookies captured. Finishing login...'
            : 'Cookies captured. Waiting for Gemini auth headers...',
      );
    }
    await _finishLoginIfReady();
  }

  Future<void> _captureHeaders(Map<dynamic, dynamic>? headers) async {
    final normalizedHeaders = _normalizeHeaders(headers);
    final authHeader = normalizedHeaders['authorization'];
    final visitId = normalizedHeaders['x-aistudio-visit-id'];

    if (authHeader == null || authHeader.isEmpty) {
      return;
    }

    await _storage.write(key: 'gemini_auth', value: authHeader);
    if (visitId != null && visitId.isNotEmpty) {
      await _storage.write(key: 'gemini_visit_id', value: visitId);
    }
    await _storage.write(
      key: 'gemini_request_headers',
      value: jsonEncode(normalizedHeaders),
    );

    if (!_authCaptured) {
      _authCaptured = true;
      _setStatus(
        _cookiesCaptured
            ? 'Auth headers captured. Finishing login...'
            : 'Auth headers captured. Waiting for Gemini cookies...',
      );
    }
    await _finishLoginIfReady();
  }

  Future<void> _captureRequestBody(dynamic body) async {
    if (body == null) {
      return;
    }

    try {
      final encoded = body is String ? body : jsonEncode(body);
      if (encoded.isEmpty) {
        return;
      }
      await _storage.write(key: 'gemini_request_body_template', value: encoded);
    } catch (_) {
      // Keep login flow resilient if the intercepted body is not JSON-encodable.
    }
  }

  Future<void> _finishLoginIfReady() async {
    if (_capturedLogin || !_cookiesCaptured || !_authCaptured) {
      return;
    }

    _capturedLogin = true;
    _setStatus('Gemini login saved successfully.');

    if (!context.mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Gemini login saved successfully.')),
    );
    context.pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Login to Google AI Studio')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Sign in to Google AI Studio. If the screen does not finish automatically, send one short prompt inside AI Studio so the app can capture the same request headers it needs for chat.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 12),
                LinearProgressIndicator(
                  value: _progress == 1 ? null : _progress,
                ),
                const SizedBox(height: 12),
                Text(
                  _status,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: InAppWebView(
              initialSettings: InAppWebViewSettings(
                javaScriptEnabled: true,
                thirdPartyCookiesEnabled: true,
                sharedCookiesEnabled: true,
                useShouldInterceptRequest: true,
                useShouldInterceptAjaxRequest: true,
                useShouldInterceptFetchRequest: true,
              ),
              initialUrlRequest: URLRequest(
                url: WebUri('https://aistudio.google.com/'),
              ),
              onProgressChanged: (controller, progress) {
                if (!mounted) {
                  return;
                }
                setState(() {
                  _progress = progress / 100;
                });
              },
              onLoadStart: (controller, url) {
                if (url != null) {
                  _setStatus('Loading ${url.host}...');
                }
              },
              onLoadStop: (controller, url) async {
                if (url == null || _capturedLogin) {
                  return;
                }
                if (url.host.contains('aistudio.google.com')) {
                  await _captureCookies(url);
                  if (!_capturedLogin && url.toString().contains('/app/')) {
                    _setStatus(
                      _authCaptured
                          ? 'AI Studio loaded. Waiting for final cookies...'
                          : 'AI Studio loaded. Waiting for Gemini auth request...',
                    );
                  }
                }
              },
              onUpdateVisitedHistory: (controller, url, isReload) async {
                if (url != null && url.host.contains('aistudio.google.com')) {
                  await _captureCookies(url);
                }
              },
              shouldInterceptRequest: (controller, request) async {
                final url = request.url.toString();
                if (_isGenerateContentRequest(url)) {
                  await _storage.write(key: 'gemini_request_url', value: url);
                  await _captureHeaders(request.headers);
                }
                return null;
              },
              shouldInterceptAjaxRequest: (controller, ajaxRequest) async {
                final url = ajaxRequest.url.toString();
                if (_isGenerateContentRequest(url)) {
                  await _storage.write(key: 'gemini_request_url', value: url);
                  await _captureHeaders(ajaxRequest.headers?.getHeaders());
                  await _captureRequestBody(ajaxRequest.data);
                }
                return ajaxRequest;
              },
              shouldInterceptFetchRequest: (controller, fetchRequest) async {
                final url = fetchRequest.url.toString();
                if (_isGenerateContentRequest(url)) {
                  await _storage.write(key: 'gemini_request_url', value: url);
                  await _captureHeaders(fetchRequest.headers);
                  await _captureRequestBody(fetchRequest.body);
                }
                return fetchRequest;
              },
            ),
          ),
        ],
      ),
    );
  }
}
