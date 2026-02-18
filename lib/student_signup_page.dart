  import 'dart:convert';
  import 'package:flutter/material.dart';
  import 'package:firebase_auth/firebase_auth.dart';
  import 'package:firebase_database/firebase_database.dart';
  import 'package:http/http.dart' as http;
  import 'package:shared_preferences/shared_preferences.dart';
  import 'package:firebase_messaging/firebase_messaging.dart';
  import 'student_home_page.dart';

  class StudentSignupPage extends StatefulWidget {
    const StudentSignupPage({super.key});

    @override
    State<StudentSignupPage> createState() => _StudentSignupPageState();
  }

  class _StudentSignupPageState extends State<StudentSignupPage> {

    final TextEditingController nameController = TextEditingController();
    final TextEditingController regController = TextEditingController();
    final TextEditingController phoneController = TextEditingController();
    final TextEditingController otpController = TextEditingController();

    final FirebaseAuth _auth = FirebaseAuth.instance;
    final DatabaseReference _db = FirebaseDatabase.instance.ref("students");

    bool otpSent = false;
    bool isLoading = false;
    String verificationId = "";
    bool isPreRegistered = false;
    bool isValidRegisterNumber = false;

    String? busId;
    String? busName;
    String? boardingPoint;

    //================= CHECK REGISTER NUMBER =================
    Future<void> checkRegisterNumber() async {

      if (regController.text.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Enter Register Number")),
        );
        return;
      }
      try {
        final response = await http.post(
          Uri.parse("http://10.114.21.165:3000/check-student"),
          headers: {"Content-Type": "application/json"},
          body: jsonEncode({
            "registerNumber": regController.text.trim(),
          }),
        );

        final data = jsonDecode(response.body);

        if (data["status"] == "ALREADY_REGISTERED") {
          setState(() {
            isValidRegisterNumber = false;
          });

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("This register number is already registered"),
              backgroundColor: Colors.red,
            ),
          );
          return;
        }

        if (data["status"] == "NOT_FOUND") {
          setState(() {
            isValidRegisterNumber = false;
          });

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Invalid Register Number"),
              backgroundColor: Colors.red,
            ),
          );
          return;
        }

        if (data["status"] == "PRE_REGISTERED") {
          setState(() {
            nameController.text = data["name"];
            busId = data["busId"];
            busName = data["busName"];
            boardingPoint = data["boardingPoint"];
            isValidRegisterNumber = true;
          });

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Register number verified"),
              backgroundColor: Colors.green,
            ),
          );
        }

      } catch (e) {
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
          setState(() {
            verificationId = vid;
            otpSent = true;
            isLoading = false;
          });
        },
        codeAutoRetrievalTimeout: (vid) {
          verificationId = vid;
        },
      );
    }
  //to pre-fill the route and stop dropdowns
    Future<void> fetchStudentDetails(String registerNumber) async {
      try {
        final response = await http.post(
          Uri.parse("http://10.114.21.165:3000/get-student-by-reg"),
          headers: {"Content-Type": "application/json"},
          body: jsonEncode({
            "registerNumber": registerNumber,
          }),
        );

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);

          setState(() {
            nameController.text = data["name"];
            busId = data["busId"];
            busName = data["busName"];
            boardingPoint = data["boardingPoint"];
            isValidRegisterNumber = true;
          });

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Pre-registered student found")),
          );
        } else {
          setState(() {
            isPreRegistered = false;
          });

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Student not pre-registered")),
          );
        }
      } catch (e) {
        print("Error fetching student: $e");
      }
    }

    // ---------------- VERIFY OTP & SAVE ----------------
    Future<void> verifyOtpAndRegister() async {
      try {
        setState(() => isLoading = true);

        PhoneAuthCredential credential = PhoneAuthProvider.credential(
          verificationId: verificationId,
          smsCode: otpController.text.trim(),
        );

        await _auth.signInWithCredential(credential);

        // 🔥 CALL BACKEND COMPLETE SIGNUP
        final response = await http.post(
          Uri.parse("http://10.114.21.165:3000/students/complete-signup"),
          headers: {"Content-Type": "application/json"},
          body: jsonEncode({
            "regNo": regController.text.trim(),
          }),
        );

        if (response.statusCode == 200) {

          final prefs = await SharedPreferences.getInstance();

          await prefs.setBool("isLoggedIn", true);
          await prefs.setString("role", "student");
          await prefs.setString("busId", busId!);
          await prefs.setString("routeName", busName!);
          await prefs.setString("boardingPoint", boardingPoint!);

          // 🔔 Subscribe to bus topic
          await FirebaseMessaging.instance
              .subscribeToTopic(busId!.toLowerCase());

          setState(() => isLoading = false);

          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const StudentHomePage()),
          );

        } else {
          setState(() => isLoading = false);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Signup failed")),
          );
        }

      } catch (e) {
        setState(() => isLoading = false);
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text("Invalid OTP")));
      }
    }
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
                          inputBox(nameController, "Student Name", Icons.person),

                          inputBox(phoneController, "Phone Number", Icons.phone,
                              type: TextInputType.phone),

                          if (otpSent)
                            inputBox(otpController, "Enter OTP", Icons.lock,
                                type: TextInputType.number),

                          const SizedBox(height: 16),

                          isLoading
                              ? const CircularProgressIndicator()
                              :ElevatedButton(
                            onPressed: otpSent
                                ? verifyOtpAndRegister
                                : () async {
                              await checkRegisterNumber();
                              if (isValidRegisterNumber) {
                                sendOtp();
                              }
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.teal,
                            ),
                            child: Text(
                              otpSent ? "VERIFY & CREATE" : "SEND OTP",
                              style: const TextStyle(
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
