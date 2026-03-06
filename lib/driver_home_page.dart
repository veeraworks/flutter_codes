import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:geolocator/geolocator.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:firebase_database/firebase_database.dart';
import 'service/api_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'temporary_bus_change_page.dart';
import 'driver_profile_page.dart';
import 'driver_settings_page.dart';
import 'issue_reporting_page.dart';
import 'driver_map_page.dart';

class DriverHomePage extends StatefulWidget {
  const DriverHomePage({super.key});

  @override
  State<DriverHomePage> createState() => _DriverHomePageState();

}
class _DriverHomePageState extends State<DriverHomePage>
    with SingleTickerProviderStateMixin {

  bool tripStarted = false;
  String? tripMode;

  // 🔑 BUS INFO STATE
  String busNumber = "-";
  String routeName = "-";
  String shift = "-";
  bool isTempBusActive = false;

  // NEW: keep permanent and temporary values separate
  String permBusNumber = "-";
  String permRouteName = "-";
  String? tempBusNumber;
  String? tempRouteName;
  double _lastSpeed = 0;

  Timer? _gpsCheckTimer;
  bool gpsOn = false;
  bool internetOn = false;
  bool locationSyncOn = false;
  bool tripEnding = false;

  String? busId;
  String? permBusId;
  String? currentTripId;

  StreamSubscription<Position>? positionStream;
  StreamSubscription? _tempBusListener;

  late AnimationController _animController;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

  bool _buttonPressed = false;

  // 🗺️ MAP STATE
  GoogleMapController? _mapController;
  Marker? _driverMarker;
  LatLng _currentLatLng = const LatLng(13.0827, 80.2707);

  // 🧵 ROUTE POLYLINE STATE
  final List<LatLng> _routePoints = [];

  // ✅ SHIFT FUNCTION (MOVE HERE)
  String _getShiftByTime() {
    final now = DateTime.now();
    final hour = now.hour;

    if (hour < 12) {
      return "MORNING";
    } else {
      return "EVENING";
    }
  }

  @override
  void initState() {
    super.initState();

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
    _initialize();

    // AUTO SET SHIFT WHEN PAGE LOADS
    shift = _getShiftByTime();

    _gpsCheckTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      if (tripStarted) {
        _checkStatuses();
      }
    });
  }

  Future<void> _initialize() async {
    final prefs = await SharedPreferences.getInstance();

    await _loadBusId();
    await _refreshDriverProfile();
    await _loadBusInfo();
    await _listenToTemporaryBus();

    final wasTracking = prefs.getBool("trackingActive") ?? false;
    final savedTripId = prefs.getString("activeTripId");

    if (wasTracking && savedTripId != null) {
      setState(() {
        tripStarted = true;
        currentTripId = savedTripId;
        tripMode = prefs.getString("tripMode");
      });

      if (tripStarted && busId != null) {

        final service = FlutterBackgroundService();

        bool running = await service.isRunning();

        if (!running) {
          await service.startService();
        }

        service.invoke("setBusId", {
          "busId": busId
        });
      }

      _startLocationUpdates();
    }

    await _checkStatuses();

    setState(() {
    });
  }

  @override
  void dispose() {
    positionStream?.cancel();
    _tempBusListener?.cancel();
    _gpsCheckTimer?.cancel();
    _animController.dispose();
    super.dispose();
  }
  // ================= LOAD BUS ID ====================================
  Future<void> _loadBusId() async {
    final prefs = await SharedPreferences.getInstance();

    setState(() {
      permBusId = prefs.getString("busId");
      busId = permBusId;
    });
  }
// ================= LOAD BUS INFO (ADDED) =================
  Future<void> _loadBusInfo() async {
    final prefs = await SharedPreferences.getInstance();

    setState(() {
      // Permanent
      permBusNumber = prefs.getString("busNumber") ?? "-";
      permRouteName = prefs.getString("routeName") ?? "-";
      shift = _getShiftByTime();
      // Temporary
      isTempBusActive = prefs.getBool("isTempBusActive") ?? false;
      tempBusNumber = prefs.getString("tempBusNumber");
      tempRouteName = prefs.getString("tempRouteName");
    });

    print("Permanent → $permBusNumber | $permRouteName");
    print("Temporary Active → $isTempBusActive");
  }
