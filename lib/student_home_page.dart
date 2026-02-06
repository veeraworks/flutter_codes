import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'settings_page.dart';
import 'map_page.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'main.dart';
import 'help_page.dart';

class StudentHomePage extends StatefulWidget {
  const StudentHomePage({super.key});

  @override
  State<StudentHomePage> createState() => _StudentHomePageState();
}

class _StudentHomePageState extends State<StudentHomePage> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  int _currentIndex = 0;
  String busStatus = 'arriving';

  // ✅ LOGOUT FUNCTION
  void _logout() {
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
              await FirebaseAuth.instance.signOut();

              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (_) => const WelcomePage()),
                    (route) => false,
              );
            },
            child:
            const Text("Logout", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: const Color(0xFFF6F3F7),

      // ================= DRAWER =================
      drawer: Drawer(
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(20, 50, 20, 20),
              color: const Color(0xFF00BFA6),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    radius: 28,
                    backgroundColor: Colors.white,
                    child: Icon(Icons.person,
                        size: 32, color: Color(0xFF00BFA6)),
                  ),
                  SizedBox(height: 12),
                  Text("VEERA",
                      style: TextStyle(color: Colors.white, fontSize: 20)),
                  Text("Student",
                      style: TextStyle(color: Colors.white70)),
                ],
              ),
            ),

            _drawerItem(Icons.route, "My Route", () {}),

            _drawerItem(Icons.notifications, "Notifications", () {
              Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const NotificationsPage()));
            }),

            _drawerItem(Icons.settings, "Settings", () {
              Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const SettingsPage()));
            }),

            _drawerItem(Icons.info, "About App", () {
              Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const AboutApp()));
            }),

            const Spacer(),

            // ✅ LOGOUT CONNECTED
            _drawerItem(Icons.logout, "Logout", () {
              _logout();
            }),

            const SizedBox(height: 20),
          ],
        ),
      ),

      // ================= BODY =================
      body: SingleChildScrollView(
        child: Column(
          children: [
            // HEADER
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(20, 40, 20, 28),
              decoration: const BoxDecoration(
                color: Color(0xFF00BFA6),
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(24),
                  bottomRight: Radius.circular(24),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      GestureDetector(
                        onTap: () {
                          _scaffoldKey.currentState!.openDrawer();
                        },
                        child: const Icon(Icons.menu, color: Colors.white),
                      ),
                      const Text('BusTrackPro',
                          style:
                          TextStyle(color: Colors.white, fontSize: 20)),
                    ],
                  ),
                  const SizedBox(height: 22),
                  const Text('Welcome, VEERA',
                      style:
                      TextStyle(color: Colors.white, fontSize: 26)),
                  const SizedBox(height: 6),
                  const Text('Route: Madambakkam',
                      style: TextStyle(
                          color: Colors.white70, fontSize: 16)),
                  const SizedBox(height: 2),
                  const Text('Track your bus in real-time',
                      style: TextStyle(
                          color: Colors.white70, fontSize: 16)),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // LIVE BUS STATUS
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Live Bus Status',
                      style: TextStyle(fontSize: 19)),
                  const SizedBox(height: 10),

                  Container(
                    padding: const EdgeInsets.all(14),
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
                    child: Row(
                      children: [
                        Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            color: busStatus == 'arriving'
                                ? Colors.amber
                                : busStatus == 'delayed'
                                ? Colors.orange
                                : Colors.red,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.directions_bus,
                              color: Colors.white),
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: const [
                            Text('Arriving in 5 mins',
                                style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w500)),
                            SizedBox(height: 2),
                            Text('Route: Madambakkam',
                                style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.black87)),
                            SizedBox(height: 2),
                            Text('Last updated 1 min ago',
                                style: TextStyle(
                                    fontSize: 13,
                                    color: Colors.black54)),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 18),

                  // LIVE TRACKING
                  const Text('Live Bus Tracking',
                      style: TextStyle(fontSize: 18)),
                  const SizedBox(height: 10),

                  Container(
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
                      children: [
                        const SizedBox(
                          height: 170,
                          child: GoogleMap(
                            initialCameraPosition: CameraPosition(
                              target: LatLng(13.0827, 80.2707),
                              zoom: 13,
                            ),
                            zoomControlsEnabled: false,
                            myLocationEnabled: true,
                            myLocationButtonEnabled: false,
                          ),
                        ),

                        InkWell(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) => const MapPage()),
                            );
                          },
                          child: Container(
                            width: double.infinity,
                            decoration: const BoxDecoration(
                              color: Color(0xFF3E64FF),
                              borderRadius: BorderRadius.only(
                                bottomLeft: Radius.circular(16),
                                bottomRight: Radius.circular(16),
                              ),
                            ),
                            child: const Padding(
                              padding: EdgeInsets.symmetric(vertical: 12),
                              child: Center(
                                child: Text('Open Map',
                                    style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 16)),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 80),
                ],
              ),
            ),
          ],
        ),
      ),

      // ================= BOTTOM NAV =================
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        selectedItemColor: const Color(0xFF00BFA6),
        unselectedItemColor: Colors.black45,
        type: BottomNavigationBarType.fixed,
        onTap: (index) {
          if (index == 1) {
            Navigator.push(context,
                MaterialPageRoute(builder: (_) => const NotificationsPage()));
          } else if (index == 2) {
            // ✅ HELP PAGE
            Navigator.push(context,
                MaterialPageRoute(builder: (_) => const HelpPage()));
          } else if (index == 3) {
            Navigator.push(context,
                MaterialPageRoute(builder: (_) => const AboutApp()));
          } else {
            setState(() => _currentIndex = index);
          }
        },
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(
              icon: Icon(Icons.notifications), label: 'Notifications'),
          BottomNavigationBarItem(icon: Icon(Icons.help), label: 'Help'),
          BottomNavigationBarItem(icon: Icon(Icons.info), label: 'About'),
        ],
      ),
    );
  }

  Widget _drawerItem(IconData icon, String title, VoidCallback onTap) {
    return ListTile(
      leading: Icon(icon, color: const Color(0xFF00BFA6)),
      title: Text(title, style: const TextStyle(fontSize: 16)),
      onTap: onTap,
    );
  }
}


