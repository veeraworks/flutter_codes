import 'package:flutter/material.dart';
import 'student_home_page.dart';
import 'student_otp_page.dart';
import 'student_signup_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

class StudentLoginPage extends StatefulWidget {
  const StudentLoginPage({super.key});

  @override
  State<StudentLoginPage> createState() => _StudentLoginPageState();
}

class _StudentLoginPageState extends State<StudentLoginPage>
    with SingleTickerProviderStateMixin {

  final TextEditingController idController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();

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

    _checkAutoLogin(); // 🔥 ADD THIS
  }

  @override
  void dispose() {
    _shakeController.dispose();
    idController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  // ✅ MANUAL HARDCODED LOGIN
  void _login() {
    String studentId = idController.text.trim();
    String password = passwordController.text.trim();

    if (studentId == "hi" && password == "123") {

      // 🔥 Go to OTP Page instead of Home
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => StudentOtpPage(
            studentId: studentId,
            phoneNumber: "9876543210",
          ),
        ),
      );
    } else {
      _shakeController.forward(from: 0);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Invalid ID or Password"),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
  Future<void> _checkAutoLogin() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();

    bool? isLoggedIn = prefs.getBool("isLoggedIn");
    String? role = prefs.getString("role");

    print("AutoLogin -> isLoggedIn: $isLoggedIn");
    print("AutoLogin -> role: $role");

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
                            decoration: InputDecoration(
                              prefixIcon: const Icon(Icons.badge, color: Colors.teal),
                              hintText: 'Student ID',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),

                          const SizedBox(height: 16),

                          /// 🔐 PASSWORD
                          TextField(
                            controller: passwordController,
                            obscureText: true,
                            decoration: InputDecoration(
                              prefixIcon: const Icon(Icons.lock, color: Colors.teal),
                              hintText: 'Password',
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

                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Text("New here? "),
                              GestureDetector(
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) =>
                                      const StudentSignupPage(),
                                    ),
                                  );
                                },
                                child: const Text(
                                  "Create an account",
                                  style: TextStyle(
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
