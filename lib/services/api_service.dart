import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../models/alert.dart';

/// Change this to your backend's address.
/// - Android emulator talking to a backend on your dev machine: 10.0.2.2
/// - iOS simulator / desktop / web: localhost
/// - Physical device: your machine's LAN IP, e.g. 192.168.1.42
const String kBackendBaseUrl = 'http://10.255.97.155:8003';

class ApiService {
  String? _token;

  Future<void> _loadToken() async {
    if (_token != null) return;
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString('access_token');
  }

  Future<bool> login(String username, String password) async {
    final response = await http.post(
      Uri.parse('$kBackendBaseUrl/api/auth/login'),
      headers: {'Content-Type': 'application/x-www-form-urlencoded'},
      body: {'username': username, 'password': password},
    );
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      _token = data['access_token'];
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('access_token', _token!);
      return true;
    }
    return false;
  }

  Future<void> logout() async {
    _token = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('access_token');
  }

  Future<Map<String, String>> _authHeaders() async {
    await _loadToken();
    return {'Authorization': 'Bearer $_token'};
  }

  Future<bool> isLoggedIn() async {
    await _loadToken();
    return _token != null;
  }

  Future<List<IdsAlert>> fetchAlerts(
      {int limit = 100, String? severity}) async {
    final headers = await _authHeaders();
    final uri =
        Uri.parse('$kBackendBaseUrl/api/alerts').replace(queryParameters: {
      'limit': '$limit',
      if (severity != null) 'severity': severity,
    });
    final response = await http.get(uri, headers: headers);
    if (response.statusCode != 200) {
      throw Exception('Failed to load alerts (${response.statusCode})');
    }
    final List data = jsonDecode(response.body);
    return data.map((e) => IdsAlert.fromJson(e)).toList();
  }

  Future<Map<String, dynamic>> fetchStats() async {
    final headers = await _authHeaders();
    final response = await http.get(Uri.parse('$kBackendBaseUrl/api/stats'),
        headers: headers);
    if (response.statusCode != 200) {
      throw Exception('Failed to load stats (${response.statusCode})');
    }
    return jsonDecode(response.body);
  }

  Future<void> startMonitoring(
      {String mode = 'live', String? csvPath, double speed = 15}) async {
    final headers = await _authHeaders();
    final uri = Uri.parse('$kBackendBaseUrl/api/monitor/start')
        .replace(queryParameters: {
      'mode': mode,
      if (csvPath != null) 'csv_path': csvPath,
      'speed': '$speed',
    });
    final response = await http.post(uri, headers: headers);
    if (response.statusCode != 200) {
      throw Exception('Failed to start monitoring: ${response.body}');
    }
  }

  Future<void> stopMonitoring() async {
    final headers = await _authHeaders();
    final response = await http
        .post(Uri.parse('$kBackendBaseUrl/api/monitor/stop'), headers: headers);
    if (response.statusCode != 200) {
      throw Exception('Failed to stop monitoring: ${response.body}');
    }
  }
}
