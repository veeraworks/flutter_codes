import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiService {
  // 🔥 Change this once when moving to production
  static const String baseUrl =
      "https://null-sheldon-unstudded.ngrok-free.dev";

  static Map<String, String> get headers => {
    "Content-Type": "application/json",
    "x-api-key": "smartbus_2026_secure",
  };

  // ✅ POST Helper
  static Future<http.Response> post(
      String endpoint, Map<String, dynamic> body) {
    return http.post(
      Uri.parse("$baseUrl$endpoint"),
      headers: headers,
      body: jsonEncode(body),
    );
  }

  // ✅ GET Helper
  static Future<http.Response> get(String endpoint) {
    return http.get(
      Uri.parse("$baseUrl$endpoint"),
      headers: headers,
    );
  }
}