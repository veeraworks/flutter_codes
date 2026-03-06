import 'package:flutter/material.dart';

class AboutAppPage extends StatelessWidget {
  const AboutAppPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("About App"),
        backgroundColor: const Color(0xFF00BFA6),
        foregroundColor: Colors.white,
      ),
      backgroundColor: const Color(0xFFF6F3F7),

      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(20),

          child: Column(
            children: [

              const SizedBox(height: 30),

              const Icon(
                Icons.directions_bus_filled,
                size: 80,
                color: Color(0xFF00BFA6),
              ),

              const SizedBox(height: 20),

              const Text(
                "Smart Bus Tracking Management",
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 8),

              const Text(
                "Version 1.0.0",
                style: TextStyle(color: Colors.black54),
              ),

              const SizedBox(height: 30),

              /// INFO CARD
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                    )
                  ],
                ),

                child: Column(
                  children: [

                    _infoRow("Institution", "Sairam Institutions"),
                    const Divider(),

                    _infoRow("System", "Real-Time Bus Tracking"),
                    const Divider(),

                    _infoRow("Temporary Bus Support", "Available"),
                    const Divider(),

                    _infoRow("Trip Monitoring", "Morning / Evening"),
                    const Divider(),

                    _infoRow("Notifications", "Trip Alerts"),

                  ],
                ),
              ),

              const SizedBox(height: 40),

              const Text(
                "© 2026 Smart Bus Tracking",
                style: TextStyle(
                  color: Colors.black45,
                  fontSize: 12,
                ),
              ),

              const SizedBox(height: 10),

            ],
          ),
        ),
      ),
    );
  }

  static Widget _infoRow(String title, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),

      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,

        children: [

          Text(
            title,
            style: const TextStyle(
              color: Colors.black54,
              fontSize: 15,
            ),
          ),

          Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 15,
            ),
          ),

        ],
      ),
    );
  }
}