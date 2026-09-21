import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/alert.dart';

const String kBackendBaseUrl = 'http://10.0.2.2:8000';

class ApiService {
  String? _token;

  Future<void> _loadToken() async {
    if (_token != null && _token!.isNotEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString('access_token');
  }

  Future<Map<String, String>> _authHeaders() async {
    await _loadToken();

    if (_token == null || _token!.isEmpty) {
      throw Exception('Not logged in');
    }

    return {
      'Authorization': 'Bearer $_token',
      'Content-Type': 'application/json',
    };
  }

  Future<bool> login(String username, String password) async {
    try {
      final response = await http
          .post(
        Uri.parse('$kBackendBaseUrl/api/auth/login'),
        headers: {
          'Content-Type': 'application/x-www-form-urlencoded',
        },
        body: {
          'username': username,
          'password': password,
        },
      )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final token = data['access_token'];

        if (token == null || token.toString().isEmpty) {
          return false;
        }

        _token = token.toString();

        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('access_token', _token!);

        return true;
      }

      print('Login failed: ${response.statusCode} ${response.body}');
      return false;
    } catch (e) {
      print('Login error: $e');
      return false;
    }
  }

  Future<void> logout() async {
    _token = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('access_token');
  }

  Future<bool> isLoggedIn() async {
    await _loadToken();
    return _token != null && _token!.isNotEmpty;
  }

  Future<bool> isModelLoaded() async {
    try {
      final response = await http
          .get(
        Uri.parse('$kBackendBaseUrl/api/health'),
      )
          .timeout(const Duration(seconds: 5));

      if (response.statusCode != 200) {
        return false;
      }

      final data = jsonDecode(response.body);
      return data['ml_model_loaded'] == true;
    } catch (e) {
      print('Health check error: $e');
      return false;
    }
  }

  Future<Map<String, dynamic>> fetchHealth() async {
    final response = await http
        .get(
      Uri.parse('$kBackendBaseUrl/api/health'),
    )
        .timeout(const Duration(seconds: 5));

    if (response.statusCode != 200) {
      throw Exception(
        'Health check failed (${response.statusCode})',
      );
    }

    return Map<String, dynamic>.from(
      jsonDecode(response.body),
    );
  }

  Future<List<IdsAlert>> fetchAlerts({
    int limit = 100,
    String? severity,
  }) async {
    final headers = await _authHeaders();

    final uri =
    Uri.parse('$kBackendBaseUrl/api/alerts').replace(
      queryParameters: {
        'limit': '$limit',
        if (severity != null) 'severity': severity,
      },
    );

    final response = await http
        .get(uri, headers: headers)
        .timeout(const Duration(seconds: 10));

    if (response.statusCode == 401) {
      throw Exception('Authentication expired. Please login again.');
    }

    if (response.statusCode != 200) {
      throw Exception(
        'Failed to load alerts (${response.statusCode}): ${response.body}',
      );
    }

    final List data = jsonDecode(response.body);

    return data.map((e) => IdsAlert.fromJson(e)).toList();
  }

  Future<Map<String, dynamic>> fetchStats() async {
    final headers = await _authHeaders();

    final response = await http
        .get(
      Uri.parse('$kBackendBaseUrl/api/stats'),
      headers: headers,
    )
        .timeout(const Duration(seconds: 10));

    if (response.statusCode == 401) {
      throw Exception('Authentication expired. Please login again.');
    }

    if (response.statusCode != 200) {
      throw Exception(
        'Failed to load stats (${response.statusCode}): ${response.body}',
      );
    }

    return Map<String, dynamic>.from(
      jsonDecode(response.body),
    );
  }

  Future<void> startMonitoring({
    String mode = 'live',
    String? csvPath,
    double speed = 15,
  }) async {
    final headers = await _authHeaders();

    final uri =
    Uri.parse('$kBackendBaseUrl/api/monitor/start').replace(
      queryParameters: {
        'mode': mode,
        if (csvPath != null) 'csv_path': csvPath,
        'speed': '$speed',
      },
    );

    final response = await http
        .post(uri, headers: headers)
        .timeout(const Duration(seconds: 10));

    if (response.statusCode == 401) {
      throw Exception('Authentication expired. Please login again.');
    }

    if (response.statusCode != 200) {
      throw Exception(
        'Failed to start monitoring: ${response.body}',
      );
    }
  }

  Future<void> stopMonitoring() async {
    final headers = await _authHeaders();

    final response = await http
        .post(
      Uri.parse('$kBackendBaseUrl/api/monitor/stop'),
      headers: headers,
    )
        .timeout(const Duration(seconds: 10));

    if (response.statusCode == 401) {
      throw Exception('Authentication expired. Please login again.');
    }

    if (response.statusCode != 200) {
      throw Exception(
        'Failed to stop monitoring: ${response.body}',
      );
    }
  }
}