import 'package:flutter/material.dart';

class DriverSettingsPage extends StatefulWidget {
  const DriverSettingsPage({super.key});

  @override
  State<DriverSettingsPage> createState() => _DriverSettingsPageState();
}

class _DriverSettingsPageState extends State<DriverSettingsPage> {
  bool notificationsOn = true;
  bool darkModeOn = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F3F7),
      appBar: AppBar(
        title: const Text("Settings"),
        backgroundColor: const Color(0xFF00BFA6),
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [

          // SETTINGS LIST
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [

                _settingsCard(
                  child: SwitchListTile(
                    value: notificationsOn,
                    title: const Text("Notifications"),
                    subtitle: const Text("Bus alerts & updates"),
                    onChanged: (val) {
                      setState(() => notificationsOn = val);
                    },
                  ),
                ),

                const SizedBox(height: 12),

                _settingsCard(
                  child: SwitchListTile(
                    value: darkModeOn,
                    title: const Text("Dark Mode"),
                    subtitle: const Text("App appearance"),
                    onChanged: (val) {
                      setState(() => darkModeOn = val);
                    },
                  ),
                ),
              ],
            ),
          ),

          // 🚪 LOGOUT BUTTON (BOTTOM)
          Padding(
            padding: const EdgeInsets.all(16),
            child: SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  // FirebaseAuth.instance.signOut();
                },
                icon: const Icon(Icons.logout, color: Colors.white),
                label: const Text(
                  "Logout",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _settingsCard({required Widget child}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
          ),
        ],
      ),
      child: child,
    );
  }
}
