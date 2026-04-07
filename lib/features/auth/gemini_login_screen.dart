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
  double _progress = 0;
  bool _capturedLogin = false;

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
                  'Sign in to Google AI Studio, then wait for the app page to finish loading. The session will be saved automatically and this screen will close.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 12),
                LinearProgressIndicator(
                  value: _progress == 1 ? null : _progress,
                ),
              ],
            ),
          ),
          Expanded(
            child: InAppWebView(
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
              onLoadStop: (controller, url) async {
                if (url == null || _capturedLogin) {
                  return;
                }

                if (url.toString().contains('app/prompts')) {
                  const storage = FlutterSecureStorage();
                  final cookieManager = CookieManager.instance();
                  final cookies = await cookieManager.getCookies(url: url);
                  final cookieString = cookies
                      .map((cookie) => '${cookie.name}=${cookie.value}')
                      .join('; ');

                  if (cookieString.isNotEmpty) {
                    await storage.write(
                      key: 'gemini_cookies',
                      value: cookieString,
                    );
                  }

                  _capturedLogin = true;
                  if (!context.mounted) {
                    return;
                  }
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Gemini login saved successfully.'),
                    ),
                  );
                  context.pop();
                }
              },
              shouldInterceptRequest: (controller, request) async {
                final url = request.url.toString();

                if (url.contains('GenerateContent')) {
                  final authHeader = request.headers?['authorization'];
                  final visitId = request.headers?['x-aistudio-visit-id'];

                  if (authHeader != null && authHeader.isNotEmpty) {
                    const storage = FlutterSecureStorage();
                    await storage.write(key: 'gemini_auth', value: authHeader);
                    if (visitId != null && visitId.isNotEmpty) {
                      await storage.write(
                        key: 'gemini_visit_id',
                        value: visitId,
                      );
                    }
                  }
                }
                return null;
              },
            ),
          ),
        ],
      ),
    );
  }
}
