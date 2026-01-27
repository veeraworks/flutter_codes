import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';

class DriverSignupPage extends StatefulWidget {
  const DriverSignupPage({super.key});

  @override
  State<DriverSignupPage> createState() => _DriverSignupPageState();
}

class _DriverSignupPageState extends State<DriverSignupPage> {

  final TextEditingController nameController = TextEditingController();
  final TextEditingController phoneController = TextEditingController();
  final TextEditingController busController = TextEditingController();
  final TextEditingController otpController = TextEditingController();

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final DatabaseReference _db = FirebaseDatabase.instance.ref("drivers");

  bool otpSent = false;
  bool isLoading = false;
  String verificationId = "";

  String selectedRoute = "Select Route";

  final List<String> routes = [
    "Ashok Pillar",
    "Koyambedu",
    "Nesapakkam",
    "Madipakkam",
    "Velachery",
    "Chengalpet",
    "Anakaputhur",
    "Sithalapakkam",
    "Padappai"
  ];

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

  // ---------------- VERIFY OTP & SAVE ----------------
  Future<void> verifyOtpAndRegister() async {
    try {
      setState(() => isLoading = true);

      PhoneAuthCredential credential = PhoneAuthProvider.credential(
        verificationId: verificationId,
        smsCode: otpController.text.trim(),
      );

      UserCredential userCred =
      await _auth.signInWithCredential(credential);

      String uid = userCred.user!.uid;

      await _db.child(uid).set({
        "name": nameController.text.trim(),
        "phone": phoneController.text.trim(),
        "busNumber": busController.text.trim(),
        "route": selectedRoute,
        "uid": uid,
      });

      setState(() => isLoading = false);
      Navigator.pop(context);

    } catch (e) {
      setState(() => isLoading = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text("Invalid OTP")));
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
        borderSide: const BorderSide(color: Color(0xFF00C9A7)),
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
              color: Colors.white.withOpacity(0.50),
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
                      Icons.person_add_alt_1,
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
                          color: Colors.black.withOpacity(0.06),
                          blurRadius: 18,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [

                        const Text(
                          "DRIVER SIGN UP",
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF00C9A7),
                          ),
                        ),

                        const SizedBox(height: 22),

                        TextField(
                          controller: nameController,
                          decoration: inputDecoration(
                            hint: 'Driver Name',
                            icon: Icons.person_outline,
                          ),
                        ),

                        const SizedBox(height: 14),

                        TextField(
                          controller: busController,
                          decoration: inputDecoration(
                            hint: 'Bus Number',
                            icon: Icons.directions_bus,
                          ),
                        ),

                        const SizedBox(height: 14),

                        TextField(
                          controller: phoneController,
                          keyboardType: TextInputType.phone,
                          decoration: inputDecoration(
                            hint: 'Phone Number',
                            icon: Icons.phone,
                          ),
                        ),

                        const SizedBox(height: 14),

                        DropdownButtonFormField<String>(
                          value: selectedRoute,
                          items: ["Select Route", ...routes]
                              .map((e) => DropdownMenuItem(
                            value: e,
                            child: Text(e),
                          ))
                              .toList(),
                          onChanged: (val) {
                            setState(() => selectedRoute = val!);
                          },
                          decoration: inputDecoration(
                            hint: "Route",
                            icon: Icons.route,
                          ),
                        ),

                        if (otpSent) ...[
                          const SizedBox(height: 14),
                          TextField(
                            controller: otpController,
                            keyboardType: TextInputType.number,
                            decoration: inputDecoration(
                              hint: 'Enter OTP',
                              icon: Icons.lock_outline,
                            ),
                          ),
                        ],

                        const SizedBox(height: 26),

                        // ✅ MODERN PRIMARY BUTTON (LIKE IMAGE)
                        GestureDetector(
                          onTap: isLoading
                              ? null
                              : (otpSent ? verifyOtpAndRegister : sendOtp),
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
                                : Text(
                              otpSent
                                  ? "VERIFY & CREATE"
                                  : "SEND OTP",
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1,
                              ),
                            ),
                          ),
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