/* ================= NOTIFICATIONS PAGE ================= */

class NotificationsPage extends StatelessWidget {
  const NotificationsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F3F7),
      appBar: AppBar(
        backgroundColor: const Color(0xFF00BFA6),
        title: const Text('Notifications',
            style: TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: const [
          NotificationCard(
            title: 'Bus Arriving',
            message: 'Your bus will arrive in 5 minutes.',
            time: '1 min ago',
            icon: Icons.directions_bus,
            color: Colors.amber,
          ),
          NotificationCard(
            title: 'Bus Delayed',
            message: 'Bus delayed due to traffic.',
            time: '10 mins ago',
            icon: Icons.warning_amber,
            color: Colors.orange,
          ),
          NotificationCard(
            title: 'Bus Not Arriving',
            message: 'Bus service is not available today.',
            time: 'Today',
            icon: Icons.cancel,
            color: Colors.red,
          ),
        ],
      ),
    );
  }
}

class NotificationCard extends StatelessWidget {
  final String title;
  final String message;
  final String time;
  final IconData icon;
  final Color color;

  const NotificationCard({
    super.key,
    required this.title,
    required this.message,
    required this.time,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                Text(message,
                    style: const TextStyle(
                        fontSize: 14, color: Colors.black87)),
                const SizedBox(height: 6),
                Text(time,
                    style: const TextStyle(
                        fontSize: 12, color: Colors.black54)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/* ================= ABOUT APP PAGE ================= */

class AboutApp extends StatelessWidget {
  const AboutApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F3F7),
      appBar: AppBar(
        backgroundColor: const Color(0xFF00BFA6),
        title: const Text('About BusTrackPro',
            style: TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            _infoCard(
              title: 'BusTrackPro',
              content: 'Smart College Bus Tracking System',
              big: true,
            ),

            const SizedBox(height: 20),

            _infoCard(
              content:
              'BusTrackPro is a smart and user-friendly college bus tracking application designed to help students track their buses in real time.\n\n'
                  'The app reduces waiting time, improves safety, and provides live bus updates such as arrival time, delay status, and bus availability.\n\n'
                  'BusTrackPro aims to create a reliable and stress-free daily travel experience for students and staff.',
            ),

            const SizedBox(height: 20),

            _infoCard(
              title: 'App Information',
              content:
              'Version: 1.0.0\nStatus: Active\nDeveloped for: College Students\nPlatform: Android',
              highlight: true,
            ),
          ],
        ),
      ),
    );
  }
}

Widget _infoCard({
  String? title,
  required String content,
  bool big = false,
  bool highlight = false,
}) {
  return Container(
    width: double.infinity,
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: highlight ? const Color(0xFFE0F7F3) : Colors.white,
      borderRadius: BorderRadius.circular(16),
      boxShadow: highlight
          ? null
          : [
        BoxShadow(
          color: Colors.black.withOpacity(0.05),
          blurRadius: 10,
        ),
      ],
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (title != null)
          Text(
            title,
            style: TextStyle(
              fontSize: big ? 26 : 17,
              fontWeight: FontWeight.bold,
              color: const Color(0xFF00BFA6),
            ),
          ),
        if (title != null) const SizedBox(height: 8),
        Text(content,
            style: const TextStyle(fontSize: 15, height: 1.6)),
      ],
    ),
  );
}
