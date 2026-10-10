import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

class WasteApiException implements Exception {
  const WasteApiException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}

class WasteApi {
  WasteApi({http.Client? client}) : _client = client ?? http.Client();

  static const _chatTimeout = Duration(seconds: 100);
  static const _shortTimeout = Duration(seconds: 15);

  final http.Client _client;

  static Uri validateBaseUrl(String input) {
    final value = input.trim();
    final uri = Uri.tryParse(value);
    if (uri == null || uri.host.isEmpty || uri.userInfo.isNotEmpty) {
      throw const WasteApiException('Enter a valid companion URL.');
    }
    final loopback = uri.host == '127.0.0.1' ||
        uri.host == 'localhost' ||
        uri.host == '::1';
    if (!loopback && uri.scheme != 'https') {
      throw const WasteApiException(
        'Non-loopback companion URLs must use HTTPS.',
      );
    }
    if (uri.scheme != 'http' && uri.scheme != 'https') {
      throw const WasteApiException('Companion URL must use HTTP or HTTPS.');
    }
    if (uri.hasQuery || uri.hasFragment || (uri.path.isNotEmpty && uri.path != '/')) {
      throw const WasteApiException(
        'Use the companion origin only; paths, queries, and fragments are not allowed.',
      );
    }
    return uri.replace(path: '');
  }

  Future<Map<String, dynamic>> health(String baseUrl) async {
    final response = await _request(
      'GET',
      baseUrl,
      '/api/health',
      null,
      null,
      timeout: _shortTimeout,
    );
    return response;
  }

  Future<Map<String, dynamic>> chat({
    required String baseUrl,
    required String token,
    required String message,
    required String mode,
    required List<Map<String, String>> history,
  }) =>
      _request('POST', baseUrl, '/api/chat', token, {
        'message': message,
        'mode': mode,
        'history': history,
      }, timeout: _chatTimeout);

  Future<Map<String, dynamic>> prepareAction({
    required String baseUrl,
    required String token,
    required String action,
  }) =>
      _request(
        'POST',
        baseUrl,
        '/api/actions/prepare',
        token,
        {'action': action},
        timeout: _shortTimeout,
      );

  Future<Map<String, dynamic>> confirmAction({
    required String baseUrl,
    required String token,
    required String confirmationId,
  }) =>
      _request(
        'POST',
        baseUrl,
        '/api/actions/confirm',
        token,
        {'confirmation_id': confirmationId},
        timeout: _shortTimeout,
      );

  Future<Map<String, dynamic>> _request(
    String method,
    String baseUrl,
    String route,
    String? token,
    Map<String, dynamic>? body,
    {
      required Duration timeout,
    }
  ) async {
    final base = validateBaseUrl(baseUrl);
    final uri = base.replace(path: route);
    final headers = <String, String>{'Accept': 'application/json'};
    if (body != null) headers['Content-Type'] = 'application/json';
    if (token != null && token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    }
    try {
      final response = method == 'GET'
          ? await _client.get(uri, headers: headers).timeout(timeout)
          : await _client
              .post(uri, headers: headers, body: jsonEncode(body))
              .timeout(timeout);
      Map<String, dynamic> data;
      try {
        data = jsonDecode(response.body) as Map<String, dynamic>;
      } catch (_) {
        throw const WasteApiException('The companion returned an unreadable response.');
      }
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw WasteApiException(
          data['error'] as String? ?? 'Companion request failed (${response.statusCode}).',
          statusCode: response.statusCode,
        );
      }
      return data;
    } on TimeoutException {
      throw const WasteApiException(
        'The companion took too long to respond. Check that it is running.',
      );
    } on WasteApiException {
      rethrow;
    } catch (_) {
      throw const WasteApiException(
        'Could not reach the companion. Check the host, pairing token, and connection.',
      );
    }
  }
}
