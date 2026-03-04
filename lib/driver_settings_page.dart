import 'package:flutter/material.dart';
import 'package:project_spt/main.dart';
import 'driver_about_app_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

class DriverSettingsPage extends StatefulWidget {
  const DriverSettingsPage({super.key});

  @override
  State<DriverSettingsPage> createState() => _DriverSettingsPageState();
}

class _DriverSettingsPageState extends State<DriverSettingsPage> {
  bool notificationsOn = true;
  bool isTripActive = false;
  String trackingStatus = "Inactive";

  // ================= INIT =================

  @override
  void initState() {
    super.initState();
    _loadTrackingStatus();
  }

  // ✅ refresh when page re-opened
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _loadTrackingStatus();
  }

  // ================= LOAD STATUS =================

  Future<void> _loadTrackingStatus() async {
    final prefs = await SharedPreferences.getInstance();

    final bool isActive = prefs.getBool("trackingActive") ?? false;

    setState(() {
      trackingStatus = isActive ? "Active" : "Inactive";
      isTripActive = isActive;
      notificationsOn = prefs.getBool("notificationsOn") ?? true;
    });
  }

  // ================= LOGOUT =================

  Future<void> _logout() async {
    final prefs = await SharedPreferences.getInstance();
    final bool isTracking = prefs.getBool("trackingActive") ?? false;

    // 🚫 BLOCK logout if trip running
    if (isTracking) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("End Trip before logging out"),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // ✅ Clear session
    await prefs.clear();

    if (!mounted) return;

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const WelcomePage()),
          (route) => false,
    );
  }

  // ================= UI =================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Settings"),
        backgroundColor: const Color(0xFF00BFA6),
        foregroundColor: Colors.white,
      ),
      backgroundColor: const Color(0xFFF6F3F7),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [

          /// ================= NOTIFICATIONS =================
          _sectionCard(
            children: [
              SwitchListTile(
                value: notificationsOn,
                title: const Text("Notifications"),
                subtitle: const Text("Bus alerts & updates"),
                onChanged: (v) async {
                  final prefs =
                  await SharedPreferences.getInstance();

                  setState(() => notificationsOn = v);
                  await prefs.setBool("notificationsOn", v);
                },
              ),
            ],
          ),

          const SizedBox(height: 12),

          /// ================= TRACKING STATUS =================
          _sectionCard(
            children: [
              _readOnlyTile(
                icon: Icons.location_on,
                title: "Tracking Status",
                value: trackingStatus,
                valueColor: trackingStatus == "Active"
                    ? Colors.green
                    : Colors.red,
              ),
            ],
          ),

          const SizedBox(height: 12),

          /// ================= APP INFO =================
          _sectionCard(
            children: [
              ListTile(
                leading: const Icon(Icons.info_outline),
                title: const Text("App Info"),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const AboutAppPage(),
                    ),
                  );
                },
              ),
            ],
          ),

          const SizedBox(height: 24),

          /// ================= LOGOUT BUTTON =================
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: isTripActive ? null : _logout,
              style: ElevatedButton.styleFrom(
                backgroundColor:
                isTripActive ? Colors.grey : Colors.red,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: const Text(
                "LOGOUT",
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ================= UI HELPERS =================

  Widget _sectionCard({required List<Widget> children}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(children: children),
    );
  }

  Widget _readOnlyTile({
    required IconData icon,
    required String title,
    required String value,
    Color valueColor = Colors.black,
  }) {
    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      trailing: Text(
        value,
        style: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: valueColor,
        ),
      ),
    );
  }
}