import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../models/chat_models.dart';

class GeminiResponseResult {
  const GeminiResponseResult({
    required this.displayText,
    this.assistantTurnData,
    this.remoteState,
  });

  final String displayText;
  final String? assistantTurnData;
  final String? remoteState;
}

class GeminiClient {
  final _storage = const FlutterSecureStorage();
  final String _defaultUrl =
      'https://alkalimakersuite-pa.clients6.google.com/\$rpc/google.internal.alkali.applications.makersuite.v1.MakerSuiteService/GenerateContent';

  static const _blockedForwardHeaders = {
    'content-length',
    'host',
    'cookie',
    'authorization',
    'x-aistudio-visit-id',
  };

  Map<String, String> _decodeSavedHeaders(String? rawHeaders) {
    if (rawHeaders == null || rawHeaders.isEmpty) {
      return const {};
    }

    final decoded = jsonDecode(rawHeaders);
    if (decoded is! Map) {
      return const {};
    }

    return {
      for (final entry in decoded.entries)
        entry.key.toString().toLowerCase(): entry.value.toString(),
    };
  }

  List<dynamic>? _decodeSavedPayloadTemplate(String? rawPayload) {
    if (rawPayload == null || rawPayload.isEmpty) {
      return null;
    }

    final decoded = jsonDecode(rawPayload);
    return decoded is List<dynamic> ? decoded : null;
  }

  bool _hasSessionTemplateSlot(List<dynamic> payload) {
    return payload.length > 4 &&
        payload[4] is String &&
        (payload[4] as String).isNotEmpty;
  }

  bool _isRemoteState(String? value) {
    return value != null && value.startsWith('v1_') && value.isNotEmpty;
  }

  List<dynamic> _buildContents(List<ChatMessageModel> history) {
    final contents = <dynamic>[];
    for (final message in history) {
      if (message.role == MessageRole.user) {
        contents.add([
          [
            [null, message.body],
          ],
          'user',
        ]);
        continue;
      }

      if (message.role == MessageRole.assistant &&
          message.transportData != null) {
        final decoded = jsonDecode(message.transportData!);
        if (decoded is List<dynamic>) {
          contents.add(decoded);
          continue;
        }
      }

      if (message.role == MessageRole.assistant) {
        contents.add([
          [
            [null, message.body],
          ],
          'model',
        ]);
      }
    }
    return contents;
  }

  String? _extractHiddenBlob(List<dynamic> data) {
    String? hiddenBlob;

    void visit(dynamic node) {
      if (node is List) {
        if (node.length > 14 &&
            node.first == null &&
            node[1] is String &&
            node[14] is String &&
            (node[14] as String).isNotEmpty) {
          hiddenBlob = node[14] as String;
        }
        for (final item in node) {
          visit(item);
        }
      } else if (node is Map) {
        for (final value in node.values) {
          visit(value);
        }
      }
    }

    visit(data);
    return hiddenBlob;
  }

  String? _extractRemoteState(List<dynamic> data) {
    String? remoteState;

    void visit(dynamic node) {
      if (node is String && _isRemoteState(node)) {
        remoteState = node;
        return;
      }
      if (node is List) {
        for (final item in node) {
          visit(item);
        }
      } else if (node is Map) {
        for (final value in node.values) {
          visit(value);
        }
      }
    }

    visit(data);
    return remoteState;
  }

  String? _buildAssistantTurnData(List<dynamic> data) {
    final displayText = _extractAssistantText(data);
    if (displayText == null) {
      return null;
    }

    final hiddenBlob = _extractHiddenBlob(data);
    final parts = <dynamic>[
      [null, displayText],
    ];
    if (hiddenBlob != null) {
      parts.add([
        null,
        '',
        null,
        null,
        null,
        null,
        null,
        null,
        null,
        null,
        null,
        null,
        null,
        null,
        hiddenBlob,
      ]);
    }
    return jsonEncode([parts, 'model']);
  }

  void _applyRemoteState(List<dynamic> payload, String? remoteState) {
    final lastValue = payload.isNotEmpty ? payload.last : null;
    if (lastValue is String && _isRemoteState(lastValue)) {
      payload.removeLast();
    }
    if (_isRemoteState(remoteState)) {
      payload.add(remoteState);
    }
  }

  String? _extractAssistantText(List<dynamic> data) {
    if (data.isEmpty || data.first is! List) {
      return null;
    }

    final turns = data.first as List<dynamic>;
    final buffer = StringBuffer();

    for (final turn in turns) {
      if (turn is! List || turn.isEmpty) {
        continue;
      }

      final candidate = turn.first;
      if (candidate is! List || candidate.isEmpty) {
        continue;
      }

      final role = _readPath(candidate, const [0, 0, 1]);
      final text = _readPath(candidate, const [0, 0, 0, 0, 0, 1]);

      if (role == 'model' && text is String && text.isNotEmpty) {
        buffer.write(text);
      }
    }

    final parsed = buffer.toString().trim();
    return parsed.isEmpty ? null : parsed;
  }

