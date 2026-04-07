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

  String? _extractBestText(dynamic value) {
    final candidates = <String>[];

    void collect(dynamic node) {
      if (node is String) {
        final text = node.trim();
        if (text.isEmpty) {
          return;
        }
        if (text.length == 1 &&
            RegExp(r'^[a-z]$', caseSensitive: false).hasMatch(text)) {
          return;
        }
        if (text.startsWith('http://') || text.startsWith('https://')) {
          return;
        }
        if (text.startsWith('models/')) {
          return;
        }
        candidates.add(text);
        return;
      }

      if (node is List) {
        for (final item in node) {
          collect(item);
        }
        return;
      }

      if (node is Map) {
        for (final item in node.values) {
          collect(item);
        }
      }
    }

    collect(value);
    if (candidates.isEmpty) {
      return null;
    }

    candidates.sort((a, b) => b.length.compareTo(a.length));
    return candidates.first;
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
    final savedHeaders = _decodeSavedHeaders(rawSavedHeaders);

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

    // 3. The exact data package Google expects
    final List<dynamic> payload = [
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
      null, // Session token (null usually works for fresh sessions)
      null, null, null, null, null, 1,
    ];

    try {
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

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        final parsedText = _extractBestText(data);
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
      return "Connection failed: $e";
    }
  }
}
