import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:project_spt/student_map_page.dart';
import 'settings_page.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'main.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'service/api_service.dart';
import 'help_page.dart';
import 'about_page.dart';
import 'package:geolocator/geolocator.dart';
import 'utils/app_logger.dart';

class StudentHomePage extends StatefulWidget {
  const StudentHomePage({super.key});

  @override
  State<StudentHomePage> createState() => _StudentHomePageState();
}

class _StudentHomePageState extends State<StudentHomePage>
    with SingleTickerProviderStateMixin {
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
  bool _locationPermissionGranted = false;
  int unreadCount = 0;
  StreamSubscription? _notificationListener;
  LatLng? _busLocation;
  bool _busActive = false;
  LatLng _studentLocation = const LatLng(13.0827, 80.2707);
  Set<Marker> _miniMarkers = {};
  Set<Polyline> _miniPolylines = {};
  GoogleMapController? _miniMapController;
  List<LatLng> _routePoints = [];
  late AnimationController _animController;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;
  @override
  void initState() {
    super.initState();
    _initLocationPermission();
    _getStudentLocation();  // 👈 ADD THIS
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );

    _fadeAnim = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOut,
    );

    _slideAnim = Tween<Offset>(
      begin: const Offset(0, -0.15),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _animController,
        curve: Curves.easeOutCubic,
      ),
    );

    _animController.forward();
    _loadActiveIssue();
    Future.delayed(const Duration(milliseconds: 300), () {
      _initializeStudent();
    });
  }
  Future<void> fetchRemainingRoute() async {

    if (busId == null) return;

    final response = await ApiService.get(
      "/routes/remaining/$busId",
    );

    if (response.statusCode == 200) {

      final data = jsonDecode(response.body);

      final busLocation = data["busLocation"];
      final remainingStops = data["remainingStops"];

      List<LatLng> points = [];

      // start from bus
      points.add(
          LatLng(busLocation["lat"], busLocation["lng"])
      );

      for (var stop in remainingStops) {
        points.add(
            LatLng(stop["lat"], stop["lng"])
        );
      }

      setState(() {

        _miniPolylines = {
          Polyline(
            polylineId: const PolylineId("remainingRoute"),
            color: Colors.blue,
            width: 5,
            points: points,
          )
        };

      });
    }
  }

  Future<void> _initializeStudent() async {

    // Load fresh profile from backend
    await _refreshStudentProfile();

    //  Load student info into state
    await _loadStudentInfo();

    await _requestPermission();
    if (busId != null) {
      await _loadRoutePolyline(busId!);
      await fetchRemainingRoute();
      _listenToEta();
    }
    // Attach listeners
    _listenForMessages();
    _listenToNotifications();
    _listenToBusIssues();
    _listenToBus();
    _listenToTemporaryBus();

  }
  Future<void> _initLocationPermission() async {
    try {
      final permission = await Geolocator.requestPermission();

      if (permission == LocationPermission.always ||
          permission == LocationPermission.whileInUse) {
        setState(() {
          _locationPermissionGranted = true;
        });
      }
    } catch (e) {
      appLog("Location permission error: $e");
    }
  }
  Future<void> _loadRoutePolyline(String busId) async {

    final snapshot = await FirebaseDatabase.instance
        .ref("busRoutes/$busId/fullRoadPolyline")
        .get();

    if (!snapshot.exists) return;

    String encodedPolyline = snapshot.value.toString();

    PolylinePoints polylinePoints = PolylinePoints();

    List<PointLatLng> decoded =
    polylinePoints.decodePolyline(encodedPolyline);

    List<LatLng> points =
    decoded.map((p) => LatLng(p.latitude, p.longitude)).toList();

    setState(() {
      _routePoints = points;

      _miniPolylines = {
        Polyline(
          polylineId: const PolylineId("route"),
          points: _routePoints,
          width: 5,
          color: Colors.blue,
        )
      };
    });
  }

  Future<void> _getStudentLocation() async {
    try {

      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        appLog("Location service disabled");
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();

      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        appLog("Location permission denied");
        return;
      }

      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      if (!mounted) return;

      setState(() {
        _studentLocation = LatLng(
          position.latitude,
          position.longitude,
        );
      });

      appLog("📍 Student location: $_studentLocation");

    } catch (e) {
      appLog("Student location error: $e");
    }
  }

  Future<void> _loadActiveIssue() async {
    final prefs = await SharedPreferences.getInstance();
    final busId = prefs.getString("busId");

    if (busId == null) return;

    final snapshot = await FirebaseDatabase.instance
        .ref("busIssues/$busId")
        .get();

    if (!snapshot.exists) return;

    final data = Map<String, dynamic>.from(snapshot.value as Map);

    if (data["status"] == "ACTIVE") {
      setState(() {
        activeIssue = data["issueType"];
      });
    }
  }

  @override
  void dispose() {
    _issueListener?.cancel();
    _busListener?.cancel();
    _tempBusListener?.cancel();
    _etaListener?.cancel();
    _notificationListener?.cancel();
    _miniMapController?.dispose();
    _animController.dispose();
    super.dispose();
  }
  Future<void> _refreshStudentProfile() async {
    final prefs = await SharedPreferences.getInstance();
    final regNo = prefs.getString("regNo");

    appLog("🔥 REGNO BEFORE API CALL = $regNo");

    if (regNo == null || regNo.isEmpty) {
      appLog("❌ REGNO IS NULL OR EMPTY");
      return;
    }

    final oldBusId = prefs.getString("busId");

    // ✅ THIS IS THE ONLY LINE CHANGED
    final response = await ApiService.get(
      "/auth/student-profile/${regNo.trim().toUpperCase()}",
    );

    if (response.statusCode == 404) {
      appLog("❌ Student not found in backend");

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Session expired. Please login again."),
        ),
      );

      return;
    }

    if (response.statusCode != 200) {
      appLog("❌ API FAILED: ${response.statusCode}");
      return;
    }

    final data = jsonDecode(response.body);
    final newBusId = data["busId"];

    if (oldBusId != null && oldBusId != newBusId) {
      await FirebaseMessaging.instance
          .unsubscribeFromTopic(oldBusId.toLowerCase());
    }

    if (newBusId != null && newBusId.isNotEmpty) {
      await FirebaseMessaging.instance
          .subscribeToTopic(newBusId.toLowerCase());
    }

    await prefs.setString("busId", newBusId ?? "");
    await prefs.setString("routeName", data["busName"] ?? "");
    await prefs.setString("studentName", data["name"] ?? "");
    await prefs.setString("stopName", data["boardingPoint"] ?? "");


    setState(() {
      studentName = data["name"];
      routeName = data["busName"];
      displayRoute = data["busName"];
      busId = newBusId;
    });

      appLog("🔥 FULL STUDENT PROFILE RESPONSE = $data");
  }

  Future<void> _requestPermission() async {
    NotificationSettings settings =
    await FirebaseMessaging.instance.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    appLog("Permission status: ${settings.authorizationStatus}");
  }

  void _listenForMessages() {
    FirebaseMessaging.onMessage.listen((RemoteMessage message) async {

      String title =
          message.notification?.title ??
              message.data['title'] ??
              "Notification";

      String body =
          message.notification?.body ??
              message.data['body'] ??
              "";

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("$title\n$body")),
      );
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

              final prefs = await SharedPreferences.getInstance();
              final oldBusId = prefs.getString("busId");

              // 🔥 UNSUBSCRIBE FROM FCM TOPIC
              if (oldBusId != null && oldBusId.isNotEmpty) {
                final topic = oldBusId.toLowerCase().trim();
                appLog("Unsubscribing from topic: $topic");

                await FirebaseMessaging.instance
                    .unsubscribeFromTopic(topic);
              }

              // 🔥 CLEAR SESSION
              await prefs.clear();

              // 🔥 SIGN OUT
              await FirebaseAuth.instance.signOut();

              if (!mounted) return;

              // 🔥 REMOVE BACK STACK
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
      appLog("❌ busId is NULL — cannot listen to temp bus");
      return;
    }

    appLog("👂 Listening to temporaryBusChanges/${originalBusId.toUpperCase()}");

    _tempBusListener?.cancel();

    _tempBusListener = FirebaseDatabase.instance
        .ref("temporaryBusChanges/${originalBusId.toUpperCase()}")
        .onValue
        .listen((event) async {

      final data = event.snapshot.value as Map?;

      // ================= TEMP ACTIVE =================
      if (data != null && data["status"] == "ACTIVE") {

        final String? newBus = data["newBus"];
        final String? tempRoute = data["tempRoute"];

        appLog("🚍 TEMP BUS ACTIVE");

        // 🔥 1️⃣ Unsubscribe old temp topic (if switching)
        if (tempBus != null && tempBus != newBus) {
          appLog("Unsubscribing old temp topic: ${tempBus!.toLowerCase()}");
          await FirebaseMessaging.instance
              .unsubscribeFromTopic(tempBus!.toLowerCase());
        }

        // 🔥 2️⃣ Subscribe new temp topic
        if (newBus != null && tempBus != newBus) {
          appLog("Subscribing to new temp topic: ${newBus.toLowerCase()}");
          await FirebaseMessaging.instance
              .subscribeToTopic(newBus.toLowerCase());
        }

        // 🔥 3️⃣ Update state AFTER topic handling
        setState(() {
          tempBus = newBus;
          displayRoute = tempRoute ?? routeName;
        });

        // 🔥 4️⃣ Re-attach listeners for new bus
        await _listenToBus();
        await _listenToBusIssues();
        _listenToEta();
      }

      // ================= TEMP CLEARED =================
      else {

        appLog("🔄 TEMP BUS CLEARED");

        // 🔥 Unsubscribe from temp topic if exists
        if (tempBus != null) {
          appLog("Unsubscribing temp topic: ${tempBus!.toLowerCase()}");
          await FirebaseMessaging.instance
              .unsubscribeFromTopic(tempBus!.toLowerCase());
        }

        // ❌ DO NOT resubscribe original (already subscribed)

        setState(() {
          tempBus = null;
          displayRoute = routeName;
        });

        await _listenToBus();

        await _listenToBusIssues();
      }
    });
  }
  Future<void> _listenToBus() async {

    String? currentBus = tempBus ?? busId;

    if (currentBus == null) return;

    await _loadRoutePolyline(currentBus);

    _busListener?.cancel();

    _busListener = FirebaseDatabase.instance
        .ref("buses/$currentBus/current")
        .onValue
        .listen((event)  {

      if (!mounted) return;

      final data = event.snapshot.value;

      // 🛑 Trip ended
      if (data == null) {

        setState(() {
          _busLocation = null;
          _busActive = false;

          _miniMarkers.removeWhere(
                (m) => m.markerId.value == "bus",
          );
        });

        appLog("🟡 Bus not started / trip ended");

        return;
      }

      final map = Map<String, dynamic>.from(data as Map);

      double? lat = map["lat"];
      double? lng = map["lng"];

      if (lat == null || lng == null) return;

      LatLng busPos = LatLng(lat, lng);

      setState(() {
        _busLocation = busPos;
        _busActive = true;

        _miniMarkers = {
          Marker(
            markerId: const MarkerId("bus"),
            position: busPos,
            icon: BitmapDescriptor.defaultMarkerWithHue(
              BitmapDescriptor.hueAzure,
            ),
          ),
          Marker(
            markerId: const MarkerId("student"),
            position: _studentLocation,
            icon: BitmapDescriptor.defaultMarkerWithHue(
              BitmapDescriptor.hueBlue,
            ),
          ),
        };
      });

      fetchRemainingRoute();

      // 🎥 Move camera to bus
      if (_miniMapController != null) {
        _miniMapController!.animateCamera(
          CameraUpdate.newCameraPosition(
            CameraPosition(
              target: busPos,
              zoom: 15,
            ),
          ),
        );
      }
    });
  }
  StreamSubscription? _etaListener;

  void _listenToEta() {

    String? currentBus = tempBus ?? busId;

    if (currentBus == null) return;

    _etaListener?.cancel();

    _etaListener = FirebaseDatabase.instance
        .ref("buses/$currentBus/eta")
        .onValue
        .listen((event) {

      final data = event.snapshot.value;

      if (data == null) return;

      final map = Map<String, dynamic>.from(data as Map);

      double? minutes = (map["etaMinutes"] as num?)?.toDouble();
      double? distance = (map["distanceMeters"] as num?)?.toDouble();

      if (!mounted) return;

      setState(() {
        if (distance != null && distance < 100) {
          _etaMinutes = 0;
        }
        else if (distance != null && distance < 500) {
          _etaMinutes = -1;
        }
        else {
          _etaMinutes = minutes;
        }
      });

    });
  }
  //ISSUE REPORTING BY BUS ALERT
  Future<void> _listenToBusIssues() async {
    final prefs = await SharedPreferences.getInstance();
    String? originalBus = prefs.getString("busId");
    String? currentBus = tempBus ?? originalBus;

    if (currentBus == null) return;

    _issueListener?.cancel();

    _issueListener = FirebaseDatabase.instance
        .ref("busIssues/$currentBus")
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

            // ===== Drawer Header =====
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(20, 60, 20, 24),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Color(0xFF00BFA6),
                    Color(0xFF00897B),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Row(
                children: [
                  const CircleAvatar(
                    radius: 28,
                    backgroundColor: Colors.white,
                    child: Icon(
                      Icons.person,
                      size: 30,
                      color: Color(0xFF00BFA6),
                    ),
                  ),

                  const SizedBox(width: 12),

                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        studentName ?? "Student",
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const Text(
                        "Student Account",
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 10),
            const Divider(thickness: 1),

            // ===== Menu Items =====

            _drawerItem(Icons.map, "View Map", () async {
              final prefs = await SharedPreferences.getInstance();
              String? busId = prefs.getString("busId");

              if (busId == null || busId.isEmpty) {
                if (!mounted) return;

                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Bus not assigned yet")),
                );
                return;
              }

              if (!mounted) return;

              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const MapPage(),
                ),
              );
            }),

            _drawerItem(Icons.notifications, "Notifications", () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const NotificationsPage()),
              );
            }),

            _drawerItem(Icons.settings, "Settings", () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SettingsPage()),
              );
            }),

            _drawerItem(Icons.info, "About App", () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AboutApp()),
              );
            }),

            const Divider(thickness: 1),

            const Spacer(),

            // ===== Logout =====
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
            SlideTransition(
              position: _slideAnim,
              child: FadeTransition(
                opacity: _fadeAnim,
                child:Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(20, 50, 20, 32),
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Color(0xFF00BFA6),
                        Color(0xFF00897B),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.only(
                      bottomLeft: Radius.circular(28),
                      bottomRight: Radius.circular(28),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          GestureDetector(
                            onTap: () =>
                                _scaffoldKey.currentState!.openDrawer(),
                            child: const Icon(Icons.menu, color: Colors.white),
                          ),
                          const Text(
                            'BusTrackPro',
                            style: TextStyle(color: Colors.white, fontSize: 20),
                          ),
                        ],
                      ),
                      const SizedBox(height: 22),

                      Text(
                        'Welcome back, ${studentName ?? "Student"}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 26,
                        ),
                      ),

                      const SizedBox(height: 6),

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
                  const Text(
                    'Live Bus Status',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 10),

                  FadeTransition(
                    opacity: _fadeAnim,
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(18),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.08),
                            blurRadius: 14,
                            offset: const Offset(0, 6),
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
                                !_busActive
                                    ? "🟡 Bus has not started yet"
                                    : _etaMinutes == null
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
                  ),
                  const SizedBox(height: 18),

                  // ================= LIVE BUS TRACKING =================

                  FadeTransition(
                    opacity: _fadeAnim,
                    child: SlideTransition(
                      position: _slideAnim,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [

                          const Text(
                            'Live Bus Tracking',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                            ),
                          ),

                          const SizedBox(height: 10),

                          AnimatedContainer(
                            duration: const Duration(milliseconds: 400),
                            margin: const EdgeInsets.only(bottom: 12),
                            curve: Curves.easeOut,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(18),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.1),
                                  blurRadius: 16,
                                  offset: const Offset(0, 8),
                                ),
                              ],
                            ),

                            child: Column(
                              children: [

                                /// 🗺️ MINI MAP
                                ClipRRect(
                                  borderRadius: const BorderRadius.only(
                                    topLeft: Radius.circular(16),
                                    topRight: Radius.circular(16),
                                  ),
                                  child: SizedBox(
                                    height: 170,
                                    child:GoogleMap(
                                      initialCameraPosition: CameraPosition(
                                        target: _busLocation ?? _studentLocation,
                                        zoom: 14,
                                      ),
                                      onMapCreated: (controller) {
                                        _miniMapController = controller;
                                      },
                                      markers: _miniMarkers,
                                      polylines: _miniPolylines,
                                      zoomControlsEnabled: false,
                                      myLocationEnabled: _locationPermissionGranted,
                                      myLocationButtonEnabled: _locationPermissionGranted,
                                      compassEnabled: false,
                                      mapToolbarEnabled: false,
                                      tiltGesturesEnabled: false,
                                      rotateGesturesEnabled: false,
                                      scrollGesturesEnabled: false,
                                      zoomGesturesEnabled: false,
                                    ),
                                  ),
                                ),

                                /// 🔵 OPEN MAP BUTTON
                                InkWell(
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => const MapPage(),
                                      ),
                                    );
                                  },
                                  child: Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.symmetric(vertical: 14),
                                    decoration: const BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: [
                                          Color(0xFF3E64FF),
                                          Color(0xFF5B7FFF),
                                        ],
                                      ),
                                      borderRadius: BorderRadius.only(
                                        bottomLeft: Radius.circular(16),
                                        bottomRight: Radius.circular(16),
                                      ),
                                    ),
                                    child: const Center(
                                      child: Text(
                                        "Open Map",
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          )
                        ],
                      ),
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
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
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
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      child: ListTile(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: const Color(0xFF00BFA6).withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: const Color(0xFF00BFA6)),
        ),
        title: Text(
          title,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w500,
          ),
        ),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
        onTap: onTap,
      ),
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

    appLog("REGNO FROM PREFS = $savedRegNo");

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
  Future<void> _clearAllNotifications() async {
    if (regNo == null) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Clear all notifications?"),
        content: const Text(
            "This will permanently delete all notification history."),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Clear All"),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    await FirebaseDatabase.instance
        .ref("notifications/$regNo")
        .remove();

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("All notifications cleared"),
        duration: Duration(seconds: 2),
      ),
    );
  }
  Future<void> _markAllAsRead() async {
    final prefs = await SharedPreferences.getInstance();
    final regNo = prefs.getString("regNo");

    if (regNo == null) return;

    final ref =
    FirebaseDatabase.instance.ref("notifications/$regNo");

    final snapshot = await ref.get();

    if (!snapshot.exists) return;

    final data = Map<String, dynamic>.from(snapshot.value as Map);

    Map<String, dynamic> updates = {};

    for (var key in data.keys) {
      updates["$key/read"] = true;
    }

    await ref.update(updates);
  }
  String formatTime(dynamic timestamp) {
    if (timestamp == null) return "Just now";

    final now = DateTime.now();
    final date = DateTime.fromMillisecondsSinceEpoch(
        (timestamp is int) ? timestamp : 0);

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
        actions: [
          if (regNo != null)
            IconButton(
              icon: const Icon(Icons.delete_sweep, color: Colors.white),
              tooltip: "Clear All",
              onPressed: _clearAllNotifications,
            ),
        ],
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
            ..sort((a, b) {
              final tsA = data[a]["timestamp"] ?? 0;
              final tsB = data[b]["timestamp"] ?? 0;
              return tsB.compareTo(tsA);
            });

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