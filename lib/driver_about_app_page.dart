import 'package:flutter/material.dart';

class AboutAppPage extends StatelessWidget {
  const AboutAppPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FA),

      appBar: AppBar(
        elevation: 0,
        title: const Text("About App"),
        centerTitle: true,
        backgroundColor: const Color(0xFF00BFA6),
        foregroundColor: Colors.white,
      ),

      body: SingleChildScrollView(
        child: Column(
          children: [

            /// HEADER
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 40),
              decoration: const BoxDecoration(
                color: Color(0xFF00BFA6),
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(30),
                  bottomRight: Radius.circular(30),
                ),
              ),

              child: Column(
                children: [

                  /// BUS ICON
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black26,
                          blurRadius: 10,
                        )
                      ],
                    ),
                    child: const Icon(
                      Icons.directions_bus_filled,
                      size: 50,
                      color: Color(0xFF00BFA6),
                    ),
                  ),

                  const SizedBox(height: 20),

                  const Text(
                    "Smart Bus Tracking",
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),

                  const SizedBox(height: 6),

                  const Text(
                    "Version 1.0.0",
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 30),

            /// INFO CARD
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),

              child: Container(
                padding: const EdgeInsets.all(20),

                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.08),
                      blurRadius: 15,
                      offset: const Offset(0, 6),
                    )
                  ],
                ),

                child: Column(
                  children: [

                    _infoRow(Icons.school, "Institution", "Sairam Institutions"),
                    const Divider(),

                    _infoRow(Icons.gps_fixed, "System", "Real-Time Bus Tracking"),
                    const Divider(),

                    _infoRow(Icons.directions_bus, "Temporary Bus", "Available"),
                    const Divider(),

                    _infoRow(Icons.schedule, "Trip Monitoring", "Morning / Evening"),
                    const Divider(),

                    _infoRow(Icons.notifications_active, "Notifications", "Trip Alerts"),

                  ],
                ),
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

            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  static Widget _infoRow(IconData icon, String title, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),

      child: Row(
        children: [

          Icon(
            icon,
            color: const Color(0xFF00BFA6),
          ),

          const SizedBox(width: 12),

          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                fontSize: 15,
                color: Colors.black54,
              ),
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