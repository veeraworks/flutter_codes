import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

import 'driver_profile_page.dart';
import 'driver_settings_page.dart';
import 'issue_reporting_page.dart';

class DriverHomePage extends StatefulWidget {
  const DriverHomePage({super.key});

  @override
  State<DriverHomePage> createState() => _DriverHomePageState();
}

class _DriverHomePageState extends State<DriverHomePage> {
  bool tripStarted = false;

  bool gpsOn = false;
  bool internetOn = false;
  bool locationSyncOn = false;

  @override
  void initState() {
    super.initState();
    _checkStatuses();
  }

  // ---------------- CHECK GPS / INTERNET ----------------

  Future<void> _checkStatuses() async {
    bool gpsEnabled = await Geolocator.isLocationServiceEnabled();
    final connectivity = await Connectivity().checkConnectivity();
    bool netEnabled = connectivity != ConnectivityResult.none;

    setState(() {
      gpsOn = gpsEnabled;
      internetOn = netEnabled;
      locationSyncOn = tripStarted && gpsOn && internetOn;
    });
  }

  // ---------------- START / END TRIP ----------------

  void _toggleTrip() async {
    await _checkStatuses();

    if (!gpsOn) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please enable GPS")),
      );
      await Geolocator.openLocationSettings();
      return;
    }

    if (!internetOn) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please enable Internet")),
      );
      return;
    }

    setState(() {
      tripStarted = !tripStarted;
    });

    await _checkStatuses();
  }

  // ---------------- UI ----------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F3F7),

      // ☰ SIMPLE DRIVER MENU
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [

            // HEADER
            DrawerHeader(
              decoration: const BoxDecoration(
                color: Color(0xFF00BFA6),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  CircleAvatar(
                    radius: 28,
                    backgroundColor: Colors.white,
                    child: Icon(Icons.person, color: Color(0xFF00BFA6)),
                  ),
                  SizedBox(height: 12),
                  Text(
                    "Driver",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),

            // PROFILE
            ListTile(
              leading: const Icon(Icons.person),
              title: const Text("Profile"),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const DriverProfilePage(),
                  ),
                );
              },
            ),

            // ISSUE REPORTING
            ListTile(
              leading: const Icon(Icons.report_problem, color: Colors.red),
              title: const Text("Issue Reporting"),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const IssueReportingPage(),
                  ),
                );
              },
            ),

            // SETTINGS
            ListTile(
              leading: const Icon(Icons.settings),
              title: const Text("Settings"),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const DriverSettingsPage(),
                  ),
                );
              },
            ),
          ],
        ),
      ),

      body: Column(
        children: [

          // HEADER
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(20, 44, 20, 30),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF00BFA6), Color(0xFF00A896)],
              ),
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(28),
                bottomRight: Radius.circular(28),
              ),
            ),
            child: Row(
              children: [
                Builder(
                  builder: (context) => IconButton(
                    icon: const Icon(Icons.menu, color: Colors.white),
                    onPressed: () => Scaffold.of(context).openDrawer(),
                  ),
                ),
                const SizedBox(width: 8),
                const CircleAvatar(
                  radius: 22,
                  backgroundColor: Colors.white,
                  child: Icon(Icons.person, color: Color(0xFF00BFA6)),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Driver Dashboard',
                      style:
                      TextStyle(color: Colors.white, fontSize: 22),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      tripStarted ? 'ON DUTY' : 'OFF DUTY',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // BUS INFO
          _infoCard(
            title: 'Bus Information',
            children: const [
              _infoRow('Route', 'Madambakkam'),
              _infoRow('Bus Number', '9'),
              _infoRow('Shift', 'Morning'),
            ],
          ),

          const SizedBox(height: 16),

          // LOCATION STATUS
          _infoCard(
            title: 'Location Status',
            children: [
              _statusRow('GPS', gpsOn, tripStarted),
              _statusRow('Internet', internetOn, tripStarted),
              _statusRow('Location Sync', locationSyncOn, tripStarted),
            ],
          ),

          const SizedBox(height: 24),

          // START / END TRIP
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: GestureDetector(
              onTap: _toggleTrip,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 18),
                decoration: BoxDecoration(
                  color:
                  tripStarted ? Colors.red : const Color(0xFF00BFA6),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Center(
                  child: Text(
                    tripStarted ? 'End Trip' : 'Start Trip',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ---------------- UI HELPERS ----------------

  Widget _infoCard({
    required String title,
    required List<Widget> children,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        padding: const EdgeInsets.all(16),
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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            ...children,
          ],
        ),
      ),
    );
  }
}

// ---------------- SMALL WIDGETS ----------------

class _infoRow extends StatelessWidget {
  final String label;
  final String value;
  const _infoRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.black54)),
          Text(value,
              style: const TextStyle(fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}

class _statusRow extends StatelessWidget {
  final String label;
  final bool active;
  final bool tripStarted;

  const _statusRow(this.label, this.active, this.tripStarted);

  @override
  Widget build(BuildContext context) {
    IconData icon;
    Color color;
    String text;

    if (!tripStarted) {
      icon = Icons.schedule;
      color = Colors.grey;
      text = "Waiting";
    } else if (active) {
      icon = Icons.check_circle;
      color = Colors.green;
      text = "Active";
    } else {
      icon = Icons.warning;
      color = Colors.red;
      text = "Issue";
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 10),
          Expanded(child: Text(label)),
          Text(
            text,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
