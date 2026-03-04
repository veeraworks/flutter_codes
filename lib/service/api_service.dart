import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiService {
  // 🔥 Change this once when moving to production
  static const String baseUrl =
      "https://null-sheldon-unstudded.ngrok-free.dev";

  static Map<String, String> get headers => {
    "Content-Type": "application/json",
    "x-api-key": "smartbus_2026_secure",
    "ngrok-skip-browser-warning": "true",
  };

  static Future<http.Response> post(
      String endpoint, Map<String, dynamic> body) {
    return http.post(
      Uri.parse("$baseUrl$endpoint"),
      headers: headers,
      body: jsonEncode(body),
    );
  }

  // ✅ GET Helper (GENERIC — DO NOT CHANGE)
  static Future<http.Response> get(String endpoint) {
    return http.get(
      Uri.parse("$baseUrl$endpoint"),
      headers: headers,
    );
  }

  // ============================================================
  // ✅ DRIVER ETA API (NEW)
  // ============================================================
  static Future<Map<String, dynamic>?> getDriverEta({
    required String busId,
    required double originLat,
    required double originLng,
    required double destLat,
    required double destLng,
    required String nextStop,
  }) async {

    final uri = Uri.parse("$baseUrl/drivers/eta").replace(
      queryParameters: {
        "originLat": originLat.toString(),
        "originLng": originLng.toString(),
        "destLat": destLat.toString(),
        "destLng": destLng.toString(),
        "busId": busId,
        "nextStop": nextStop,
      },
    );

    print("📡 ETA URL: $uri");

    final response = await http.get(
      uri,
      headers: headers,
    );

    print("📡 ETA Status: ${response.statusCode}");

    if (response.statusCode != 200) {
      print("❌ ETA Failed: ${response.body}");
      return null;
    }

    return jsonDecode(response.body);
  }
}