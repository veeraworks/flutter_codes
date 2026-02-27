import 'dart:convert';
import 'service/api_service.dart';
import 'package:flutter/material.dart';
import 'student_home_page.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'student_otp_page.dart';
import 'student_signup_page.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'student_signup_page.dart';

class StudentLoginPage extends StatefulWidget {
  const StudentLoginPage({super.key});

  @override
  State<StudentLoginPage> createState() => _StudentLoginPageState();
}

class _StudentLoginPageState extends State<StudentLoginPage>
    with SingleTickerProviderStateMixin {

  final TextEditingController idController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  bool _obscurePassword = false;

  late AnimationController _shakeController;
  late Animation<double> _shakeAnimation;

  @override
  void initState() {
    super.initState();

    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );

    _shakeAnimation = Tween<double>(begin: 0, end: 10)
        .chain(CurveTween(curve: Curves.elasticIn))
        .animate(_shakeController);

    _checkAutoLogin();
  }

  @override
  void dispose() {
    _shakeController.dispose();
    idController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  // ✅ MANUAL LOGIN (Firebase NOT touched)
  Future<void> _login() async {
    String studentId = idController.text.trim();
    String mobileNumber = passwordController.text.trim();

    if (studentId.isEmpty || mobileNumber.isEmpty) {
      _shakeController.forward(from: 0);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Please fill all fields"),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    try {
      final response = await ApiService.post(
        "/students/check-student",
        {
          "regNo": studentId,
          "phone": mobileNumber,
        },
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200 && data["student"] != null) {

        await _auth.verifyPhoneNumber(
          phoneNumber: "+91$mobileNumber",

          verificationCompleted: (credential) async {
            await _auth.signInWithCredential(credential);
          },

          verificationFailed: (e) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(e.message ?? "OTP failed")),
            );
          },

          codeSent: (vid, token) {

            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) => StudentOtpPage(
                  verificationId: vid,
                  regNo: studentId,
                  phoneNumber: mobileNumber,
                  isSignup: false, // 🔥 LOGIN FLOW
                ),
              ),
            );
          },

          codeAutoRetrievalTimeout: (vid) {},
        );

      } else {
        _shakeController.forward(from: 0);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Invalid Student ID or Mobile Number"),
            backgroundColor: Colors.red,
          ),
        );
      }

    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Server not reachable"),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
  // ---------------AUTO LOGIN----------------------------------------------
  Future<void> _checkAutoLogin() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();

    bool? isLoggedIn = prefs.getBool("isLoggedIn");
    String? role = prefs.getString("role");

    if (isLoggedIn == true && role == "student") {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const StudentHomePage()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [

          /// 🎓 TOP IMAGE
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

          /// 🧾 LOGIN CARD
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: AnimatedBuilder(
                animation: _shakeAnimation,
                builder: (context, child) {
                  return Transform.translate(
                    offset: Offset(_shakeAnimation.value, 0),
                    child: child,
                  );
                },
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

                          CircleAvatar(
                            radius: 40,
                            backgroundColor: Colors.teal.withOpacity(0.15),
                            child: const Icon(
                              Icons.school,
                              size: 40,
                              color: Colors.teal,
                            ),
                          ),

                          const SizedBox(height: 20),

                          const Text(
                            "STUDENT LOGIN",
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.teal,
                            ),
                          ),

                          const SizedBox(height: 24),

                          /// 🆔 STUDENT ID
                          TextField(
                            controller: idController,
                            keyboardType: TextInputType.text,
                            decoration: InputDecoration(
                              prefixIcon: const Icon(Icons.badge, color: Colors.teal),
                              hintText: 'Student ID',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),

                          const SizedBox(height: 16),

                          /// 📱 MOBILE NUMBER
                          TextField(
                            controller: passwordController,
                            keyboardType: TextInputType.phone,
                            decoration: InputDecoration(
                              prefixIcon: const Icon(Icons.phone, color: Colors.teal),
                              hintText: 'Mobile Number',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),

                          const SizedBox(height: 14),

                          /// ✅ LOGIN BUTTON
                          SizedBox(
                            width: double.infinity,
                            height: 52,
                            child: ElevatedButton(
                              onPressed: _login,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.teal,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(30),
                                ),
                              ),
                              child: const Text(
                                'LOGIN',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),

                          const SizedBox(height: 14),

                          /// 🌟 BETTER SIGN UP SECTION
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Text(
                                "New here? ",
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.black,
                                ),
                              ),
                              GestureDetector(
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => const StudentSignupStep1(),
                                    ),
                                  );
                                },
                                child: const Text(
                                  "Create an account",
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: Colors.teal,
                                    fontWeight: FontWeight.bold,

                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 60),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}