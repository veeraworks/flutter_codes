import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'settings_page.dart';
import 'map_page.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'main.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:geolocator/geolocator.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:shared_preferences/shared_preferences.dart';

class StudentHomePage extends StatefulWidget {
  const StudentHomePage({super.key});

  @override
  State<StudentHomePage> createState() => _StudentHomePageState();
}

class _StudentHomePageState extends State<StudentHomePage> {
  String? studentName;
  String? routeName;
  String? displayRoute;
  String? activeIssue;
  String? tempBus;
  String? busId;
  StreamSubscription<DatabaseEvent>? _issueListener;
  StreamSubscription<DatabaseEvent>? _tempBusListener;
  StreamSubscription<DatabaseEvent>? _busListener;
  String lastUpdatedText = "Just now";

  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  int _currentIndex = 0;
  double? _etaMinutes;

  int unreadCount = 0;
  StreamSubscription? _notificationListener;

  String? _prevTempRoute; // track previous temp route to avoid duplicate snackbars

  @override
  void initState() {
    super.initState();

    _refreshStudentProfile();
    _requestPermission();
    _listenForMessages();

    _loadStudentInfo().then((_) async {
      print(" Student Bus ID: $busId");

      if (busId != null) {
        print(" Subscribing to topic: ${busId!.toLowerCase()}");
        await _subscribeToRoute();
      } else {
        print(" busId still NULL after loading!");
      }
    });

    _listenToNotifications();
    _listenToBusIssues();
    _listenToBus();
    _listenToTemporaryBus();
  }

  @override
  void dispose() {
    _issueListener?.cancel();
    _busListener?.cancel();
    _tempBusListener?.cancel();
    _notificationListener?.cancel();
    super.dispose();
  }

  Future<void> _refreshStudentProfile() async {
    final prefs = await SharedPreferences.getInstance();
    final regNo = prefs.getString("regNo");

    if (regNo == null) return;

    final oldBusId = prefs.getString("busId");
    final response = await http.get(
      Uri.parse("https://null-sheldon-unstudded.ngrok-free.dev/students/profile?regNo=$regNo"),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final newBusId = data["busId"];

      // 🔥 If bus changed → unsubscribe old topic
      if (oldBusId != null && oldBusId != newBusId) {
        await FirebaseMessaging.instance
            .unsubscribeFromTopic(oldBusId.toLowerCase());
      }

      // 🔥 Subscribe new topic
      await FirebaseMessaging.instance
          .subscribeToTopic(newBusId.toLowerCase());

      await prefs.setString("busId", newBusId);
      await prefs.setString("routeName", data["busName"]);
      await prefs.setString("studentName", data["name"]);

      setState(() {
        studentName = data["name"];
        routeName = data["busName"];
        displayRoute = data["busName"];
        busId = newBusId;
      });
    }
  }

  Future<void> _subscribeToRoute() async {
    final prefs = await SharedPreferences.getInstance();
    final busId = prefs.getString("busId");

    if (busId != null && busId.isNotEmpty) {

      print("🔥 Subscribing NOW to topic: ${busId.toLowerCase()}");

      await FirebaseMessaging.instance
          .subscribeToTopic(busId.toLowerCase());

      print("✅ Subscribed successfully!");
    } else {
      print("❌ busId is NULL or empty!");
    }

    String? token = await FirebaseMessaging.instance.getToken();
    print("🔥 FCM TOKEN: $token");
  }

  Future<void> _requestPermission() async {
    NotificationSettings settings =
    await FirebaseMessaging.instance.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    print("Permission status: ${settings.authorizationStatus}");
  }

