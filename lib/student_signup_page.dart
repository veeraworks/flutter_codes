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

  String? name;
  String? department;
  String? busId;
  String? boardingPoint;

  // ================= VERIFY STUDENT =================
  Future<void> checkRegisterNumber() async {
    if (regController.text
        .trim()
        .isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Enter Register Number")),
      );
      return;
    }

    if (phoneController.text
        .trim()
        .length != 10) {
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

        // ✅ GO TO STEP 2
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) =>
                StudentSignupStep2(
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
      backgroundColor: Colors.grey.shade100,
      extendBodyBehindAppBar: true,

      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        iconTheme: const IconThemeData(color: Colors.black),
      ),

      body: Stack(
        children: [

          /// ✅ FULL WIDTH TOP IMAGE
          Positioned(
            top: -10,
            left: 0,
            right: 0,
            child: Image.asset(
              'assets/images/student2.jpg',
              height: 240,
              width: double.infinity,
              fit: BoxFit.cover,
            ),
          ),

          /// ✅ SIGNUP CONTENT
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                children: [

                  const SizedBox(height: 180),

                  /// CARD
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(22),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.06),
                          blurRadius: 15,
                          offset: const Offset(0, 6),
                        )
                      ],
                    ),
                    child: Column(
                      children: [

                        /// ICON
                        Container(
                          padding: const EdgeInsets.all(18),
                          decoration: BoxDecoration(
                            color: Colors.teal.withOpacity(0.12),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.person_add_alt_1,
                            color: Colors.teal,
                            size: 30,
                          ),
                        ),

                        const SizedBox(height: 14),

                        const Text(
                          "STUDENT SIGNUP",
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.teal,
                          ),
                        ),

                        const SizedBox(height: 24),

                        /// REGISTER NUMBER
                        TextField(
                          controller: regController,
                          decoration: InputDecoration(
                            hintText: "Register Number",
                            prefixIcon: const Icon(
                              Icons.badge_outlined,
                              color: Colors.teal,
                            ),
                            filled: true,
                            fillColor: Colors.grey.shade100,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: BorderSide.none,
                            ),
                          ),
                        ),

                        const SizedBox(height: 16),

                        /// PHONE
                        TextField(
                          controller: phoneController,
                          keyboardType: TextInputType.phone,
                          decoration: InputDecoration(
                            hintText: "Mobile Number",
                            prefixIcon:
                            const Icon(Icons.phone, color: Colors.teal),
                            filled: true,
                            fillColor: Colors.grey.shade100,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: BorderSide.none,
                            ),
                          ),
                        ),

                        const SizedBox(height: 26),

                        /// BUTTON
                        SizedBox(
                          width: double.infinity,
                          height: 52,
                          child: ElevatedButton(
                            onPressed:
                            isLoading ? null : checkRegisterNumber,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.teal,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            child: isLoading
                                ? const CircularProgressIndicator(
                                color: Colors.white)
                                : const Text(
                              "NEXT",
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}