//===================== LISTEN TO TEMPORARY BUS CHANGES ==========================
  Future<void> _listenToTemporaryBus() async {
    final prefs = await SharedPreferences.getInstance();
    final permId = prefs.getString("busId");
    if (permId == null) return;

    _tempBusListener?.cancel();

    _tempBusListener = FirebaseDatabase.instance
        .ref("temporaryBusChanges/${permId.toUpperCase()}")
        .onValue
        .listen((event) async {

      final data = event.snapshot.value as Map?;

      // ================= ACTIVE =================
      if (data != null && data["status"] == "ACTIVE") {

        final String? newBus = data["newBus"];
        final String? newRoute = data["tempRoute"];

        if (newBus == null || newBus == busId) return;
        if (!mounted) return;
        setState(() {
          isTempBusActive = true;
          tempBusNumber = newBus;
          tempRouteName = newRoute;
          busId = newBus;
        });

        // 🔥 SAVE TEMP STATE
        await prefs.setBool("isTempBusActive", true);
        await prefs.setString("tempBusNumber", newBus);
        await prefs.setString("tempRouteName", newRoute ?? "");

        // 🔥 UPDATE BACKGROUND SERVICE
        if (tripStarted) {
          FlutterBackgroundService().invoke("setBusId", {
            "busId": busId,
          });
        }
      }

      // ================= CLEAR =================
      else {

        setState(() {
          isTempBusActive = false;
          tempBusNumber = null;
          tempRouteName = null;
          busId = permBusId;
        });

        // 🔥 CLEAR SAVED TEMP STATE
        await prefs.setBool("isTempBusActive", false);
        await prefs.remove("tempBusNumber");
        await prefs.remove("tempRouteName");

        // 🔥 UPDATE BACKGROUND SERVICE
        if (tripStarted) {
          FlutterBackgroundService().invoke("setBusId", {
            "busId": busId,
          });
        }
      }
    });
  }
  // ---------------- CHECK GPS / INTERNET ---------------------------------------
  Future<void> _checkStatuses() async {

    if (!mounted) return;

    final gpsEnabled = await Geolocator.isLocationServiceEnabled();

    final ConnectivityResult connectivity =
    await Connectivity().checkConnectivity();

    final bool netEnabled = connectivity != ConnectivityResult.none;

    if (!mounted) return;

    setState(() {
      gpsOn = gpsEnabled;
      internetOn = netEnabled;
      locationSyncOn = tripStarted && gpsOn && internetOn;
    });

    if (tripStarted && !gpsOn && !tripEnding) {

      tripEnding = true;

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("GPS turned OFF! Trip stopped")),
      );

      _endTripFromBackend();
    }
  }
  // ================= START GPS TRACKING ==================================
  Future<void> _startLocationUpdates() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      print("GPS SERVICE DISABLED");
      return;
    }

    LocationPermission permission = await Geolocator.checkPermission();

    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      print("LOCATION PERMISSION DENIED");
      return;
    }

    positionStream?.cancel();

    positionStream = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10,
      ),
    ).listen((position) {

      print("GPS UPDATE → ${position.latitude}, ${position.longitude}");
      print("RAW SPEED → ${position.speed} m/s");

      if (!tripStarted) {
        print("GPS running but trip not started");
        return;
      }

      final latLng = LatLng(position.latitude, position.longitude);

      // ================= SPEED STABILIZATION =================
      double realSpeed = position.speed;

      // Remove tiny GPS noise
      if (realSpeed < 0.5) {
        realSpeed = 0;
      }

      // Apply exponential smoothing (70% previous + 30% new)
      realSpeed = (_lastSpeed * 0.7) + (realSpeed * 0.3);

      // Round to 1 decimal place
      realSpeed = double.parse(realSpeed.toStringAsFixed(1));

      _lastSpeed = realSpeed;

      print("SMOOTHED SPEED → $realSpeed m/s");

      // ================= UI UPDATE =================
      if (!mounted) return;

      setState(() {
        _currentLatLng = latLng;

        _driverMarker = Marker(
          markerId: const MarkerId("driver"),
          position: latLng,
          icon: BitmapDescriptor.defaultMarkerWithHue(
            BitmapDescriptor.hueGreen,
          ),
        );

        if (_routePoints.isEmpty ||
            Geolocator.distanceBetween(
              _routePoints.last.latitude,
              _routePoints.last.longitude,
              latLng.latitude,
              latLng.longitude,
            ) > 5) {

          _routePoints.add(latLng);
        }

      });

      _mapController?.animateCamera(
        CameraUpdate.newLatLng(latLng),
      );

      // ================= FIREBASE UPDATE =================
      if (busId != null && internetOn) {
        FirebaseDatabase.instance.ref("buses/$busId/current").update({
          "lat": position.latitude,
          "lng": position.longitude,
          "bearing": position.heading,
          "speed": realSpeed, // 🔥 stable speed
          "updatedAt": ServerValue.timestamp,
        }).catchError((e) {
          print("Failed to update bus location: $e");
        });
      }
    });
  }
  //==================== START TRIP WITH MODE (NEW) =================
  Future<void> _startTripWithMode(String mode) async {
    if (busId == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Bus ID not found")),
      );
      return;
    }

    await _checkStatuses();

    if (!gpsOn || !internetOn) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Enable GPS & Internet first")),
      );
      return;
    }

    try {
      final response = await ApiService.post(
        "/drivers/start-trip",
        {
          "busId": busId,
          "mode": mode,
        },
      );

      print("START TRIP RESPONSE → ${response.body}");

      if (response.statusCode != 200) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Failed to start trip")),
        );
        return;
      }

      if (response.body.isEmpty) {
        print("Start trip API returned empty response");
        return;
      }

      Map<String, dynamic> data = {};

      try {
        data = jsonDecode(response.body);
      } catch (e) {
        print("JSON decode failed");
      }
      print("TripId received → ${data["tripId"]}");

