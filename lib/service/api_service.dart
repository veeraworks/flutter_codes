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
    String nextStop = "",
  }) async {
    final url =
        "$baseUrl/drivers/eta"
        "?busId=$busId"
        "&originLat=$originLat"
        "&originLng=$originLng"
        "&destLat=$destLat"
        "&destLng=$destLng"
        "&nextStop=$nextStop";

    final response = await http.get(
      Uri.parse(url),
      headers: headers,
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }

    print("❌ ETA API failed: ${response.statusCode}");
    return null;
  }
}