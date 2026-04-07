import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../models/chat_models.dart';

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

  Future<String> getResponse(
    String prompt,
    List<ChatMessageModel> history,
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
      return "Error: Please login first.";
    }

    final endpoint = requestUrl?.isNotEmpty == true ? requestUrl! : _defaultUrl;

    final List<dynamic> contents = [];
    for (var msg in history) {
      contents.add([
        [
          [null, msg.body],
        ],
        msg.isAssistant ? "model" : "user",
      ]);
    }
    contents.add([
      [
        [null, prompt],
      ],
      "user",
    ]);

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

    if (!_hasSessionTemplateSlot(payload)) {
      return 'Error: Gemini request template is incomplete. Re-login, send one short prompt inside AI Studio, and wait for the login screen to close on its own.';
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
          return parsedText;
        }
        return 'Google response parsed, but no assistant text was found.';
      }
      if (response.statusCode == 401) {
        return 'Google error: 401. Re-login and send one short prompt inside AI Studio before returning here so the app can capture the full request headers.';
      }
      return "Google error: ${response.statusCode}";
    } catch (e) {
      await _storage.write(key: 'gemini_last_response_status', value: 'error');
      await _storage.write(
        key: 'gemini_last_response_body',
        value: e.toString(),
      );
      return "Connection failed: $e";
    }
  }
}
