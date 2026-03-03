import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'student_otp_page.dart';

class StudentSignupStep2 extends StatefulWidget {
  final String regNo;
  final String phoneNumber;
  final String name;
  final String department;
  final String busId;
  final String boardingPoint;

  const StudentSignupStep2({
    super.key,
    required this.regNo,
    required this.phoneNumber,
    required this.name,
    required this.department,
    required this.busId,
    required this.boardingPoint,
  });

  @override
  State<StudentSignupStep2> createState() => _StudentSignupStep2State();
}

class _StudentSignupStep2State extends State<StudentSignupStep2> {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  bool isLoading = false;

  // ================= SEND OTP =================
  Future<void> sendOtp() async {
    setState(() => isLoading = true);

    await _auth.verifyPhoneNumber(
      phoneNumber: "+91${widget.phoneNumber}",

      /// AUTO VERIFY (Some devices)
      verificationCompleted: (PhoneAuthCredential credential) async {
        await _auth.signInWithCredential(credential);
      },

      /// ERROR
      verificationFailed: (FirebaseAuthException e) {
        setState(() => isLoading = false);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message ?? "OTP Failed")),
        );
      },

      /// OTP SENT ✅ → OPEN OTP PAGE
      codeSent: (String verificationId, int? resendToken) {
        setState(() => isLoading = false);

        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => StudentOtpPage(
              verificationId: verificationId,
              regNo: widget.regNo,
              phoneNumber: widget.phoneNumber,
              isSignup: true,
            ),
          ),
        );
      },

      codeAutoRetrievalTimeout: (String verificationId) {},
    );
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

          /// HEADER IMAGE
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Image.asset(
              "assets/images/student2.jpg",
              height: 240,
              fit: BoxFit.cover,
            ),
          ),

          /// CONTENT
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
                            Icons.verified_user,
                            color: Colors.teal,
                            size: 30,
                          ),
                        ),

                        const SizedBox(height: 14),

                        const Text(
                          "CONFIRM DETAILS",
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.teal,
                            letterSpacing: 1,
                          ),
                        ),

                        const SizedBox(height: 24),

                        /// STUDENT DETAILS
                        _infoTile(Icons.person, "Name", widget.name),
                        _infoTile(Icons.school, "Department", widget.department),
                        _infoTile(Icons.directions_bus, "Bus", widget.busId),
                        _infoTile(Icons.location_on, "Boarding", widget.boardingPoint),
                        _infoTile(Icons.phone, "Phone", widget.phoneNumber),

                        const SizedBox(height: 28),

                        /// SEND OTP BUTTON
                        SizedBox(
                          width: double.infinity,
                          height: 52,
                          child: ElevatedButton(
                            onPressed: isLoading ? null : sendOtp,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.teal,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            child: isLoading
                                ? const CircularProgressIndicator(
                                color: Colors.white)
                                : const Text(
                              "SEND OTP",
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

  // ================= INFO TILE =================
  Widget _infoTile(IconData icon, String title, String value) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.teal),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              "$title: $value",
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}