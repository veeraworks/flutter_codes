import 'dart:convert';
import 'package:flutter/material.dart';
import 'service/api_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'driver_home_page.dart';
import 'package:flutter/services.dart';

class DriverOtpPage extends StatefulWidget {
  final String phoneNumber;
  final String driverName;

  const DriverOtpPage({
    super.key,
    required this.phoneNumber,
    required this.driverName,
  });

  @override
  State<DriverOtpPage> createState() => _DriverOtpPageState();
}

class _DriverOtpPageState extends State<DriverOtpPage> {
  final TextEditingController otpController = TextEditingController();
  bool isLoading = false;

  Future<void> submitOtp() async {
    if (otpController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Enter OTP")),
      );
      return;
    }

    setState(() => isLoading = true);

    try {
      final response = await ApiService.post(
        "/drivers/check-driver",
          {
            "phone": widget.phoneNumber,
            "otp": otpController.text.trim(),
          }
      ).timeout(const Duration(seconds: 8));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        if (data["driver"] != null) {

          final driver = data["driver"];

          print("Driver Data → $driver"); // 🔍 Debug

          final prefs = await SharedPreferences.getInstance();

          // ✅ SAVE ALL REQUIRED VALUES
          await prefs.setString("driverName", driver["name"] ?? "");
          await prefs.setString("phone", widget.phoneNumber);
          await prefs.setString("licenseNo", driver["licenseNo"] ?? "");

          await prefs.setString("busId", driver["busId"] ?? "");
          await prefs.setString("permBusId", driver["busId"] ?? "");
          await prefs.setString("routeName", driver["busName"] ?? "");
          await prefs.setString("shift", driver["shift"] ?? "");

          await prefs.setBool("isLoggedIn", true);
          await prefs.setString("role", "driver");
          await prefs.setBool("isTempBusActive", false);

          if (!mounted) return;

          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => const DriverHomePage(),
            ),
          );

        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Driver not found")),
          );
        }
      }
      else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Server error ${response.statusCode}")),
        );
      }

    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Network error")),
      );
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }
  @override
  void dispose() {
    otpController.dispose();
    super.dispose();
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F3F7),
      appBar: AppBar(
        title: const Text("OTP Verification"),
        backgroundColor: const Color(0xFF00BFA6),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(22),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 18,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: const BoxDecoration(
                    color: Color(0xFFE0F7F3),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.lock,
                    size: 32,
                    color: Color(0xFF00BFA6),
                  ),
                ),

                const SizedBox(height: 20),

                const Text(
                  "ENTER OTP",
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1,
                    color: Color(0xFF00BFA6),
                  ),
                ),

                const SizedBox(height: 6),

                Text(
                  "OTP sent to ${widget.phoneNumber}",
                  style: const TextStyle(
                    fontSize: 13,
                    color: Colors.black54,
                  ),
                ),

                const SizedBox(height: 22),

                TextField(
                  controller: otpController,
                  keyboardType: TextInputType.number,
                  maxLength: 6,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(6),
                  ],
                  decoration: InputDecoration(
                    hintText: "Enter OTP",
                    counterText: "",
                    prefixIcon: const Icon(Icons.sms),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(18),
                      borderSide: const BorderSide(color: Color(0xFF00BFA6)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(18),
                      borderSide: const BorderSide(color: Color(0xFF00C9A7)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(18),
                      borderSide: const BorderSide(
                        color: Color(0xFF00BFA6),
                        width: 2,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 22),

                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: isLoading ? null : submitOtp,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF00BFA6),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                    ),
                    child: isLoading
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text(
                      "SUBMIT",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}