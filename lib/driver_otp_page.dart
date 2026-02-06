import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'driver_home_page.dart';

class DriverOtpPage extends StatefulWidget {
  final String phoneNumber;

  const DriverOtpPage({super.key, required this.phoneNumber});

  @override
  State<DriverOtpPage> createState() => _DriverOtpPageState();
}

class _DriverOtpPageState extends State<DriverOtpPage> {
  final TextEditingController otpController = TextEditingController();
  bool isLoading = false;

  Future<void> submitOtp() async {
    if (otpController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please enter OTP")),
      );
      return;
    }

    setState(() => isLoading = true);

    // ⏳ TEMP: simulate OTP verification
    await Future.delayed(const Duration(seconds: 1));

    // ✅ SAVE SESSION DATA
    final prefs = await SharedPreferences.getInstance();

    // 🔴 TEMP VALUES (until backend is ready)
    const String driverName = "Driver One";
    const String busId = "BUS10"; // ⚠️ MUST MATCH FIREBASE NODE
    const String routeName = "Madambakkam";
    const String shift = "Morning";

    await prefs.setString("driverName", driverName);
    await prefs.setString("busId", busId);
    await prefs.setString("routeName", routeName);
    await prefs.setString("shift", shift);

    // 🔍 DEBUG (VERY IMPORTANT)
    debugPrint("✅ OTP VERIFIED");
    debugPrint("✅ SAVED driverName = $driverName");
    debugPrint("✅ SAVED busId = $busId");
    debugPrint("✅ SAVED routeName = $routeName");
    debugPrint("✅ SAVED shift = $shift");

    setState(() => isLoading = false);

    // ✅ NAVIGATE TO DRIVER HOME
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const DriverHomePage()),
    );
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
            padding: const EdgeInsets.fromLTRB(22, 28, 22, 28),
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
                // 🔒 ICON
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

                // 🔢 OTP FIELD
                TextField(
                  controller: otpController,
                  keyboardType: TextInputType.number,
                  maxLength: 6,
                  decoration: InputDecoration(
                    hintText: "Enter OTP",
                    counterText: "",
                    prefixIcon: const Icon(Icons.sms),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                  ),
                ),

                const SizedBox(height: 22),

                // ✅ SUBMIT BUTTON
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
