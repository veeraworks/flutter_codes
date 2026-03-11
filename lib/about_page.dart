import 'package:flutter/material.dart';

class AboutApp extends StatelessWidget {
  const AboutApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F3F7),
      appBar: AppBar(
        backgroundColor: const Color(0xFF00BFA6),
        title: const Text(
          'About BusTrackPro',
          style: TextStyle(color: Colors.white),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _infoCard(
              title: 'BusTrackPro',
              content: 'Smart College Bus Tracking System',
              big: true,
            ),
            const SizedBox(height: 20),
            _infoCard(
              content:
                  'BusTrackPro is a smart and user-friendly college bus tracking application designed to help students track their buses in real time.\n\n'
                  'The app reduces waiting time, improves safety, and provides live bus updates such as arrival time, delay status, and bus availability.\n\n'
                  'BusTrackPro aims to create a reliable and stress-free daily travel experience for students and staff.',
            ),
            const SizedBox(height: 20),
            _infoCard(
              title: 'App Information',
              content:
                  'Version: 1.0.0\nStatus: Active\nDeveloped by: Sairam Instituition\nPlatform: Android',
              highlight: true,
            ),
          ],
        ),
      ),
    );
  }
}

Widget _infoCard({
  String? title,
  required String content,
  bool big = false,
  bool highlight = false,
}) {
  return Container(
    width: double.infinity,
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: highlight ? const Color(0xFFE0F7F3) : Colors.white,
      borderRadius: BorderRadius.circular(16),
      boxShadow: highlight
          ? null
          : [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
              ),
            ],
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (title != null)
          Text(
            title,
            style: TextStyle(
              fontSize: big ? 26 : 17,
              fontWeight: FontWeight.bold,
              color: const Color(0xFF00BFA6),
            ),
          ),
        if (title != null) const SizedBox(height: 8),
        Text(
          content,
          style: const TextStyle(fontSize: 15, height: 1.6),
        ),
      ],
    ),
  );
}
