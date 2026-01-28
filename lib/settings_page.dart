import 'package:flutter/material.dart';
import 'theme_manager.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'main.dart';


class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {

  bool notificationOn = true;
  bool locationOn = true;
  bool darkMode = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F3F7),
      appBar: AppBar(
        backgroundColor: const Color(0xFF00BFA6),
        title: const Text("Settings", style: TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [

          _sectionTitle("Account"),
          _tile(Icons.person, "Profile", "View and edit your profile", () {}),
          _tile(Icons.route, "My Route", "Manage your bus route", () {}),

          const SizedBox(height: 20),

          _sectionTitle("Preferences"),

          SwitchListTile(
            value: notificationOn,
            onChanged: (val) {
              setState(() => notificationOn = val);
            },
            activeColor: const Color(0xFF00BFA6),
            title: const Text("Notifications"),
            subtitle: const Text("Bus alerts and updates"),
            secondary: const Icon(Icons.notifications),
          ),

          SwitchListTile(
            value: locationOn,
            onChanged: (val) {
              setState(() => locationOn = val);
            },
            activeColor: const Color(0xFF00BFA6),
            title: const Text("Live Location"),
            subtitle: const Text("Allow location access"),
            secondary: const Icon(Icons.location_on),
          ),

          SwitchListTile(
            value: darkMode,
            onChanged: (val) {
              setState(() => darkMode = val);
            },
            activeColor: const Color(0xFF00BFA6),
            title: const Text("Dark Mode"),
            subtitle: const Text("Enable dark theme"),
            secondary: const Icon(Icons.dark_mode),
          ),

          const SizedBox(height: 20),

          _sectionTitle("Support"),
          _tile(Icons.help, "Help & Support", "Get help using the app", () {}),
          _tile(Icons.info, "About App", "BusTrackPro details", () {
            Navigator.pop(context);
          }),

          const SizedBox(height: 20),

          _sectionTitle("Account Actions"),
          _tile(Icons.logout, "Logout", "Sign out from this account", () {
            _showLogoutDialog();
          }, color: Colors.red),
        ],
      ),
    );
  }

  Widget _sectionTitle(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(text,
          style: const TextStyle(
              fontSize: 18, fontWeight: FontWeight.bold)),
    );
  }

  Widget _tile(IconData icon, String title, String subtitle, VoidCallback onTap,
      {Color color = Colors.black}) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: ListTile(
        leading: Icon(icon, color: color),
        title: Text(title),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
        onTap: onTap,
      ),
    );
  }

  void _showLogoutDialog() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Logout"),
        content: const Text("Are you sure you want to logout?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);

              // 🔥 FIREBASE LOGOUT
              await FirebaseAuth.instance.signOut();

              // 🔁 Go back to Welcome Page & clear all pages
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (_) => const WelcomePage()),
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
