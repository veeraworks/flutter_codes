import 'package:flutter/material.dart';
import 'driver_signup_page.dart';
import 'driver_otp_page.dart';
import 'driver_home_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
    Future<void> driverLogin() async {

      final name = driverNameController.text.trim();
      final phone = phoneController.text.trim();

      if (name.isEmpty || phone.isEmpty) {
        setState(() => showError = true);
        shakeController.forward(from: 0);
        return;
      }

      setState(() {
        showError = false;
        isLoading = true;
      });

      await Future.delayed(const Duration(milliseconds: 500));

      setState(() => isLoading = false);

      // 🔐 Manual Login Condition
      if (name == "driver" && phone == "123") {

        SharedPreferences prefs = await SharedPreferences.getInstance();

        await prefs.setBool("isLoggedIn", true);
        await prefs.setString("role", "driver");
        await prefs.setString("busId", "BUS10");
        await prefs.setString("busNumber", "BUS10");
        await prefs.setString("routeName", "Ashok Pillar");
        await prefs.setString("originalBusNumber", "BUS10");
        await prefs.setString("originalRoute", "Ashok Pillar");

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => const DriverHomePage(),
          ),
        );

      } else {
        setState(() => showError = true);
      }
    }

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

  Future<void> driverLogin() async {
    final name = driverNameController.text.trim();
    final phone = phoneController.text.trim();

    if (name.isEmpty || phone.isEmpty) {
      setState(() => showError = true);
      shakeController.forward(from: 0);
      return;
    }

    setState(() {
      showError = false;
      isLoading = true;
    });

    await Future.delayed(const Duration(milliseconds: 500));

    setState(() => isLoading = false);

    // 🔐 Hardcoded credentials
    if (name == "driver" && phone == "123") {

      SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setBool("isLoggedIn", true);
      await prefs.setString("role", "driver");

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => const DriverHomePage(),
        ),
      );

    } else {
      setState(() => showError = true);
    }
  }

  InputDecoration inputDecoration({
    required String hint,
    required IconData icon,
  }) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(fontSize: 15),
      prefixIcon: Icon(icon, color: const Color(0xFF00C9A7)),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
      ),
    );
  }

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
            child: Container(color: Colors.white.withOpacity(0.50)),
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
                          keyboardType: TextInputType.phone,
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
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 18),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Text(
                              "New here? ",
                              style: TextStyle(color: Colors.black54),
                            ),
                            GestureDetector(
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) =>
                                    const DriverSignupPage(),
                                  ),
                                );
                              },
                              child: const Text(
                                "Create an account",
                                style: TextStyle(
                                  color: Color(0xFF00C9A7),
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
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
