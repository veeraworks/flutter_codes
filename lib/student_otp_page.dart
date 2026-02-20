import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'student_home_page.dart';

class StudentOtpPage extends StatefulWidget {
  final String studentId;
  final String phoneNumber;

  const StudentOtpPage({
    super.key,
    required this.studentId,
    required this.phoneNumber,
  });

  @override
  State<StudentOtpPage> createState() => _StudentOtpPageState();
}

class _StudentOtpPageState extends State<StudentOtpPage> {
  final TextEditingController otpController = TextEditingController();
  bool isLoading = false;

  Future<void> _submitOtp() async {
    if (otpController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Enter OTP")),
      );
      return;
    }

    setState(() => isLoading = true);

    try {
      final response = await http.post(
        Uri.parse("https://null-sheldon-unstudded.ngrok-free.dev/students/check-student"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "regNo": widget.studentId,
          "phone": widget.phoneNumber,
        }),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200 && data["student"] != null) {

        final student = data["student"];

        final prefs = await SharedPreferences.getInstance();

        await prefs.setBool("isLoggedIn", true);
        await prefs.setString("role", "student");
        await prefs.setString("studentId", student["regNo"] ?? "");
        await prefs.setString("studentName", student["name"] ?? "");
        await prefs.setString("routeName", student["route"] ?? "");
        await prefs.setString("busNumber", student["busNo"] ?? "");
        await prefs.setString("busId", student["busId"] ?? ""); // 🔥 ADD THIS
        await prefs.setString("boardingPoint", student["boardingPoint"] ?? "");

        if (!mounted) return;

        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const StudentHomePage()),
              (route) => false,
        );

      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Student not found")),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Server not reachable")),
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
            padding: const EdgeInsets.all(20),
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
                  radius: 36,
                  backgroundColor: Colors.teal.withOpacity(0.15),
                  child: const Icon(Icons.lock, color: Colors.teal, size: 34),
                ),

                const SizedBox(height: 16),

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
                  "OTP sent to ${widget.phoneNumber}",
                  style: const TextStyle(color: Colors.grey),
                ),

                const SizedBox(height: 20),

                TextField(
                  controller: otpController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    prefixIcon:
                    const Icon(Icons.password, color: Colors.teal),
                    hintText: "Enter OTP",
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: isLoading ? null : _submitOtp,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.teal,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                    ),
                    child: isLoading
                        ? const CircularProgressIndicator(
                      color: Colors.white,
                    )
                        : const Text(
                      "SUBMIT",
                      style: TextStyle(
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
