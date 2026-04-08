import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:async';

class GeminiWebViewSessionState {
  const GeminiWebViewSessionState({
    this.currentUrl,
    this.pageTitle,
    this.status = 'Open Gemini Session to connect AI Studio.',
    this.hasController = false,
    this.bridgeInstalled = false,
    this.appLoaded = false,
    this.hasPromptInput = false,
    this.hasSendButton = false,
    this.activeRequestId,
    this.lastResponsePreview,
  });

  final String? currentUrl;
  final String? pageTitle;
  final String status;
  final bool hasController;
  final bool bridgeInstalled;
  final bool appLoaded;
  final bool hasPromptInput;
  final bool hasSendButton;
  final String? activeRequestId;
  final String? lastResponsePreview;

  bool get appearsReady => hasController && bridgeInstalled && hasPromptInput;

  GeminiWebViewSessionState copyWith({
    String? currentUrl,
    String? pageTitle,
    String? status,
    bool? hasController,
    bool? bridgeInstalled,
    bool? appLoaded,
    bool? hasPromptInput,
    bool? hasSendButton,
    String? activeRequestId,
    String? lastResponsePreview,
  }) {
    return GeminiWebViewSessionState(
      currentUrl: currentUrl ?? this.currentUrl,
      pageTitle: pageTitle ?? this.pageTitle,
      status: status ?? this.status,
      hasController: hasController ?? this.hasController,
      bridgeInstalled: bridgeInstalled ?? this.bridgeInstalled,
      appLoaded: appLoaded ?? this.appLoaded,
      hasPromptInput: hasPromptInput ?? this.hasPromptInput,
      hasSendButton: hasSendButton ?? this.hasSendButton,
      activeRequestId: activeRequestId ?? this.activeRequestId,
      lastResponsePreview: lastResponsePreview ?? this.lastResponsePreview,
    );
  }
}

