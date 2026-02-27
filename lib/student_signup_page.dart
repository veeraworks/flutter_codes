import 'dart:convert';
import 'package:flutter/material.dart';
import 'service/api_service.dart';
import 'student_signup_page2.dart';

class StudentSignupStep1 extends StatefulWidget {
  const StudentSignupStep1({super.key});

  @override
  State<StudentSignupStep1> createState() => _StudentSignupStep1State();
}

class _StudentSignupStep1State extends State<StudentSignupStep1> {

  final TextEditingController regController = TextEditingController();
  final TextEditingController phoneController = TextEditingController();

  bool isLoading = false;
  bool isValidRegisterNumber = false;

  String? name;
  String? department;
  String? busId;
  String? boardingPoint;

  // ================= VERIFY STUDENT =================
  Future<void> checkRegisterNumber() async {

    if (regController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Enter Register Number")),
      );
      return;
    }

    if (phoneController.text.trim().length != 10) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Enter valid 10-digit phone")),
      );
      return;
    }

    setState(() => isLoading = true);

    try {
      final response = await ApiService.post(
        "/students/verify-signup",
        {
          "regNo": regController.text.trim(),
        },
      );

      setState(() => isLoading = false);

      if (response.statusCode == 200) {

        final data = jsonDecode(response.body);
        final student = data["student"];

        name = student["name"];
        department = student["department"];
        busId = student["busId"];
        boardingPoint = student["boardingPoint"];

        isValidRegisterNumber = true;

        // ✅ GO TO STEP 2
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => StudentSignupStep2(
              regNo: regController.text.trim(),
              phoneNumber: phoneController.text.trim(),
              name: name!,
              department: department!,
              busId: busId!,
              boardingPoint: boardingPoint!,
            ),
          ),
        );

      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Student not found"),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      setState(() => isLoading = false);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Server error"),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // ================= UI =================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Student Signup")),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [

            TextField(
              controller: regController,
              decoration: const InputDecoration(
                labelText: "Register Number",
                border: OutlineInputBorder(),
              ),
            ),

            const SizedBox(height: 16),

            TextField(
              controller: phoneController,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: "Phone Number",
                border: OutlineInputBorder(),
              ),
            ),

            const SizedBox(height: 24),

            isLoading
                ? const CircularProgressIndicator()
                : ElevatedButton(
              onPressed: checkRegisterNumber,
              child: const Text("NEXT"),
            )
          ],
        ),
      ),
    );
  }
}