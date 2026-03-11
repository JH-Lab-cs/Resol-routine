import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

class JsonApiResponse {
  const JsonApiResponse({
    required this.statusCode,
    required this.body,
    required this.rawBody,
  });

  final int statusCode;
  final Object? body;
  final String rawBody;

  Map<String, Object?> get bodyAsMap {
    if (body is Map<String, Object?>) {
      return body as Map<String, Object?>;
    }
    if (body is Map) {
      return Map<String, Object?>.from(body as Map);
    }
    return const <String, Object?>{};
  }
}

class JsonApiClient {
  JsonApiClient({required String baseUrl, required http.Client httpClient})
    : _baseUrl = baseUrl,
      _httpClient = httpClient;

  final String _baseUrl;
  final http.Client _httpClient;

  Future<JsonApiResponse> get(String path, {Map<String, String>? headers}) {
    return _send(method: 'GET', path: path, headers: headers);
  }

  Future<JsonApiResponse> post(
    String path, {
    Map<String, String>? headers,
    Object? body,
  }) {
    return _send(method: 'POST', path: path, headers: headers, body: body);
  }

  Future<JsonApiResponse> _send({
    required String method,
    required String path,
    Map<String, String>? headers,
    Object? body,
  }) async {
    final request = http.Request(method, _buildUri(path));
    request.headers.addAll(<String, String>{
      'Accept': 'application/json',
      if (body != null) 'Content-Type': 'application/json',
      ...?headers,
    });
    if (body != null) {
      request.body = jsonEncode(body);
    }

    final streamed = await _httpClient.send(request);
    final response = await http.Response.fromStream(streamed);
    final rawBody = response.body;
    final parsedBody = _parseBody(rawBody);
    return JsonApiResponse(
      statusCode: response.statusCode,
      body: parsedBody,
      rawBody: rawBody,
    );
  }

  Uri _buildUri(String path) {
    final normalizedPath = path.startsWith('/') ? path : '/$path';
    return Uri.parse('$_baseUrl$normalizedPath');
  }

  Object? _parseBody(String rawBody) {
    final trimmed = rawBody.trim();
    if (trimmed.isEmpty) {
      return null;
    }

    try {
      return jsonDecode(trimmed);
    } on FormatException {
      return null;
    }
  }
}
