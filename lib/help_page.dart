import 'package:flutter/material.dart';

class HelpPage extends StatelessWidget {
  const HelpPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Help & Support"),
        backgroundColor: const Color(0xFF00BFA6),
        foregroundColor: Colors.white,
      ),

      backgroundColor: const Color(0xFFF6F3F7),

      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [

            /// HEADER TEXT
            const Text(
              "Frequently Asked Questions",
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 6),

            const Text(
              "Find answers to common questions about bus tracking and app usage.",
              style: TextStyle(
                color: Colors.black54,
                fontSize: 14,
              ),
            ),

            const SizedBox(height: 20),

            _helpTile(
              icon: Icons.location_on,
              title: "How to track my bus?",
              content:
              "Open the Home Page and view the Live Map to see your assigned bus location in real-time.",
            ),

            _helpTile(
              icon: Icons.play_arrow,
              title: "When does tracking start?",
              content:
              "Tracking begins when the driver starts the Morning or Evening trip from the driver app.",
            ),

            _helpTile(
              icon: Icons.directions_bus,
              title: "Bus not moving?",
              content:
              "If the driver has not started the trip yet, the bus location will not update.",
            ),

            _helpTile(
              icon: Icons.gps_off,
              title: "Live location not updating?",
              content:
              "Live tracking works only when the driver's GPS and internet connection are enabled.",
            ),

            _helpTile(
              icon: Icons.swap_horiz,
              title: "Temporary Bus Change?",
              content:
              "Sometimes the assigned bus may be replaced temporarily. Always check the Live Map for the updated bus.",
            ),

            _helpTile(
              icon: Icons.cloud_off,
              title: "Bus showing offline?",
              content:
              "Bus appears offline if the driver has not started the trip or if GPS is turned off.",
            ),

            _helpTile(
              icon: Icons.access_time,
              title: "Bus delayed?",
              content:
              "Check the live map to see the current position of the bus and estimate arrival time.",
            ),

            _helpTile(
              icon: Icons.cancel,
              title: "Bus not arriving?",
              content:
              "If the trip has not started or has already ended, the bus will not appear on the map.",
            ),

            const SizedBox(height: 24),

            /// CONTACT SUPPORT
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.08),
                    blurRadius: 10,
                  )
                ],
              ),
              child: Column(
                children: const [

                  Icon(
                    Icons.support_agent,
                    size: 40,
                    color: Color(0xFF00BFA6),
                  ),

                  SizedBox(height: 10),

                  Text(
                    "Need More Help?",
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  SizedBox(height: 6),

                  Text(
                    "Contact your institution transport office for further assistance.",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.black54,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),

          ],
        ),
      ),
    );
  }

  // ================= HELP TILE =================
  Widget _helpTile({
    required IconData icon,
    required String title,
    required String content,
  }) {

    return Container(
      margin: const EdgeInsets.only(bottom: 14),

      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 10,
          ),
        ],
      ),

      child: ExpansionTile(
        maintainState: true,
        tilePadding: const EdgeInsets.symmetric(horizontal: 16),

        leading: Icon(
          icon,
          color: const Color(0xFF00BFA6),
        ),

        collapsedIconColor: const Color(0xFF00BFA6),
        iconColor: const Color(0xFF00BFA6),

        title: Text(
          title,
          style: const TextStyle(
            color: Color(0xFF00BFA6),
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),

        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),

        children: [
          Text(
            content,
            style: const TextStyle(
              color: Colors.black87,
              fontSize: 15,
              height: 1.5,
            ),
          )
        ],
      ),
    );
  }
}