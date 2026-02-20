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
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [

          _helpTile(
            icon: Icons.location_on,
            title: "How to track my bus?",
            content:
            "Go to Home Page and open the Live Map to see your assigned bus location in real-time.",
          ),

          _helpTile(
            icon: Icons.play_arrow,
            title: "When does tracking start?",
            content:
            "Tracking starts only when the driver begins the Morning or Evening trip from their app.",
          ),

          _helpTile(
            icon: Icons.directions_bus,
            title: "Bus not moving?",
            content:
            "Tracking works only when the driver starts the trip. If the trip has not started yet, the bus location will not update.",
          ),

          _helpTile(
            icon: Icons.gps_off,
            title: "Live location not updating?",
            content:
            "Live location updates only when the driver's GPS and internet are enabled during the trip.",
          ),

          _helpTile(
            icon: Icons.swap_horiz,
            title: "Temporary Bus Change?",
            content:
            "Sometimes your bus may be replaced temporarily. Always check the Live Map for the updated bus location.",
          ),

          _helpTile(
            icon: Icons.cloud_off,
            title: "Bus showing offline?",
            content:
            "Bus will appear offline if the driver has not started the trip or if GPS is turned off.",
          ),

          _helpTile(
            icon: Icons.access_time,
            title: "Bus delayed?",
            content:
            "If the bus is delayed, you can check its live position on the map for updated arrival time.",
          ),

          _helpTile(
            icon: Icons.cancel,
            title: "Bus not arriving?",
            content:
            "If the trip has not started or has ended, the bus may not appear on the map.",
          ),
        ],
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
      margin: const EdgeInsets.only(bottom: 16),
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
        leading: Icon(icon, color: const Color(0xFF00BFA6)),
        collapsedIconColor: const Color(0xFF00BFA6),
        iconColor: const Color(0xFF00BFA6),
        title: Text(
          title,
          style: const TextStyle(
            color: Color(0xFF00BFA6),
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        childrenPadding:
        const EdgeInsets.fromLTRB(16, 0, 16, 16),
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