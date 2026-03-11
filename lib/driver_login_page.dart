import 'dart:convert';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'service/api_service.dart';
import 'driver_otp_page.dart';
import 'utils/app_logger.dart';

class DriverLoginPage extends StatefulWidget {
  const DriverLoginPage({super.key});

  @override
  State<DriverLoginPage> createState() => _DriverLoginPageState();
}

class _DriverLoginPageState extends State<DriverLoginPage>
    with SingleTickerProviderStateMixin {

  final TextEditingController driverNameController = TextEditingController();
  final TextEditingController phoneController = TextEditingController();

  bool showError = false;
  bool isLoading = false;

  late AnimationController shakeController;

  @override
  void initState() {
    super.initState();

    shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
  }

  @override
  void dispose() {
    shakeController.dispose();
    driverNameController.dispose();
    phoneController.dispose();
    super.dispose();
  }

  // ================= LOGIN =================
  Future<void> driverLogin() async {
    final name = driverNameController.text.trim();
    final phone = phoneController.text.trim();

    if (name.isEmpty || phone.isEmpty) {
      setState(() => showError = true);
      return;
    }

    if (phone.length != 10) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Enter valid 10-digit phone number")),
      );
      return;
    }

    setState(() {
      showError = false;
      isLoading = true;
    });

    try {
      final response = await ApiService.post(
        "/drivers/check-driver",
        {
          "phone": phone,
        },
      ).timeout(const Duration(seconds: 8));

      Map<String, dynamic> data = {};

      try {
        data = jsonDecode(response.body);
      } catch (e) {
        appLog("JSON parse error: $e");
      }
      if (response.statusCode == 200 && data["driver"] != null) {

        final driver = data["driver"];

        final prefs = await SharedPreferences.getInstance();
        await prefs.setString("busId", driver["busId"] ?? "");
        await prefs.setString("permBusId", driver["busId"] ?? "");
        await prefs.setString(
          "busNumber",
          driver["busNumber"] ?? driver["busId"] ?? "",
        );
        await prefs.setString(
          "routeName",
          driver["busName"] ?? driver["routeName"] ?? driver["route"] ?? "",
        );
        await prefs.setString("shift", driver["shift"] ?? "");

        await prefs.setString("driverName", driver["name"] ?? "");
        await prefs.setString("licenseNo", driver["licenseNo"] ?? "");
        await prefs.setString("phone", phone);

        // Keep pre-OTP state separate; mark full session only after OTP success.
        await prefs.setString("pendingDriverPhone", phone);
        await prefs.setBool("isTempBusActive", false);


        if (!mounted) return;

        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => DriverOtpPage(
              phoneNumber: phone,
              driverName: driver["name"],
            ),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Driver not found")),
        );
      }

    } on TimeoutException {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Server timeout")),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Network error")),
      );
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  // ================= INPUT DECORATION =================
  InputDecoration inputDecoration({
    required String hint,
    required IconData icon,
  }) {
    return InputDecoration(
      hintText: hint,
      prefixIcon: Icon(icon, color: const Color(0xFF00C9A7)),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(color: Color(0xFF00C9A7)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(
          color: Color(0xFF00C9A7),
          width: 2,
        ),
      ),
    );
  }

  // ================= UI =================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [

          Positioned.fill(
            child: Image.asset(
              'assets/images/maps6.png',
              fit: BoxFit.cover,
            ),
          ),

          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.white.withOpacity(0.15),
                    Colors.white.withOpacity(0.85),
                    Colors.white,
                  ],
                ),
              ),
            ),
          ),

          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [

                  Container(
                    width: 110,
                    height: 110,
                    decoration: const BoxDecoration(
                      color: Color(0xFFE0F7F3),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.directions_bus_filled,
                      size: 60,
                      color: Color(0xFF00C9A7),
                    ),
                  ),

                  const SizedBox(height: 30),

                  Container(
                    padding: const EdgeInsets.fromLTRB(22, 28, 22, 28),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(22),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.02),
                          blurRadius: 18,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [

                        const Text(
                          "DRIVER LOGIN",
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF00C9A7),
                          ),
                        ),

                        const SizedBox(height: 22),

                        TextField(
                          controller: driverNameController,
                          decoration: inputDecoration(
                            hint: 'Driver Name',
                            icon: Icons.person,
                          ),
                        ),

                        const SizedBox(height: 18),

                        TextField(
                          controller: phoneController,
                          keyboardType: TextInputType.number,
                          maxLength: 10,
                          decoration: inputDecoration(
                            hint: 'Phone Number',
                            icon: Icons.phone,
                          ),
                        ),

                        if (showError) ...[
                          const SizedBox(height: 12),
                          const Text(
                            'Please fill all fields',
                            style: TextStyle(
                              color: Colors.red,
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],

                        const SizedBox(height: 26),

                        GestureDetector(
                          onTap: isLoading ? null : driverLogin,
                          child: Container(
                            width: double.infinity,
                            height: 56,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(30),
                              gradient: const LinearGradient(
                                colors: [
                                  Color(0xFF00C9A7),
                                  Color(0xFF00B09B),
                                ],
                              ),
                            ),
                            alignment: Alignment.center,
                            child: isLoading
                                ? const CircularProgressIndicator(
                              color: Colors.white,
                            )
                                : const Text(
                              "SEND OTP",
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1,
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(height: 18),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
