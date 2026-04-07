import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../models/chat_models.dart';

class GeminiClient {
  final _storage = const FlutterSecureStorage();
  final String _url = 'https://alkalimakersuite-pa.clients6.google.com/\$rpc/google.internal.alkali.applications.makersuite.v1.MakerSuiteService/GenerateContent';

  Future<String> getResponse(String prompt, List<ChatMessageModel> history) async {
    // 1. Pull the stolen keys from phone storage
    final cookies = await _storage.read(key: 'gemini_cookies');
    final auth = await _storage.read(key: 'gemini_auth');
    final visitId = await _storage.read(key: 'gemini_visit_id') ?? "v1_${DateTime.now().millisecondsSinceEpoch}";

    if (cookies == null || auth == null) return "Error: Please login first.";

    // 2. Build the history list for Google
    final List<dynamic> contents = [];
    for (var msg in history) {
      contents.add([[[null, msg.body]], msg.isAssistant ? "model" : "user"]);
    }
    contents.add([[[null, prompt]], "user"]);

    // 3. The exact data package Google expects
    final List<dynamic> payload = [
      "models/gemini-1.5-flash", 
      contents,
      [[null, null, 7, 5], [null, null, 8, 5], [null, null, 9, 5], [null, null, 10, 5]],
      [null, null, null, 65536, 1, 0.95, 64, null, null, null, null, null, null, 1, null, null, [1, null, null, 3]],
      null, // Session token (null usually works for fresh sessions)
      null, null, null, null, null, 1
    ];

    try {
      final response = await http.post(
        Uri.parse(_url),
        headers: {
          'content-type': 'application/json+protobuf',
          'cookie': cookies,
          'authorization': auth,
          'x-goog-api-key': 'AIzaSyDdP816MREB3SkjZO04QXbjsigfcI0GWOs', // Standard public key
          'x-user-agent': 'grpc-web-javascript/0.1',
          'x-aistudio-visit-id': visitId,
        },
        body: jsonEncode(payload),
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        // Path to the text in Google's weird response array
        return data[1][0][0][0].toString();
      }
      return "Google error: ${response.statusCode}";
    } catch (e) {
      return "Connection failed: $e";
    }
  }
}