class GeminiWebViewSessionController
    extends Notifier<GeminiWebViewSessionState> {
  InAppWebViewController? _controller;
  final Map<String, Completer<String>> _pendingResponses = {};
  int _requestCounter = 0;

  @override
  GeminiWebViewSessionState build() => const GeminiWebViewSessionState();

  void attachController(InAppWebViewController controller) {
    _controller = controller;
    state = state.copyWith(
      hasController: true,
      status: 'Gemini session host attached. Sign in to AI Studio if needed.',
    );
  }

  void handleLoadStart(WebUri? url) {
    state = state.copyWith(
      currentUrl: url?.toString(),
      appLoaded: false,
      hasPromptInput: false,
      hasSendButton: false,
      status: 'Loading ${url?.host ?? 'AI Studio'}...',
    );
  }

  Future<void> handleLoadStop(WebUri? url) async {
    state = state.copyWith(
      currentUrl: url?.toString(),
      pageTitle: await _controller?.getTitle(),
      status: 'Page loaded. Waiting for the Gemini bridge to initialize...',
    );
  }

  void handleBridgeEvent(List<dynamic> args) {
    if (args.isEmpty || args.first is! Map) {
      return;
    }
    final event = Map<String, dynamic>.from(args.first as Map);
    final type = event['type']?.toString();

    if (type == 'bridge-installed') {
      state = state.copyWith(
        bridgeInstalled: true,
        currentUrl: event['href']?.toString() ?? state.currentUrl,
        status: 'Gemini bridge installed. Waiting for AI Studio app shell...',
      );
      return;
    }

    if (type == 'page-state') {
      final href = event['href']?.toString();
      final title = event['title']?.toString();
      final hasPromptInput = event['hasPromptInput'] == true;
      final hasSendButton = event['hasSendButton'] == true;
      final appLoaded = hasPromptInput || hasSendButton;

      state = state.copyWith(
        currentUrl: href ?? state.currentUrl,
        pageTitle: title ?? state.pageTitle,
        appLoaded: appLoaded,
        hasPromptInput: hasPromptInput,
        hasSendButton: hasSendButton,
        status: hasPromptInput
            ? 'AI Studio composer detected. Ready to send prompts.'
            : 'Gemini session attached. Waiting for the composer to appear...',
      );
      return;
    }

    if (type == 'prompt-sent') {
      state = state.copyWith(
        activeRequestId: event['requestId']?.toString(),
        status: 'Prompt injected. Waiting for Gemini response...',
      );
      return;
    }

    if (type == 'response-chunk') {
      final requestId = event['requestId']?.toString();
      final text = event['text']?.toString() ?? '';
      if (requestId == null || text.isEmpty) {
        return;
      }

      state = state.copyWith(
        activeRequestId: requestId,
        lastResponsePreview: text.length > 120 ? text.substring(0, 120) : text,
        status: 'Gemini response streaming...',
      );
      return;
    }

    if (type == 'response-done') {
      final requestId = event['requestId']?.toString();
      final text = event['text']?.toString() ?? '';
      if (requestId != null) {
        final completer = _pendingResponses.remove(requestId);
        if (completer != null && !completer.isCompleted) {
          completer.complete(text);
        }
      }
      state = state.copyWith(
        activeRequestId: null,
        lastResponsePreview: text.length > 120 ? text.substring(0, 120) : text,
        status: 'Gemini response received.',
      );
      return;
    }

    if (type == 'response-error') {
      final requestId = event['requestId']?.toString();
      final message = event['message']?.toString() ?? 'Unknown Gemini error';
      if (requestId != null) {
        final completer = _pendingResponses.remove(requestId);
        if (completer != null && !completer.isCompleted) {
          completer.completeError(StateError(message));
        }
      }
      state = state.copyWith(activeRequestId: null, status: message);
    }
  }

  Future<void> _waitForBridgeReady() async {
    const maxAttempts = 20;
    for (var attempt = 0; attempt < maxAttempts; attempt++) {
      if (state.bridgeInstalled && state.hasPromptInput) {
        return;
      }
      await Future<void>.delayed(const Duration(milliseconds: 250));
    }
  }

  Future<String> sendPrompt(String prompt) async {
    if (_controller == null) {
      throw StateError('Gemini WebView controller is not attached.');
    }
    if (!state.bridgeInstalled || !state.hasPromptInput) {
      await _waitForBridgeReady();
    }
    if (!state.bridgeInstalled) {
      throw StateError(
        'Gemini bridge is not installed yet. Open the Gemini session screen and wait for the bridge to attach.',
      );
    }

    final requestId =
        'req_${DateTime.now().microsecondsSinceEpoch}_${_requestCounter++}';
    final completer = Completer<String>();
    _pendingResponses[requestId] = completer;

    final result = await _controller!.callAsyncJavaScript(
      functionBody: '''
        if (!window.__shryneGeminiBridge || !window.__shryneGeminiBridge.sendPrompt) {
          throw new Error('Gemini bridge is not available in the page context.');
        }
        window.__shryneGeminiBridge.sendPrompt(prompt, requestId);
        return true;
      ''',
      arguments: <String, dynamic>{
        'prompt': prompt,
        'requestId': requestId,
      },
    );
    if (result?.error != null) {
      throw StateError(result!.error.toString());
    }

    state = state.copyWith(
      activeRequestId: requestId,
      status: 'Prompt injected into Gemini session.',
    );

    return completer.future.timeout(
      const Duration(minutes: 2),
      onTimeout: () {
        _pendingResponses.remove(requestId);
        throw TimeoutException('Timed out waiting for Gemini response.');
      },
    );
  }

  Future<void> reload() async {
    await _controller?.reload();
  }

  Future<void> openAiStudioHome() async {
    await _controller?.loadUrl(
      urlRequest: URLRequest(url: WebUri('https://aistudio.google.com/app')),
    );
  }
}

final geminiWebViewSessionProvider =
    NotifierProvider<GeminiWebViewSessionController, GeminiWebViewSessionState>(
      GeminiWebViewSessionController.new,
    );

const String geminiBridgeBootstrapScript = _bridgeBootstrapScript;

