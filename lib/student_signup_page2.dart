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

      verificationCompleted: (credential) async {
        await _auth.signInWithCredential(credential);
      },

      verificationFailed: (e) {
        setState(() => isLoading = false);
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message ?? "OTP Failed")));
      },

      codeSent: (vid, token) {

        setState(() => isLoading = false);

        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => StudentOtpPage(
              verificationId: vid,
              regNo: widget.regNo,
              phoneNumber: widget.phoneNumber,
              isSignup: true,
            ),
          ),
        );
      },

      codeAutoRetrievalTimeout: (vid) {},
    );
  }

  // ================= UI =================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Confirm Details")),

      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            Text("Name: ${widget.name}"),
            Text("Department: ${widget.department}"),
            Text("Bus: ${widget.busId}"),
            Text("Boarding: ${widget.boardingPoint}"),
            Text("Phone: ${widget.phoneNumber}"),

            const SizedBox(height: 30),

            isLoading
                ? const Center(child: CircularProgressIndicator())
                : SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: sendOtp,
                child: const Text("SEND OTP"),
              ),
            )
          ],
        ),
      ),
    );
  }
}