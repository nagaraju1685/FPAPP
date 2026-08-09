import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'loan.dart';

class ApiException implements Exception {
  final String message;
  ApiException(this.message);

  @override
  String toString() => message;
}

class ApiClient {
  ApiClient._();

  static const String baseUrl = 'https://fin.movetosmart.com';
  static const String _cookiePrefsKey = 'session_cookie';
  static const String _usernamePrefsKey = 'session_username';

  static String? _sessionCookie;
  static String? _username;

  static String? get sessionCookie => _sessionCookie;
  static String? get username => _username;

  static Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        if (_sessionCookie case final cookie?) 'Cookie': cookie,
      };

  /// Loads a previously persisted session, if any. Returns the username
  /// to auto-sign-in as, or null if there is no stored session.
  static Future<String?> restoreSession() async {
    final prefs = await SharedPreferences.getInstance();
    _sessionCookie = prefs.getString(_cookiePrefsKey);
    _username = prefs.getString(_usernamePrefsKey);
    if (_sessionCookie == null || _username == null) return null;
    return _username;
  }

  static Future<void> _persistSession() async {
    final prefs = await SharedPreferences.getInstance();
    if (_sessionCookie != null && _username != null) {
      await prefs.setString(_cookiePrefsKey, _sessionCookie!);
      await prefs.setString(_usernamePrefsKey, _username!);
    }
  }

  static Future<void> logout() async {
    try {
      await http.post(Uri.parse('$baseUrl/logout'), headers: _headers);
    } catch (_) {
      // Best-effort server-side invalidation; always clear local state below.
    }
    _sessionCookie = null;
    _username = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_cookiePrefsKey);
    await prefs.remove(_usernamePrefsKey);
  }

  static Future<void> changePassword({
    required String oldPassword,
    required String newPassword,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/api/change-password'),
      headers: _headers,
      body: jsonEncode({'oldPassword': oldPassword, 'newPassword': newPassword}),
    );
    _captureCookie(response);

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(
        _extractErrorMessage(response.body) ?? 'Failed to change password (${response.statusCode})',
      );
    }
  }

  static Future<void> signup({
    required String username,
    required String password,
    required List<String> currencies,
  }) async {
    await _authRequest('/signup', {
      'username': username,
      'password': password,
      'currencies': currencies,
    }, 'Signup failed');
    _username = username;
    await _persistSession();
  }

  static Future<void> login({
    required String username,
    required String password,
  }) async {
    await _authRequest('/login', {
      'username': username,
      'password': password,
    }, 'Login failed');
    _username = username;
    await _persistSession();
  }

  static Future<List<Loan>> getLoans() async {
    final response = await http.get(Uri.parse('$baseUrl/api/loans'), headers: _headers);
    _captureCookie(response);

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(
        _extractErrorMessage(response.body) ?? 'Failed to load loans (${response.statusCode})',
      );
    }

    final decoded = jsonDecode(response.body) as List;
    return decoded.map((e) => Loan.fromJson(e as Map<String, dynamic>)).toList();
  }

  static Future<void> saveLoans(List<Loan> loans) async {
    final response = await http.put(
      Uri.parse('$baseUrl/api/loans'),
      headers: _headers,
      body: jsonEncode(loans.map((l) => l.toJson()).toList()),
    );
    _captureCookie(response);

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(
        _extractErrorMessage(response.body) ?? 'Failed to save loans (${response.statusCode})',
      );
    }
  }

  static Future<void> _authRequest(
    String path,
    Map<String, dynamic> body,
    String defaultErrorMessage,
  ) async {
    final response = await http.post(
      Uri.parse('$baseUrl$path'),
      headers: _headers,
      body: jsonEncode(body),
    );
    _captureCookie(response);

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(
        _extractErrorMessage(response.body) ?? '$defaultErrorMessage (${response.statusCode})',
      );
    }
  }

  static void _captureCookie(http.Response response) {
    final setCookie = response.headers['set-cookie'];
    if (setCookie != null) {
      _sessionCookie = setCookie.split(';').first;
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