const _bridgeBootstrapScript = '''
(() => {
  if (window.__shryneGeminiBridgeInstalled) {
    return 'already-installed';
  }

  window.__shryneGeminiBridgeInstalled = true;

  const notify = (payload) => {
    if (!window.flutter_inappwebview || !window.flutter_inappwebview.callHandler) {
      return;
    }
    window.flutter_inappwebview.callHandler('geminiSessionEvent', payload);
  };

  const findPromptInput = () =>
    document.querySelector('textarea') ||
    document.querySelector('[contenteditable="true"]') ||
    document.querySelector('input[type="text"]');

  const findSendButton = () =>
    document.querySelector('button[aria-label*="Send"]') ||
    document.querySelector('button[aria-label*="send"]') ||
    document.querySelector('button[type="submit"]');

  const setPromptValue = (element, prompt) => {
    if (!element) {
      return false;
    }

    if (element.tagName === 'TEXTAREA' || element.tagName === 'INPUT') {
      const descriptor =
        Object.getOwnPropertyDescriptor(HTMLTextAreaElement.prototype, 'value') ||
        Object.getOwnPropertyDescriptor(HTMLInputElement.prototype, 'value');
      descriptor?.set?.call(element, prompt);
      element.dispatchEvent(new Event('input', { bubbles: true }));
      element.dispatchEvent(new Event('change', { bubbles: true }));
      return true;
    }

    if (element.isContentEditable) {
      element.textContent = prompt;
      element.dispatchEvent(
        new InputEvent('input', {
          bubbles: true,
          inputType: 'insertText',
          data: prompt,
        }),
      );
      return true;
    }

    return false;
  };

  const extractLikelyAssistantText = () => {
    const selectors = [
      '[data-message-author-role="assistant"]',
      '[data-role="assistant"]',
      '[data-testid*="assistant"]',
      '[aria-label*="assistant"]',
      'article',
      'main'
    ];

    const texts = [];
    for (const selector of selectors) {
      for (const node of document.querySelectorAll(selector)) {
        const text = (node.innerText || node.textContent || '').trim();
        if (text.length > 10) {
          texts.push(text);
        }
      }
    }

    texts.sort((a, b) => b.length - a.length);
    return texts[0] || '';
  };

  const streamAssistantText = (requestId) => {
    let lastText = '';
    let idleTicks = 0;

    const sample = () => {
      const text = extractLikelyAssistantText();
      if (text && text !== lastText) {
        lastText = text;
        idleTicks = 0;
        notify({
          type: 'response-chunk',
          requestId,
          text,
        });
      } else {
        idleTicks += 1;
      }

      if (idleTicks > 24) {
        notify({
          type: 'response-done',
          requestId,
          text: lastText,
        });
        return;
      }

      window.setTimeout(sample, 250);
    };

    sample();
  };

  const emitPageState = () => {
    notify({
      type: 'page-state',
      href: window.location.href,
      title: document.title,
      hasPromptInput: !!findPromptInput(),
      hasSendButton: !!findSendButton()
    });
  };

  window.__shryneGeminiBridge = {
    sendPrompt: (prompt, requestId) => {
      const input = findPromptInput();
      const sendButton = findSendButton();

      if (!input || !sendButton) {
        notify({
          type: 'response-error',
          requestId,
          message: 'Could not find prompt input or send button in the Gemini page.',
        });
        return;
      }

      if (!setPromptValue(input, prompt)) {
        notify({
          type: 'response-error',
          requestId,
          message: 'Could not set the prompt value in the Gemini page.',
        });
        return;
      }

      notify({
        type: 'prompt-sent',
        requestId,
        prompt,
      });

      sendButton.click();
      streamAssistantText(requestId);
    },
  };

  const observer = new MutationObserver(() => emitPageState());
  observer.observe(document.documentElement || document.body, {
    childList: true,
    subtree: true,
    attributes: true
  });

  notify({
    type: 'bridge-installed',
    href: window.location.href
  });
  emitPageState();
  return 'installed';
})();
''';
