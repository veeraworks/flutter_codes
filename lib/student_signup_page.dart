  import 'dart:convert';
  import 'package:flutter/material.dart';
  import 'package:firebase_auth/firebase_auth.dart';
  import 'package:firebase_database/firebase_database.dart';
  import 'service/api_service.dart';
  import 'package:project_spt/student_otp_page.dart';

  class StudentSignupPage extends StatefulWidget {
    const StudentSignupPage({super.key});

    @override
    State<StudentSignupPage> createState() => _StudentSignupPageState();
  }

  class _StudentSignupPageState extends State<StudentSignupPage> {

    final TextEditingController nameController = TextEditingController();
    final TextEditingController regController = TextEditingController();
    final TextEditingController phoneController = TextEditingController();
    final TextEditingController routeController = TextEditingController();
    final TextEditingController boardingController = TextEditingController();

    final FirebaseAuth _auth = FirebaseAuth.instance;
    final DatabaseReference _db = FirebaseDatabase.instance.ref("students");

    bool isLoading = false;
    bool isValidRegisterNumber = false;
    String? selectedRoute;
    String? selectedBoardingPoint;
    String? busId;
    String? busName;
    String? boardingPoint;
    String? selectedDepartment;

    List<String> departmentList = [
      "CSE FIRST YEAR",
      "CSE SECOND YEAR",
      "CSE THIRD YEAR",

      "ECE FIRST YEAR",
      "ECE SECOND YEAR",
      "ECE THIRD YEAR",

      "EEE FIRST YEAR",
      "EEE SECOND YEAR",
      "EEE THIRD YEAR",

      "MECH FIRST YEAR",
      "MECH SECOND YEAR",
      "MECH THIRD YEAR",

      "CIVIL FIRST YEAR",
      "CIVIL SECOND YEAR",
      "CIVIL THIRD YEAR",

      "IOT FIRST YEAR",
      "IOT SECOND YEAR",
      "IOT THIRD YEAR",
    ];

    //================= CHECK REGISTER NUMBER =================
    Future<void> checkRegisterNumber() async {
      if (regController.text.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Enter Register Number")),
        );
        return;
      }

      try {
        final response = await ApiService.post(
          "/students/verify-signup",
          {
            "regNo": regController.text.trim(),
          },
        );

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          final student = data["student"];

          setState(() {
            nameController.text = student["name"];
            selectedDepartment = student["department"];
            busId = student["busId"];

            routeController.text = student["busId"];
            boardingController.text = student["boardingPoint"];

            selectedRoute = student["busId"];
            selectedBoardingPoint = student["boardingPoint"];

            isValidRegisterNumber = true;
          });

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Student verified successfully"),
              backgroundColor: Colors.green,
            ),
          );
        } else {
          setState(() {
            isValidRegisterNumber = false;
          });

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Student not found"),
              backgroundColor: Colors.red,
            ),
          );
        }
      } catch (e) {
        setState(() {
          isValidRegisterNumber = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Server error"),
            backgroundColor: Colors.red,
          ),
        );
      }
    }

    // ---------------- SEND OTP ----------------
    Future<void> sendOtp() async {

      if (phoneController.text.trim().length != 10) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Enter valid 10-digit phone number")),
        );
        return;
      }

      setState(() => isLoading = true);

      await _auth.verifyPhoneNumber(
        phoneNumber: "+91${phoneController.text.trim()}",

        verificationCompleted: (credential) async {
          await _auth.signInWithCredential(credential);
        },

        verificationFailed: (e) {
          setState(() => isLoading = false);
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text(e.message ?? "OTP failed")));
        },

        codeSent: (vid, token) {

          setState(() => isLoading = false);

          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => StudentOtpPage(
                verificationId: vid,
                regNo: regController.text.trim(),
                phoneNumber: phoneController.text.trim(),
                isSignup: true, // 🔥 SIGNUP FLOW
              ),
            ),
          );
        },

        codeAutoRetrievalTimeout: (vid) {},
      );
    }
    String? verificationId;
    // ---------------- UI ----------------
    @override
    Widget build(BuildContext context) {
      return Scaffold(
        backgroundColor: Colors.white,
        body: Stack(
          children: [

            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Image.asset(
                'assets/images/student2.jpg',
                height: 240,
                fit: BoxFit.cover,
                color: Colors.white.withOpacity(0.1),
                colorBlendMode: BlendMode.lighten,
              ),
            ),

            Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  children: [

                    const SizedBox(height: 180),

                    Container(
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
                          CircleAvatar( radius: 40,
                            backgroundColor: Colors.teal.withOpacity(0.15),
                            child: const Icon(Icons.person_add,
                                size: 40, color: Colors.teal),
                          ),

                          const SizedBox(height: 20),

                          const Text("STUDENT SIGN UP",
                              style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.teal)),

                          const SizedBox(height: 16),

                          inputBox(regController, "Register Number", Icons.badge),

                          TextField(
                            controller: nameController,
                            readOnly: true,
                            decoration: InputDecoration(
                              prefixIcon: const Icon(Icons.person, color: Colors.teal),
                              hintText: "Student Name",
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),

                          inputBox(phoneController, "Phone Number", Icons.phone,
                              type: TextInputType.phone),

                          const SizedBox(height: 12),
                          DropdownButtonFormField<String>(
                            value: selectedDepartment,
                            decoration: InputDecoration(
                              prefixIcon: const Icon(Icons.school, color: Colors.teal),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            hint: const Text("Department"),
                            items: departmentList.map((dept) {
                              return DropdownMenuItem(
                                value: dept,
                                child: Text(dept),
                              );
                            }).toList(),
                            onChanged: (value) {
                              setState(() {
                                selectedDepartment = value;
                              });
                            },
                          ),

                          const SizedBox(height: 12),

                          TextField(
                            controller: routeController,
                            readOnly: true,
                            decoration: InputDecoration(
                              prefixIcon: const Icon(Icons.directions_bus, color: Colors.teal),
                              hintText: "Route Name",
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),

                          const SizedBox(height: 12),

                          TextField(
                            controller: boardingController,
                            readOnly: true,
                            decoration: InputDecoration(
                              prefixIcon: const Icon(Icons.location_on, color: Colors.teal),
                              hintText: "Boarding Point",
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),

                          const SizedBox(height: 16),

                          isLoading
                              ? const CircularProgressIndicator()
                              :ElevatedButton(
                            onPressed: () async {
                              await checkRegisterNumber();
                              if (isValidRegisterNumber) {
                                await sendOtp();
                              }
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.teal,
                            ),
                            child: const Text(
                              "SEND OTP",
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          )
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

    Widget inputBox(TextEditingController controller, String hint, IconData icon,
        {TextInputType type = TextInputType.text}) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: TextField(
          controller: controller,
          keyboardType: type,
          decoration: InputDecoration(
            prefixIcon: Icon(icon, color: Colors.teal),
            hintText: hint,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
      );
    }
  }