  dynamic _readPath(dynamic value, List<int> path) {
    dynamic current = value;
    for (final index in path) {
      if (current is! List || index >= current.length) {
        return null;
      }
      current = current[index];
    }
    return current;
  }

  Future<GeminiResponseResult> getResponse(
    List<ChatMessageModel> history,
    String? remoteState,
  ) async {
    final cookies = await _storage.read(key: 'gemini_cookies');
    final auth = await _storage.read(key: 'gemini_auth');
    final visitId =
        await _storage.read(key: 'gemini_visit_id') ??
        "v1_${DateTime.now().millisecondsSinceEpoch}";
    final requestUrl = await _storage.read(key: 'gemini_request_url');
    final rawSavedHeaders = await _storage.read(key: 'gemini_request_headers');
    final rawPayloadTemplate = await _storage.read(
      key: 'gemini_request_body_template',
    );
    final savedHeaders = _decodeSavedHeaders(rawSavedHeaders);
    final payloadTemplate = _decodeSavedPayloadTemplate(rawPayloadTemplate);

    if (cookies == null || auth == null) {
      return const GeminiResponseResult(
        displayText: 'Error: Please login first.',
      );
    }

    final endpoint = requestUrl?.isNotEmpty == true ? requestUrl! : _defaultUrl;

    final contents = _buildContents(history);

    final List<dynamic> payload =
        payloadTemplate != null &&
            payloadTemplate.length >= 2 &&
            _hasSessionTemplateSlot(payloadTemplate)
        ? List<dynamic>.from(payloadTemplate)
        : <dynamic>[
            "models/gemini-3-flash-preview",
            contents,
            [
              [null, null, 7, 5],
              [null, null, 8, 5],
              [null, null, 9, 5],
              [null, null, 10, 5],
            ],
            [
              null,
              null,
              null,
              65536,
              1,
              0.95,
              64,
              null,
              null,
              null,
              null,
              null,
              null,
              1,
              null,
              null,
              [1, null, null, 3],
            ],
            null,
            null,
            null,
            null,
            null,
            null,
            1,
          ];

    payload[1] = contents;
    _applyRemoteState(payload, remoteState);

    if (!_hasSessionTemplateSlot(payload)) {
      return const GeminiResponseResult(
        displayText:
            'Error: Gemini request template is incomplete. Re-login, send one short prompt inside AI Studio, and wait for the login screen to close on its own.',
      );
    }

    try {
      await _storage.write(key: 'gemini_last_request_url', value: endpoint);
      await _storage.write(
        key: 'gemini_last_request_body',
        value: jsonEncode(payload),
      );

      final headers = <String, String>{
        for (final entry in savedHeaders.entries)
          if (!_blockedForwardHeaders.contains(entry.key))
            entry.key: entry.value,
        'content-type':
            savedHeaders['content-type'] ?? 'application/json+protobuf',
        'cookie': cookies,
        'authorization': auth,
        'origin': savedHeaders['origin'] ?? 'https://aistudio.google.com',
        'referer': savedHeaders['referer'] ?? 'https://aistudio.google.com/',
        'x-aistudio-visit-id': visitId,
      };

      final savedApiKey = savedHeaders['x-goog-api-key'];
      if (savedApiKey != null && savedApiKey.isNotEmpty) {
        headers['x-goog-api-key'] = savedApiKey;
      } else {
        headers['x-goog-api-key'] = 'AIzaSyDdP816MREB3SkjZO04QXbjsigfcI0GWOs';
      }

      if (!headers.containsKey('x-user-agent')) {
        headers['x-user-agent'] = 'grpc-web-javascript/0.1';
      }

      final response = await http.post(
        Uri.parse(endpoint),
        headers: headers,
        body: jsonEncode(payload),
      );

      await _storage.write(
        key: 'gemini_last_response_status',
        value: response.statusCode.toString(),
      );
      await _storage.write(
        key: 'gemini_last_response_body',
        value: response.body,
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        final parsedText = _extractAssistantText(data);
        if (parsedText != null) {
          return GeminiResponseResult(
            displayText: parsedText,
            assistantTurnData: _buildAssistantTurnData(data),
            remoteState: _extractRemoteState(data),
          );
        }
        return GeminiResponseResult(
          displayText:
              'Google response parsed, but no assistant text was found.',
          remoteState: _extractRemoteState(data),
        );
      }
      if (response.statusCode == 401) {
        return const GeminiResponseResult(
          displayText:
              'Google error: 401. Re-login and send one short prompt inside AI Studio before returning here so the app can capture the full request headers.',
        );
      }
      return GeminiResponseResult(
        displayText: "Google error: ${response.statusCode}",
      );
    } catch (e) {
      await _storage.write(key: 'gemini_last_response_status', value: 'error');
      await _storage.write(
        key: 'gemini_last_response_body',
        value: e.toString(),
      );
      return GeminiResponseResult(displayText: "Connection failed: $e");
    }
  }
}
