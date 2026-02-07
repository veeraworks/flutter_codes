import 'package:flutter/material.dart';
import 'driver_about_app_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

class DriverSettingsPage extends StatefulWidget {
  const DriverSettingsPage({super.key});

  @override
  State<DriverSettingsPage> createState() => _DriverSettingsPageState();
}

class _DriverSettingsPageState extends State<DriverSettingsPage> {
  bool notificationsOn = true;
  String trackingStatus = "Inactive";

  @override
  void initState() {
    super.initState();
    _loadTrackingStatus();
  }

  Future<void> _loadTrackingStatus() async {
    final prefs = await SharedPreferences.getInstance();
    final bool isActive = prefs.getBool("trackingActive") ?? false;

    setState(() {
      trackingStatus = isActive ? "Active" : "Inactive";
    });
  }

  void _logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();

    if (!mounted) return;
    Navigator.pop(context);
  }

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
          _sectionCard(
            children: [
              SwitchListTile(
                value: notificationsOn,
                onChanged: (v) {
                  setState(() => notificationsOn = v);
                },
                title: const Text("Notifications"),
                subtitle: const Text("Bus alerts & updates"),
              ),
            ],
          ),

          const SizedBox(height: 12),

          _sectionCard(
            children: [
              _readOnlyTile(
                icon: Icons.location_on,
                title: "Tracking Status",
                value: trackingStatus,
                valueColor:
                trackingStatus == "Active" ? Colors.green : Colors.red,
              ),
            ],
          ),

          const SizedBox(height: 12),

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

          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: _logout,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
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
          )
        ],
      ),
    );
  }

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

  void _showAppInfo(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: const [
            Text(
              "Smart Bus Tracking",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Text("Version 1.0.0"),
            SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}
