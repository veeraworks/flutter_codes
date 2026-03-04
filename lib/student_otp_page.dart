import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'service/api_service.dart';
import 'student_home_page.dart';

class StudentOtpPage extends StatefulWidget {
  final String verificationId;
  final String regNo;
  final String phoneNumber;
  final bool isSignup;

  const StudentOtpPage({
    super.key,
    required this.verificationId,
    required this.regNo,
    required this.phoneNumber,
    required this.isSignup,
  });

  @override
  State<StudentOtpPage> createState() => _StudentOtpPageState();
}

class _StudentOtpPageState extends State<StudentOtpPage> {
  final TextEditingController otpController = TextEditingController();

  bool isLoading = false;

  Future<void> _submitOtp() async {
    if (otpController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Enter OTP")),
      );
      return;
    }

    setState(() => isLoading = true);

    try {

      // ✅ DEV MODE — allow any OTP
      if (otpController.text.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Enter OTP")),
        );
        setState(() => isLoading = false);
        return;
      }
      // 🔥 STEP 2: Call backend
      final response = await ApiService.post(
        widget.isSignup
            ? "/students/complete-signup"
            : "/students/check-student",
        {
          "regNo": widget.regNo,
          "phone": widget.phoneNumber,
        },
      );

      if (response.statusCode != 200) {
        throw Exception("Backend error");
      }

      final data = jsonDecode(response.body);

      if (data["student"] == null) {
        throw Exception("Student not found");
      }

      final student = data["student"];

      // 💾 STEP 3: Save session
      final prefs = await SharedPreferences.getInstance();

      await prefs.setBool("isLoggedIn", true);
      await prefs.setString("role", "student");
      await prefs.setString("regNo", widget.regNo.toUpperCase());
      await prefs.setString("studentName", student["name"] ?? "");
      await prefs.setString("busId", student["busId"] ?? "");
      await prefs.setString("routeName", student["busName"] ?? "");
      await prefs.setString("boardingPoint", student["boardingPoint"] ?? "");

      // 🔔 Subscribe to bus topic
      if (student["busId"] != null) {
        await FirebaseMessaging.instance
            .subscribeToTopic(student["busId"].toString().toLowerCase());
      }

      if (!mounted) return;

      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const StudentHomePage()),
            (route) => false,
      );

    } on FirebaseAuthException {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Invalid OTP")),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Login failed")),
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
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.teal,
        title: const Text(
          "OTP Verification",
          style: TextStyle(color: Colors.white),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.12),
                  blurRadius: 25,
                  offset: const Offset(0, 12),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircleAvatar(
                  radius: 38,
                  backgroundColor: Colors.teal.withOpacity(0.15),
                  child: const Icon(Icons.lock,
                      color: Colors.teal, size: 36),
                ),
                const SizedBox(height: 20),
                const Text(
                  "ENTER OTP",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.teal,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  "OTP sent to +91 ${widget.phoneNumber}",
                  style: const TextStyle(color: Colors.grey),
                ),
                const SizedBox(height: 24),
                TextField(
                  controller: otpController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.password,
                        color: Colors.teal),
                    hintText: "Enter OTP",
                    border: OutlineInputBorder(
                      borderRadius:
                      BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(height: 28),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: isLoading ? null : _submitOtp,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.teal,
                      shape: RoundedRectangleBorder(
                        borderRadius:
                        BorderRadius.circular(30),
                      ),
                    ),
                    child: isLoading
                        ? const CircularProgressIndicator(
                        color: Colors.white)
                        : Text(
                      widget.isSignup
                          ? "VERIFY & CREATE"
                          : "VERIFY & LOGIN",
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
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