// If backend returned tripId
      if (data["tripId"] != null) {
        currentTripId = data["tripId"].toString();
      }

// If backend did not return tripId (trip already active)
      if (currentTripId == null) {
        final prefs = await SharedPreferences.getInstance();
        currentTripId = prefs.getString("activeTripId");
      }

      print("Current TripId → $currentTripId");

// Update UI
      if (mounted) {
        setState(() {
          tripStarted = true;
          tripMode = mode;
        });
      }

      // Start background service
      final service = FlutterBackgroundService();

      bool running = await service.isRunning();
      if (!running) {
        await service.startService();
      }

      service.invoke("setBusId", {
        "busId": busId,
      });

      // Save trip state locally
      final prefs = await SharedPreferences.getInstance();

      await prefs.setBool("trackingActive", true);

      if (currentTripId != null) {
        await prefs.setString("activeTripId", currentTripId!);
      }

      await prefs.setString("tripMode", mode);

      await _checkStatuses();

      // Start GPS tracking
      await _startLocationUpdates();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("$mode trip started")),
      );

    } catch (e) {
      print("START TRIP ERROR → $e");

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Trip start failed")),
      );
    }
  }

  //==================== END TRIP WITH MODE (NEW) =================
  Future<void> _endTripFromBackend() async {
    final prefs = await SharedPreferences.getInstance();

    String? tripId = currentTripId ?? prefs.getString("activeTripId");

    print("END TRIP busId = $busId");
    print("END TRIP tripId = $tripId");

    if (busId == null || tripId == null) {
      print("❌ End trip failed. Missing trip data.");
      return;
    }

    tripEnding = true;

    try {
      final response = await ApiService.post(
        "/drivers/end-trip",
        {
          "busId": busId,
          "tripId": tripId,
        },
      );

      print("END TRIP RESPONSE → ${response.body}");

      // 🔥 CLEAR LOCAL DATA
      await prefs.setBool("trackingActive", false);
      await prefs.remove("activeTripId");
      await prefs.remove("tripMode");

      await positionStream?.cancel();

      FlutterBackgroundService().invoke("stopService");

      if (!mounted) return;
      setState(() {
        tripStarted = false;
        currentTripId = null;
        tripEnding = false;
        _routePoints.clear();
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Trip Ended")),
      );

    } catch (e) {
      print("❌ End Trip Error → $e");
    }
  }
  Future<void> _refreshDriverProfile() async {
    final prefs = await SharedPreferences.getInstance();
    final phone = prefs.getString("phone");

    if (phone == null) return;

    final response =
    await ApiService.get("/auth/driver-profile/$phone");

    if (response.statusCode != 200) return;

    final data = jsonDecode(response.body);

    // 🔥 SAVE UPDATED VALUES
    await prefs.setString("driverName", data["name"] ?? "-");
    await prefs.setString("busId", data["busId"] ?? "-");
    await prefs.setString("busNumber", data["busNumber"] ?? data["busId"] ?? "-");
    await prefs.setString("routeName", data["busName"] ?? "-");
    await prefs.setString("licenseNo", data["licenseNo"] ?? "-");
    await prefs.setString("shift", data["shift"] ?? "-");

    setState(() {
      permBusNumber = data["busNumber"] ?? data["busId"] ?? "-";
      permRouteName = data["busName"] ?? "-";
      permBusId = data["busId"];
      shift = _getShiftByTime();
    });

    // 🔥 UPDATE BACKGROUND SERVICE IF TRIP ACTIVE
    if (tripStarted && busId != null) {
      FlutterBackgroundService().invoke("setBusId", {
        "busId": busId,
      });
    }
  }

  // ---------------- UI ----------------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
        backgroundColor: const Color(0xFFF6F3F7),

        drawer: Drawer(
          child: ListView(
            padding: EdgeInsets.zero,
            children: [
              const DrawerHeader(
                decoration: BoxDecoration(color: Color(0xFF00BFA6)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
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

              ListTile(
                leading: const Icon(Icons.person),
                title: const Text("Profile"),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const DriverProfilePage()),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.map, color: Colors.blue),
                title: const Text("Live Map"),
                onTap: () {
                  Navigator.pop(context);

                  if (!tripStarted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("Start trip to view map")),
                    );
                    return;
                  }

                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const DriverMapPage(),
                    ),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.swap_horiz, color: Colors.orange),
                title: const Text("Temporary Bus Change"),
                onTap: () async {
                  Navigator.pop(context); // close drawer first

                  final bool? updated = await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const TemporaryBusChangePage(),
                    ),
                  );

                  // Refresh bus info if user applied or cleared changes
                  if (updated == true) {
                    await _loadBusInfo();
                    await _checkStatuses();
                  }
                },
              ),

              ListTile(
                leading: const Icon(Icons.report_problem, color: Colors.red),
                title: const Text("Issue Reporting"),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const IssueReportingPage()),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.settings),
                title: const Text("Settings"),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const DriverSettingsPage()),
                ),
              ),
            ],
          ),
        ),

        body: SingleChildScrollView(
          child: Column(
            children: [
              // HEADER
              SlideTransition(
                position: _slideAnim,
                child: FadeTransition(
                  opacity: _fadeAnim,
                  child: Container(
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
                              style: TextStyle(color: Colors.white, fontSize: 22),
                            ),
                            Text(
                              tripStarted
                                  ? (isTempBusActive
                                  ? 'TEMP ${tripMode ?? ""} DUTY'
                                  : '${tripMode ?? ""} DUTY')
                                  : 'OFF DUTY',
                              style: const TextStyle(color: Colors.white70),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 20),

              FadeTransition(
                opacity: _fadeAnim,
                child: _infoCard(
                  title: 'Bus Information',
                  children: [
                    _infoRow('Route', permRouteName),
                    _infoRow('Bus Number', permBusNumber),
                    _infoRow('Shift', shift),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              if (isTempBusActive)
                _infoCard(
                  title: "Temporary Bus Active",
                  titleColor: Colors.orange,
                  children: [
                    _infoRow("Temporary Bus", tempBusNumber ?? "-"),
                    _infoRow("Temporary Route", tempRouteName ?? "-"),
                  ],
                ),

              const SizedBox(height: 16),

              _infoCard(
                title: 'Location Status',
                children: [
                  _statusRow('GPS', gpsOn, tripStarted),
                  _statusRow('Internet', internetOn, tripStarted),
                  _statusRow('Location Sync', locationSyncOn, tripStarted),
                ],
              ),

              FadeTransition(
                opacity: _fadeAnim,
                child: const SizedBox(height: 20),
              ),

              Padding(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
                child: tripStarted
                    ? _animatedActionButton(
                  text: "End Trip",
                  color: Colors.red,
                  onTap: tripEnding ? () {} : _endTripFromBackend,
                )
                    : Column(
                  children: [
                    _animatedActionButton(
                      text: "Start Morning Trip",
                      color: const Color(0xFF00BFA6),
                      onTap: () => _startTripWithMode("MORNING"),
                    ),
                    const SizedBox(height: 12),
                    _animatedActionButton(
                      text: "Start Evening Trip",
                      color: Colors.orange,
                      onTap: () => _startTripWithMode("EVENING"),
                    ),
                  ],
                ),
              ),
            ],
          ),
        )
    );
  }

  // ---------------- UI HELPERS ----------------
  Widget _animatedActionButton({
    required String text,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _buttonPressed = true),
      onTapUp: (_) {
        setState(() => _buttonPressed = false);
        onTap();
      },
      onTapCancel: () => setState(() => _buttonPressed = false),
      child: AnimatedScale(
        scale: _buttonPressed ? 0.95 : 1,
        duration: const Duration(milliseconds: 120),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          padding: const EdgeInsets.symmetric(vertical: 18),
          decoration: BoxDecoration(
            color: _buttonPressed
                ? color.withOpacity(0.85)
                : color,
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.15),
                blurRadius: 8,
                offset: const Offset(0, 4),
              )
            ],
          ),
          child: Center(
            child: Text(
              text,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _infoCard({
    required String title,
    required List<Widget> children,
    Color titleColor = Colors.black,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: titleColor,
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
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(color: Colors.black54)),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w500)),
      ],
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
          Text(text,
              style:
              TextStyle(color: color, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}