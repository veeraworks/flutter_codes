import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'main.dart';
import 'help_page.dart';
import 'student_home_page.dart' hide HelpPage;
import 'package:geolocator/geolocator.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  bool notificationOn = true;

  static const Color primaryColor = Color(0xFF00BFA6);
  static const Color greyIcon = Colors.black54;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F3F7),
      appBar: AppBar(
        backgroundColor: primaryColor,
        title: const Text(
          "Settings",
          style: TextStyle(color: Colors.white),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [

          // ================= ACCOUNT =================
          _sectionTitle("Account"),

          _tile(
            Icons.person,
            "Profile",
            "View your student details",
                () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const ProfilePage(),
                ),
              );
            },
          ),

          const SizedBox(height: 20),

          // ================= PREFERENCES =================
          _sectionTitle("Preferences"),

          Card(
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14)),
            child: SwitchListTile(
              value: notificationOn,
              onChanged: (val) {
                setState(() => notificationOn = val);
              },
              activeColor: primaryColor,
              title: const Text("Notifications"),
              subtitle: const Text("Bus alerts and updates"),
              secondary:
              const Icon(Icons.notifications, color: greyIcon),
            ),
          ),

          const SizedBox(height: 10),

          _tile(
            Icons.location_on_outlined,
            "Location Permission",
            "Manage location access",
                () async {
              await Geolocator.openLocationSettings();
            },
          ),

          const SizedBox(height: 20),

          // ================= SUPPORT =================
          _sectionTitle("Support"),

          _tile(
            Icons.help_outline,
            "Help & Support",
            "Get help using the app",
                () {
              Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => const HelpPage()),
              );
            },
          ),

          _tile(
            Icons.info_outline,
            "About App",
            "BusTrackPro details",
                () {
              Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => const AboutApp()),
              );
            },
          ),

          const SizedBox(height: 20),

          // ================= ACCOUNT ACTIONS =================
          _sectionTitle("Account Actions"),

          _tile(
            Icons.logout,
            "Logout",
            "Sign out from this account",
                () {
              _showLogoutDialog();
            },
            iconColor: Colors.red,
            textColor: Colors.red,
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style:
        const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _tile(
      IconData icon,
      String title,
      String subtitle,
      VoidCallback onTap, {
        Color iconColor = greyIcon,
        Color textColor = Colors.black,
      }) {
    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
      ),
      child: ListTile(
        leading: Icon(icon, color: iconColor),
        title: Text(title, style: TextStyle(color: textColor)),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.arrow_forward_ios,
            size: 16, color: greyIcon),
        onTap: onTap,
      ),
    );
  }

  void _showLogoutDialog() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Logout"),
        content:
        const Text("Are you sure you want to logout?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);

              await FirebaseAuth.instance.signOut();

              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(
                    builder: (_) => const WelcomePage()),
                    (route) => false,
              );
            },
            child: const Text(
              "Logout",
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }
}

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {

  String? name;
  String? regNo;
  String? routeName;
  String? busId;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final prefs = await SharedPreferences.getInstance();

    setState(() {
      name = prefs.getString("studentName") ?? "Not Available";
      regNo = prefs.getString("regNo") ?? "Not Available";
      routeName = prefs.getString("routeName") ?? "Not Assigned";
      busId = prefs.getString("busId") ?? "-";
    });
  }

  Widget _infoTile(String label, String? value) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment:
        MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              color: Colors.black54,
            ),
          ),
          Text(
            value ?? "-",
            style: const TextStyle(
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F3F7),
      appBar: AppBar(
        backgroundColor: const Color(0xFF00BFA6),
        title: const Text(
          "My Profile",
          style: TextStyle(color: Colors.white),
        ),
        iconTheme:
        const IconThemeData(color: Colors.white),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [

            const CircleAvatar(
              radius: 45,
              backgroundColor: Color(0xFF00BFA6),
              child: Icon(Icons.person,
                  size: 50, color: Colors.white),
            ),

            const SizedBox(height: 24),

            _infoTile("Name", name),
            _infoTile("Register No", regNo),
            _infoTile("Route", routeName),
            _infoTile("Bus ID", busId),
          ],
        ),
      ),
    );
  }
}