  void _listenForMessages() {

    FirebaseMessaging.onMessage.listen((RemoteMessage message) async {

      print("🔔 Notification Received!");

      final prefs = await SharedPreferences.getInstance();
      final regNo = prefs.getString("regNo");

      if (regNo == null) return;

      String title =
          message.data['title'] ??
              message.notification?.title ??
              "Notification";

      String body =
          message.data['body'] ??
              message.notification?.body ??
              "";

      // Snackbar (foreground only)
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("$title\n$body")),
        );
      }
    });
  }

  Future<void> _listenToNotifications() async {
    final prefs = await SharedPreferences.getInstance();
    final regNo = prefs.getString("regNo");
    if (regNo == null) return;

    _notificationListener = FirebaseDatabase.instance
        .ref("notifications/$regNo")
        .onValue
        .listen((event) {

      final data = event.snapshot.value;

      if (data == null) {
        setState(() => unreadCount = 0);
        return;
      }

      final Map<String, dynamic> map =
      Map<String, dynamic>.from(data as Map);

      int count = 0;

      map.forEach((key, value) {
        final notif = Map<String, dynamic>.from(value);
        if (notif["read"] == false) {
          count++;
        }
      });

      setState(() {
        unreadCount = count;
      });
    });
  }

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

              // 🔥 Clear SharedPreferences session
              final prefs = await SharedPreferences.getInstance();
              await prefs.clear();

              // 🔥 Optional: Firebase sign out (safe to keep)
              await FirebaseAuth.instance.signOut();

              // 🔥 Navigate & remove back stack
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
  //=================Temporary Bus Change Listener==================
  Future<void> _listenToTemporaryBus() async {
    final prefs = await SharedPreferences.getInstance();
    final String? originalBusId = prefs.getString("busId");

    if (originalBusId == null) {
      print("❌ busId is NULL — cannot listen to temp bus");
      return;
    }

    print("👂 Listening to temporaryBusChanges/${originalBusId.toUpperCase()}");

    _tempBusListener = FirebaseDatabase.instance
        .ref("temporaryBusChanges/${originalBusId.toUpperCase()}")
        .onValue
        .listen((event) async {

      final data = event.snapshot.value as Map?;

      if (data != null && data["status"] == "ACTIVE") {

        final String? newBus = data["newBus"];
        final String? tempRoute = data["tempRoute"];

        print("🚍 TEMP BUS ACTIVE");
        print("Unsubscribing from: ${originalBusId.toLowerCase()}");
        print("Subscribing to temp bus: ${newBus?.toLowerCase()}");

        // 🔥 Unsubscribe from original topic
        await FirebaseMessaging.instance
            .unsubscribeFromTopic(originalBusId.toLowerCase());

        // 🔥 Subscribe to temporary topic
        if (newBus != null) {
          await FirebaseMessaging.instance
              .subscribeToTopic(newBus.toLowerCase());
        }

        setState(() {
          tempBus = newBus;
          displayRoute = tempRoute ?? routeName;
        });

      } else {

        print("🔄 TEMP BUS CLEARED");

        // 🔥 Unsubscribe from temp topic
        if (tempBus != null) {
          print("Unsubscribing from temp bus: ${tempBus!.toLowerCase()}");
          await FirebaseMessaging.instance
              .unsubscribeFromTopic(tempBus!.toLowerCase());
        }

        // 🔥 Subscribe back to original topic
        print("Subscribing back to: ${originalBusId.toLowerCase()}");
        await FirebaseMessaging.instance
            .subscribeToTopic(originalBusId.toLowerCase());

        setState(() {
          tempBus = null;
          displayRoute = routeName;
        });
      }
    });
  }

  Future<void> _listenToBus() async {
    final prefs = await SharedPreferences.getInstance();
    String? busId = prefs.getString("busId");

    if (busId == null) return;

    _busListener = FirebaseDatabase.instance
        .ref("buses/$busId/current")
        .onValue
        .listen((event) async {

      final data = event.snapshot.value;

      if (data == null) {
        setState(() {
          _etaMinutes = null;
        });
        return;
      }
      final map = Map<String, dynamic>.from(data as Map);
      if (!map.containsKey("lat") || !map.containsKey("lng")) {
        setState(() {
          _etaMinutes = null;   // No trip → No ETA
        });
        return;
      }

      double lat = map["lat"];
      double lng = map["lng"];

      // Get student location
      Position position = await Geolocator.getCurrentPosition();

      double distance = Geolocator.distanceBetween(
        lat,
        lng,
        position.latitude,
        position.longitude,
      );

      if (distance < 50) {
        setState(() {
          _etaMinutes = 0;
        });
      } else if (distance < 300) {
        setState(() {
          _etaMinutes = -1;
        });
      } else {
        double speed = 30 * 1000 / 3600;
        double time = distance / speed;

        setState(() {
          _etaMinutes = (time / 60).ceilToDouble();
        });
      }
    });
  }

  //ISSUE REPORTING BY BUS ALERT
  Future<void> _listenToBusIssues() async {
    final prefs = await SharedPreferences.getInstance();
    final busId = prefs.getString("busId");

    if (busId == null) return;

    _issueListener = FirebaseDatabase.instance
        .ref("busIssues/$busId")
        .onValue
        .listen((event) {

      final data = event.snapshot.value;

      if (data == null) {
        setState(() {
          activeIssue = null;
        });
        return;
      }

      final map = Map<String, dynamic>.from(data as Map);

      if (map["status"] == "ACTIVE") {
        setState(() {
          activeIssue = map["issueType"];
        });
      } else {
        setState(() {
          activeIssue = null;
        });
      }
    });
  }

  //LOAD STUDENT INFO
  Future<void> _loadStudentInfo() async {
    final prefs = await SharedPreferences.getInstance();

    setState(() {
      studentName = prefs.getString("studentName") ?? "-";
      routeName = prefs.getString("routeName");

      // 🔥 LOAD DISPLAY ROUTE (temp if active, otherwise permanent)
      displayRoute = routeName;
    });
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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    radius: 28,
                    backgroundColor: Colors.white,
                    child: Icon(Icons.person,
                        size: 32, color: Color(0xFF00BFA6)),
                  ),
                  SizedBox(height: 12),
                  Text(
                    studentName ?? "Student",
                    style: const TextStyle(color: Colors.white, fontSize: 20),
                  ),
                  Text("Student",
                      style: TextStyle(color: Colors.white70)),
                ],
              ),
            ),

            _drawerItem(Icons.map, "Live Map", () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const MapPage()),
              );
            }),

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
            if (tempBus != null)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                color: Colors.orange,
                child: Text(
                  "Temporary Bus Active: $tempBus",
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
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

                  Text(
                    'Welcome, ${studentName ?? "Student"}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 26,
                    ),
                  ),

                  const SizedBox(height: 6),

                  // 🔥 SHOW ACTUAL ROUTE NAME
                  Text(
                    'Route: ${displayRoute ?? "Not Assigned"}',
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 16,
                    ),
                  ),

                  const SizedBox(height: 2),

                  const Text(
                    'Track your bus in real-time',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 16,
                    ),
                  ),

                ],
              ),
            ),

            const SizedBox(height: 16),

            //Issue Reporting by Driver
            if (activeIssue != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.red),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.warning, color: Colors.red),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          "ALERT: $activeIssue",
                          style: const TextStyle(
                            color: Colors.red,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

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
                            color: _etaMinutes == 0
                                ? Colors.green
                                : _etaMinutes == -1
                                ? Colors.orange
                                : Colors.amber,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.directions_bus,
                              color: Colors.white),
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _etaMinutes == null
                                  ? "Calculating..."
                                  : _etaMinutes == 0
                                  ? "🟢 Bus has arrived!"
                                  : _etaMinutes == -1
                                  ? "🟠 Bus is nearby"
                                  : "🚌 Arriving in ${_etaMinutes!.toInt()} mins",
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: _etaMinutes == 0
                                    ? Colors.green
                                    : _etaMinutes == -1
                                    ? Colors.orange
                                    : Colors.black87,
                              ),
                            ),

                            const SizedBox(height: 6),

                            // 🔥 ROUTE INFO
                            Row(
                              children: [
                                const Icon(Icons.route, size: 16, color: Colors.black54),
                                const SizedBox(width: 6),
                                Text(
                                  'Route: ${displayRoute ?? routeName ?? "Not Assigned"}',
                                  style: const TextStyle(
                                    fontSize: 14,
                                    color: Colors.black87,
                                  ),
                                ),
                              ],
                            ),

                            const SizedBox(height: 4),
                            Row(
                              children: const [
                                Icon(Icons.access_time, size: 14, color: Colors.black45),
                                SizedBox(width: 6),
                                Text(
                                  'Live tracking active',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Colors.black54,
                                  ),
                                ),
                              ],
                            ),
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
            Navigator.push(context,
                MaterialPageRoute(builder: (_) => const HelpPage()));
          } else if (index == 3) {
            Navigator.push(context,
                MaterialPageRoute(builder: (_) => const AboutApp()));
          } else {
            setState(() => _currentIndex = index);
          }
        },
        items: [
          const BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          // 🔴 NOTIFICATION WITH BADGE
          BottomNavigationBarItem(
            icon: Stack(
              children: [
                const Icon(Icons.notifications),

                if (unreadCount > 0)
                  Positioned(
                    right: 0,
                    top: 0,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                      ),
                      constraints: const BoxConstraints(
                        minWidth: 16,
                        minHeight: 16,
                      ),
                      child: Text(
                        unreadCount.toString(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
              ],
            ),
            label: 'Notifications',
          ),
          const BottomNavigationBarItem(icon: Icon(Icons.help), label: 'Help'),
          const BottomNavigationBarItem(icon: Icon(Icons.info), label: 'About'),
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
class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key});

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {

  String? regNo;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    await _loadRegNo();

    if (regNo != null) {
      await _markAllAsRead();
    }
  }

  Future<void> _loadRegNo() async {
    final prefs = await SharedPreferences.getInstance();
    final savedRegNo = prefs.getString("regNo");

    print("REGNO FROM PREFS = $savedRegNo");

    if (savedRegNo == null) {
      Future.delayed(Duration.zero, () {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const WelcomePage()),
              (route) => false,
        );
      });
      return;
    }

    setState(() {
      regNo = savedRegNo;
    });
  }

  Future<void> _markAllAsRead() async {
    final prefs = await SharedPreferences.getInstance();
    final regNo = prefs.getString("regNo");

    if (regNo == null) return;

    final snapshot = await FirebaseDatabase.instance
        .ref("notifications/$regNo")
        .get();

    if (!snapshot.exists) return;

    final data = Map<String, dynamic>.from(snapshot.value as Map);

    for (var key in data.keys) {
      await FirebaseDatabase.instance
          .ref("notifications/$regNo/$key")
          .update({"read": true});
    }
  }

  String formatTime(int timestamp) {
    final now = DateTime.now();
    final date = DateTime.fromMillisecondsSinceEpoch(timestamp);
    final difference = now.difference(date);

    if (difference.inMinutes < 1) return "Just now";
    if (difference.inMinutes < 60)
      return "${difference.inMinutes} mins ago";
    if (difference.inHours < 24)
      return "${difference.inHours} hrs ago";
    return "${difference.inDays} days ago";
  }

  @override
  Widget build(BuildContext context) {
    if (regNo == null) {
      return const Scaffold(
        body: Center(child: Text("Session missing. Please login again.")),
      );
    }
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF00BFA6),
        title: const Text(
          "Notifications",
          style: TextStyle(color: Colors.white),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: StreamBuilder(
        stream: FirebaseDatabase.instance
            .ref("notifications/$regNo")
            .onValue,
        builder: (context, snapshot) {
          if (!snapshot.hasData || snapshot.data!.snapshot.value == null) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  Icon(Icons.notifications_off,
                      size: 60, color: Colors.grey),
                  SizedBox(height: 12),
                  Text(
                    "No notifications yet",
                    style: TextStyle(fontSize: 16, color: Colors.grey),
                  ),
                ],
              ),
            );
          }

          final data = Map<String, dynamic>.from(
              snapshot.data!.snapshot.value as Map);

          // 🔥 SORT KEYS BY TIMESTAMP DESC
          final keys = data.keys.toList()
            ..sort((a, b) =>
                data[b]["timestamp"].compareTo(data[a]["timestamp"]));

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: keys.length,
            itemBuilder: (context, index) {
              final notificationId = keys[index];
              final item = data[notificationId];

              return Dismissible(
                key: Key(notificationId),
                direction: DismissDirection.endToStart,
                background: Container(
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.only(right: 20),
                  color: Colors.red,
                  child: const Icon(Icons.delete, color: Colors.white),
                ),
                onDismissed: (_) async {
                  await FirebaseDatabase.instance
                      .ref("notifications/$regNo/$notificationId")
                      .remove();
                },
                child: GestureDetector(
                  onTap: () {
                    FirebaseDatabase.instance
                        .ref("notifications/$regNo/$notificationId/read")
                        .set(true);
                  },
                  child: NotificationCard(
                    title: item["title"] ?? "",
                    message: item["body"] ?? "",
                    time: formatTime(item["timestamp"]),
                    icon: Icons.notifications,
                    color: Colors.blue,
                    isRead: item["read"] == true,
                  ),
                ),
              );
            },
          );
        },
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
  final bool isRead;

  const NotificationCard({
    super.key,
    required this.title,
    required this.message,
    required this.time,
    required this.icon,
    required this.color,
    required this.isRead,
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
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
          ),
        ],
      ),
      child:Row(
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
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight:
                          isRead ? FontWeight.w500 : FontWeight.w700,
                          color: Colors.black,
                        ),
                      ),
                    ),

                    if (!isRead)
                      Container(
                        width: 8,
                        height: 8,
                        margin: const EdgeInsets.only(left: 6),
                        decoration: const BoxDecoration(
                          color: Colors.blue,
                          shape: BoxShape.circle,
                        ),
                      ),
                  ],
                ),

                const SizedBox(height: 4),

                Text(
                  message,
                  style: const TextStyle(
                    fontSize: 14,
                    color: Colors.black87,
                  ),
                ),

                const SizedBox(height: 6),

                Text(
                  time,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.black54,
                  ),
                ),
              ],
            ),
          ),
        ],
      )
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
              'Version: 1.0.0\nStatus: Active\nDeveloped by: Sairam Instituition\nPlatform: Android',
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
// ================= HELP & SUPPORT PAGE =================
class HelpPage extends StatelessWidget {
  const HelpPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F3F7),
      appBar: AppBar(
        backgroundColor: const Color(0xFF00BFA6),
        elevation: 0,
        title: const Text(
          'Help & Support',
          style: TextStyle(color: Colors.white),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [

            // 🔷 HOW TO USE
            _infoCard(
              title: "How to Track Your Bus",
              content:
              "1. Open the Home page.\n"
                  "2. View Live Bus Status.\n"
                  "3. Tap 'Open Map' for full tracking.\n"
                  "4. Check ETA and bus arrival updates.",
            ),
            const SizedBox(height: 20),

            // 🔷 COMMON ISSUES
            _infoCard(
              title: "Common Issues",
              content:
              "• Bus not updating → Check internet.\n"
                  "• Location not working → Enable GPS.\n"
                  "• No notifications → Enable notification permission.",
            ),
            const SizedBox(height: 20),

            // 🔷 CONTACT
            _infoCard(
              title: "Contact Support",
              content:
              "For technical issues :\n\n"
                  "Email: support@bustrackpro.com\n"
                  "Phone: +91 9876543210",
            ),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }
}
