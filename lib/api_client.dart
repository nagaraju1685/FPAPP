import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'loan.dart';

class ApiException implements Exception {
  final String message;
  ApiException(this.message);

  @override
  String toString() => message;
}

/// Thrown when the server returns 423 Locked: the account has a forced
/// password reset pending and every non-auth endpoint is blocked until
/// POST /api/change-password succeeds.
class AccountLockedException implements Exception {
  final String message;
  AccountLockedException([this.message = 'A password reset is required.']);

  @override
  String toString() => message;
}

class ApiClient {
  ApiClient._();

  static const String baseUrl = 'https://finapp.movetosmart.com';

  static const _secureStorage = FlutterSecureStorage();
  static const String _accessTokenKey = 'access_token';
  static const String _refreshTokenKey = 'refresh_token';
  static const String _usernamePrefsKey = 'session_username';

  static String? _accessToken;
  static String? _refreshToken;
  static String? _username;

  static String? get username => _username;

  /// Called when a refresh attempt fails and the session must be dropped.
  /// The app should route back to the login screen.
  static Future<void> Function()? onSessionExpired;

  /// Called when the server reports the account is locked pending a forced
  /// password reset. The app should route to a "set new password" screen
  /// and block everything else until it succeeds.
  static Future<void> Function()? onAccountLocked;

