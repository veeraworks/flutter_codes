import 'package:flutter/material.dart';

class HelpPage extends StatelessWidget {
  const HelpPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Help & Support"),
        backgroundColor: const Color(0xFF00BFA6),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [

          _helpTile(
            icon: Icons.location_on,
            title: "How to track my bus?",
            content:
            "Go to Home page and click 'Open Map' to see your bus live location.",
          ),

          _helpTile(
            icon: Icons.access_time,
            title: "Bus delayed?",
            content:
            "If the bus is delayed, you will see live status update and also receive notifications.",
          ),

          _helpTile(
            icon: Icons.cancel,
            title: "Bus not arriving?",
            content:
            "If service is cancelled, the app will show 'Bus not arriving' in Live Bus Status.",
          ),

          _helpTile(
            icon: Icons.report_problem,
            title: "Report an issue",
            content:
            "If you face any problem, contact your college transport office.",
          ),
        ],
      ),
    );
  }

  // ✅ White box, teal title, black content
  Widget _helpTile({
    required IconData icon,
    required String title,
    required String content,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white, // ✅ white box
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
            color: Color(0xFF00BFA6), // ✅ teal text
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
              color: Colors.black87, // ✅ black answer
              fontSize: 15,
              height: 1.5,
            ),
          )
        ],
      ),
    );
  }
}
