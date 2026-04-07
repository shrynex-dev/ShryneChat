import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:go_router/go_router.dart';

class GeminiLoginScreen extends StatelessWidget {
  const GeminiLoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Login to Google AI Studio')),
      body: InAppWebView(
        initialUrlRequest: URLRequest(url: WebUri("https://aistudio.google.com/")),
        onLoadStop: (controller, url) async {
          // When page reaches the "app" section, we are likely logged in
          if (url.toString().contains("app/prompts")) {
            const storage = FlutterSecureStorage();
            
            // Extract and save cookies
            final cookieManager = CookieManager.instance();
            final cookies = await cookieManager.getCookies(url: url!);
            final cookieString = cookies.map((e) => "${e.name}=${e.value}").join("; ");
            await storage.write(key: 'gemini_cookies', value: cookieString);

            if (context.mounted) {
               ScaffoldMessenger.of(context).showSnackBar(
                 const SnackBar(content: Text('Login Successful! Tokens Captured.'))
               );
               context.pop();
            }
          }
        },
        // We use this to "sniff" the specific headers Google uses
        shouldInterceptRequest: (controller, request) async {
          final url = request.url.toString();
          
          // Look for the specific AI Studio background calls
          if (url.contains("GenerateContent")) {
            final authHeader = request.headers?['authorization'];
            final visitId = request.headers?['x-aistudio-visit-id'];
            
            if (authHeader != null) {
              const storage = FlutterSecureStorage();
              await storage.write(key: 'gemini_auth', value: authHeader);
              if (visitId != null) {
                await storage.write(key: 'gemini_visit_id', value: visitId);
              }
            }
          }
          return null;
        },
      ),
    );
  }
}