  static Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        if (_accessToken case final token?) 'Authorization': 'Bearer $token',
      };

  /// Loads a previously persisted session, if any. Returns the username
  /// to auto-sign-in as, or null if there is no stored session.
  static Future<String?> restoreSession() async {
    _accessToken = await _secureStorage.read(key: _accessTokenKey);
    _refreshToken = await _secureStorage.read(key: _refreshTokenKey);
    final prefs = await SharedPreferences.getInstance();
    _username = prefs.getString(_usernamePrefsKey);
    if (_accessToken == null || _refreshToken == null || _username == null) return null;
    return _username;
  }

  static Future<void> _persistSession() async {
    if (_accessToken != null && _refreshToken != null) {
      await _secureStorage.write(key: _accessTokenKey, value: _accessToken);
      await _secureStorage.write(key: _refreshTokenKey, value: _refreshToken);
    }
    if (_username != null) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_usernamePrefsKey, _username!);
    }
  }

  static Future<void> _clearSession() async {
    _accessToken = null;
    _refreshToken = null;
    _username = null;
    await _secureStorage.delete(key: _accessTokenKey);
    await _secureStorage.delete(key: _refreshTokenKey);
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_usernamePrefsKey);
  }

  static Future<void> logout() async {
    await _clearSession();
  }

  static Future<void> changePassword({
    required String oldPassword,
    required String newPassword,
  }) async {
    final response = await _authenticatedRequest(
      'POST',
      '/api/change-password',
      body: {'oldPassword': oldPassword, 'newPassword': newPassword},
      handleLocked: false,
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(
        _extractErrorMessage(response.body) ?? 'Failed to change password (${response.statusCode})',
      );
    }
  }

  /// Sets a new password while the account is locked pending a forced
  /// reset. Only valid mid-423-flow; does not require the old password.
  static Future<void> resetPassword({required String newPassword}) async {
    final response = await _authenticatedRequest(
      'POST',
      '/api/reset-password',
      body: {'newPassword': newPassword},
      handleLocked: false,
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(
        _extractErrorMessage(response.body) ?? 'Failed to reset password (${response.statusCode})',
      );
    }
  }

  static Future<void> signup({
    required String username,
    required String password,
    required List<String> currencies,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/api/auth/signup'),
      headers: _headers,
      body: jsonEncode({
        'username': username,
        'password': password,
        'currencies': currencies,
      }),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(
        _extractErrorMessage(response.body) ?? 'Signup failed (${response.statusCode})',
      );
    }
    // Signup does not log the user in; call login() next.
  }

  /// Returns true if the account has a forced password reset pending.
  static Future<bool> login({
    required String username,
    required String password,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/api/auth/login'),
      headers: _headers,
      body: jsonEncode({'username': username, 'password': password}),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(
        _extractErrorMessage(response.body) ?? 'Login failed (${response.statusCode})',
      );
    }

    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    _accessToken = decoded['accessToken'] as String;
    _refreshToken = decoded['refreshToken'] as String;
    _username = username;
    await _persistSession();
    return decoded['resetRequired'] as bool? ?? false;
  }

  static Future<bool> _refreshTokens() async {
    final refreshToken = _refreshToken;
    if (refreshToken == null) return false;

    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/auth/refresh'),
        headers: const {'Content-Type': 'application/json'},
        body: jsonEncode({'refreshToken': refreshToken}),
      );
      if (response.statusCode < 200 || response.statusCode >= 300) return false;

      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      _accessToken = decoded['accessToken'] as String;
      _refreshToken = decoded['refreshToken'] as String;
      await _persistSession();
      return true;
    } catch (_) {
      return false;
    }
  }

  static Future<List<Loan>> getLoans() async {
    final response = await _authenticatedRequest('GET', '/api/loans');

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(
        _extractErrorMessage(response.body) ?? 'Failed to load loans (${response.statusCode})',
      );
    }

    final decoded = jsonDecode(response.body) as List;
    return decoded.map((e) => Loan.fromJson(e as Map<String, dynamic>)).toList();
  }

  static Future<void> saveLoans(List<Loan> loans) async {
    final response = await _authenticatedRequest(
      'PUT',
      '/api/loans',
      body: loans.map((l) => l.toJson()).toList(),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(
        _extractErrorMessage(response.body) ?? 'Failed to save loans (${response.statusCode})',
      );
    }
  }

  static Future<List<int>> getBackup() async {
    final response = await _authenticatedRequest('GET', '/api/backup');

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(
        _extractErrorMessage(response.body) ?? 'Failed to download backup (${response.statusCode})',
      );
    }
    return response.bodyBytes;
  }

  static Future<void> importLoans(List<Map<String, dynamic>> loans) async {
    final response = await _authenticatedRequest('POST', '/api/import', body: loans);

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(
        _extractErrorMessage(response.body) ?? 'Failed to import loans (${response.statusCode})',
      );
    }
  }

  static Future<Map<String, dynamic>> getMe() async {
    final response = await _authenticatedRequest('GET', '/api/me');

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(
        _extractErrorMessage(response.body) ?? 'Failed to load account (${response.statusCode})',
      );
    }
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  static Future<void> contact({
    required String name,
    required String email,
    required String message,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/api/contact'),
      headers: const {'Content-Type': 'application/json'},
      body: jsonEncode({'name': name, 'email': email, 'message': message}),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(
        _extractErrorMessage(response.body) ?? 'Failed to send message (${response.statusCode})',
      );
    }
  }

  /// Performs an authenticated request, transparently refreshing the access
  /// token once on a 401 and retrying. If the refresh also fails, the
  /// session is cleared and [onSessionExpired] is invoked. A 423 response
  /// (forced password reset pending) invokes [onAccountLocked] unless
  /// [handleLocked] is false (used by the endpoints exempt from the lock:
  /// change-password / reset-password).
  static Future<http.Response> _authenticatedRequest(
    String method,
    String path, {
    Object? body,
    bool handleLocked = true,
  }) async {
    var response = await _send(method, path, body: body);

    if (response.statusCode == 401) {
      final refreshed = await _refreshTokens();
      if (!refreshed) {
        await _clearSession();
        if (onSessionExpired != null) await onSessionExpired!();
        throw ApiException('Session expired. Please sign in again.');
      }
      response = await _send(method, path, body: body);
    }

    if (handleLocked && response.statusCode == 423) {
      if (onAccountLocked != null) await onAccountLocked!();
      throw AccountLockedException(
        _extractErrorMessage(response.body) ?? 'A password reset is required.',
      );
    }

    return response;
  }

  static Future<http.Response> _send(String method, String path, {Object? body}) {
    final uri = Uri.parse('$baseUrl$path');
    final encodedBody = body != null ? jsonEncode(body) : null;
    switch (method) {
      case 'GET':
        return http.get(uri, headers: _headers);
      case 'POST':
        return http.post(uri, headers: _headers, body: encodedBody);
      case 'PUT':
        return http.put(uri, headers: _headers, body: encodedBody);
      case 'DELETE':
        return http.delete(uri, headers: _headers);
      default:
        throw ArgumentError('Unsupported method: $method');
    }
  }

  static String? _extractErrorMessage(String body) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map && decoded['error'] is String) {
        return decoded['error'] as String;
      }
      if (decoded is Map && decoded['message'] is String) {
        return decoded['message'] as String;
      }
    } catch (_) {
      // Response body wasn't JSON; fall through to null.
    }
    return null;
  }
}
