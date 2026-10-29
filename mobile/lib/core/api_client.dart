import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app_language.dart';
import 'env.dart';
import 'supabase_providers.dart';

class ApiException implements Exception {
  const ApiException(this.statusCode, this.message);

  final int statusCode;
  final String message;

  @override
  String toString() => message;
}

/// Thin wrapper around the FastAPI backend — see docs/architecture.md for
/// why booking creation goes through here instead of direct Supabase calls.
class ApiClient {
  ApiClient(this._supabase, {required String Function() language}) : _language = language;

  final SupabaseClient _supabase;

  /// Sent as Accept-Language, so the backend's messages come back in it.
  final String Function() _language;

  Uri _uri(String path, [Map<String, String>? query]) {
    return Uri.parse('${Env.fastApiBaseUrl}$path').replace(queryParameters: query);
  }

  Map<String, String> get _headers {
    final token = _supabase.auth.currentSession?.accessToken;
    return {
      'Content-Type': 'application/json',
      'Accept-Language': _language(),
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  Future<dynamic> get(String path, {Map<String, String>? query}) async {
    final response = await http.get(_uri(path, query), headers: _headers);
    return _decode(response);
  }

  Future<dynamic> post(String path, {Map<String, dynamic>? body}) async {
    final response = await http.post(
      _uri(path),
      headers: _headers,
      body: body == null ? null : jsonEncode(body),
    );
    return _decode(response);
  }

  Future<dynamic> delete(String path) async {
    final response = await http.delete(_uri(path), headers: _headers);
    return _decode(response);
  }

  dynamic _decode(http.Response response) {
    if (response.statusCode >= 200 && response.statusCode < 300) {
      if (response.body.isEmpty) return null;
      return jsonDecode(response.body);
    }
    var message = response.body;
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map && decoded['detail'] != null) {
        message = decoded['detail'].toString();
      }
    } catch (_) {
      // Keep the raw body as the message.
    }
    throw ApiException(response.statusCode, message);
  }
}

final apiClientProvider = Provider<ApiClient>((ref) {
  return ApiClient(
    ref.watch(supabaseClientProvider),
    language: () => appLanguageCode(ref.read(appLanguageProvider)),
  );
});
