import 'dart:collection';

import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../application/gemini_webview_session.dart';

class GeminiSessionWebView extends ConsumerWidget {
  const GeminiSessionWebView({
    super.key,
    this.visible = true,
    this.onProgress,
  });

  final bool visible;
  final ValueChanged<double>? onProgress;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(geminiWebViewSessionProvider);
    final sessionController = ref.read(geminiWebViewSessionProvider.notifier);
    final webView = InAppWebView(
      initialUserScripts: UnmodifiableListView([
        UserScript(
          source: geminiBridgeBootstrapScript,
          injectionTime: UserScriptInjectionTime.AT_DOCUMENT_START,
        ),
      ]),
      initialSettings: InAppWebViewSettings(
        javaScriptEnabled: true,
        thirdPartyCookiesEnabled: true,
        sharedCookiesEnabled: true,
      ),
      initialUrlRequest: URLRequest(
        url: WebUri(session.currentUrl ?? 'https://aistudio.google.com/'),
      ),
      onWebViewCreated: (controller) {
        sessionController.attachController(controller);
        controller.addJavaScriptHandler(
          handlerName: 'geminiSessionEvent',
          callback: (args) {
            sessionController.handleBridgeEvent(args);
            return null;
          },
        );
      },
      onProgressChanged: (controller, progress) {
        onProgress?.call(progress / 100);
      },
      onLoadStart: (controller, url) {
        sessionController.handleLoadStart(url);
      },
      onLoadStop: (controller, url) async {
        await sessionController.handleLoadStop(url);
      },
    );

    if (visible) {
      return webView;
    }

    return Offstage(
      offstage: true,
      child: SizedBox(
        width: 1,
        height: 1,
        child: IgnorePointer(child: webView),
      ),
    );
  }
}
