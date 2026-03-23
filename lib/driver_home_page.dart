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
import 'utils/app_logger.dart';

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
  String driverName = "Driver";

  // NEW: keep permanent and temporary values separate
  String permBusNumber = "-";
  String permRouteName = "-";
  String? tempBusNumber;
  String? tempRouteName;
  double _lastSpeed = 0;
  DateTime? tripStartTime;
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

  // 🧵 ROUTE POLYLINE STATE
  final List<LatLng> _routePoints = [];

  // ✅ SHIFT FUNCTION (MOVE HERE)
  String? _pickText(dynamic value) {
    if (value == null) return null;
    final text = value.toString().trim();
    if (text.isEmpty || text == "-") return null;
    return text;
  }

  Map<String, dynamic> _extractProfile(Map<String, dynamic> data) {
    if (data["driver"] is Map) {
      return Map<String, dynamic>.from(data["driver"] as Map);
    }
    return data;
  }

  Future<Map<String, dynamic>?> _fetchDriverProfileByPhone(String phone) async {
    final encodedPhone = Uri.encodeQueryComponent(phone);
    final endpoints = [
      "/auth/driver-profile/$phone",
      "/auth/driver-profile?phone=$encodedPhone",
      "/auth/profile?phone=$encodedPhone",
      "/drivers/profile?phone=$encodedPhone",
      "/profile?phone=$encodedPhone",
    ];
    Map<String, dynamic>? fallbackProfile;

    for (final endpoint in endpoints) {
      final response = await ApiService.get(endpoint);
      appLog("Driver profile fetch $endpoint -> ${response.statusCode}");
      if (response.statusCode != 200) continue;

      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) continue;

      final profile = _extractProfile(decoded);
      final hasBusId = _pickText(profile["busId"]) != null;
      final hasRoute = _pickText(profile["busName"]) != null ||
          _pickText(profile["routeName"]) != null ||
          _pickText(profile["route"]) != null;

      if (hasBusId && hasRoute) return profile;
      if (hasBusId) fallbackProfile = profile;
    }

    return fallbackProfile;
  }

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

    // 🔹 First fetch profile from backend
    await _refreshDriverProfile();

    // 🔹 Then load saved data
    await _loadBusInfo();
    busId ??= permBusId;

    // 🔹 Then listen to temporary bus changes
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
      driverName = prefs.getString("driverName") ?? "Driver";

      permBusNumber = prefs.getString("busNumber") ?? "-";
      permRouteName = prefs.getString("routeName") ?? "-";
      permBusId = prefs.getString("permBusId");

      // keep main state variables synced
      busNumber = permBusNumber;
      routeName = permRouteName;

      shift = _getShiftByTime();

      isTempBusActive = prefs.getBool("isTempBusActive") ?? false;
      tempBusNumber = prefs.getString("tempBusNumber");
      tempRouteName = prefs.getString("tempRouteName");
    });

    appLog("Loaded busNumber: $permBusNumber");
    appLog("Loaded routeName: $permRouteName");
  }
  //================ LISTEN TO TEMPORARY BUS CHANGES ==========================
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
      appLog("GPS SERVICE DISABLED");
      return;
    }

    LocationPermission permission = await Geolocator.checkPermission();

    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      appLog("LOCATION PERMISSION DENIED");
      return;
    }

    positionStream?.cancel();

    positionStream = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10,
      ),
    ).listen((position) {

      appLog("GPS UPDATE → ${position.latitude}, ${position.longitude}");
      appLog("RAW SPEED → ${position.speed} m/s");

      if (!tripStarted) {
        appLog("GPS running but trip not started");
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

      appLog("SMOOTHED SPEED → $realSpeed m/s");

      // ================= UI UPDATE =================
      if (!mounted) return;

      setState(() {


        if (_routePoints.isEmpty ||
            Geolocator.distanceBetween(
              _routePoints.last.latitude,
              _routePoints.last.longitude,
              latLng.latitude,
              latLng.longitude,
            ) > 5) {

          _routePoints.add(latLng);

          // prevent memory overflow
          if (_routePoints.length > 1000) {
            _routePoints.removeAt(0);
          }
        }
      });

      _mapController?.animateCamera(
        CameraUpdate.newLatLng(latLng),
      );

      // ================= FIREBASE UPDATE =================
      if (busId != null && busId!.isNotEmpty && internetOn) {
        FirebaseDatabase.instance.ref("buses/$busId/current").update({
          "lat": position.latitude,
          "lng": position.longitude,
          "bearing": position.heading,
          "speed": realSpeed, // 🔥 stable speed
          "updatedAt": ServerValue.timestamp,
        }).catchError((e) {
          appLog("Failed to update bus location: $e");
        });
      }
    });
  }
  //==================== START TRIP WITH MODE (NEW) =================
  Future<void> _startTripWithMode(String mode) async {

    // Prevent double start
    if (tripStarted) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Trip already running")),
      );
      return;
    }

    // Validate bus ID
    if (busId == null || busId!.isEmpty) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Bus ID not found")),
      );
      return;
    }

    // Check GPS + Internet
    await _checkStatuses();

    if (!gpsOn || !internetOn) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Enable GPS & Internet first")),
      );
      return;
    }

    try {

      appLog("🚍 Starting trip for bus → $busId");

      final response = await ApiService.post(
        "/drivers/start-trip",
        {
          "busId": busId,
          "mode": mode,
        },
      );

      appLog("START TRIP RESPONSE → ${response.body}");

      if (response.statusCode != 200) {

        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Failed to start trip")),
        );

        return;
      }

      // ---------------- PARSE RESPONSE ----------------

      Map<String, dynamic> data = {};

      if (response.body.isNotEmpty) {
        try {
          data = jsonDecode(response.body);
        } catch (e) {
          appLog("JSON decode failed → $e");
        }
      }

      // ---------------- GET TRIP ID ----------------

      if (data["tripId"] != null) {
        currentTripId = data["tripId"].toString();
      }

      if (currentTripId == null) {
        final prefs = await SharedPreferences.getInstance();
        currentTripId = prefs.getString("activeTripId");
      }

      appLog("Current TripId → $currentTripId");

      // ---------------- UPDATE UI ----------------

      if (mounted) {
        setState(() {
          tripStarted = true;
          tripMode = mode;
          tripStartTime = DateTime.now(); // start timer
        });
      }

      // ---------------- START BACKGROUND SERVICE ----------------

      final service = FlutterBackgroundService();

      bool running = await service.isRunning();

      if (!running) {
        await service.startService();
      }

      service.invoke("setBusId", {
        "busId": busId,
      });

      // ---------------- SAVE LOCAL STATE ----------------

      final prefs = await SharedPreferences.getInstance();

      await prefs.setBool("trackingActive", true);

      if (currentTripId != null) {
        await prefs.setString("activeTripId", currentTripId!);
      }

      await prefs.setString("tripMode", mode);

      // ---------------- START GPS TRACKING ----------------

      await _startLocationUpdates();

      // ---------------- FINAL CHECK ----------------

      await _checkStatuses();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("$mode trip started successfully")),
      );

    } catch (e) {

      appLog("❌ START TRIP ERROR → $e");

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Trip start failed")),
      );
    }
  }
  //==================== END TRIP WITH MODE (NEW) =================
  Future<void> _endTripFromBackend() async {

    if (tripEnding) return;

    tripEnding = true;

    final prefs = await SharedPreferences.getInstance();

    String? tripId = currentTripId ?? prefs.getString("activeTripId");

    appLog("🚏 END TRIP busId = $busId");
    appLog("🚏 END TRIP tripId = $tripId");

    if (busId == null || tripId == null) {
      appLog("❌ End trip failed. Missing trip data.");
      tripEnding = false;
      return;
    }

    try {

      final response = await ApiService.post(
        "/drivers/end-trip",
        {
          "busId": busId,
          "tripId": tripId,
        },
      );

      appLog("END TRIP RESPONSE → ${response.body}");

      // ---------------- STOP GPS ----------------

      await positionStream?.cancel();

      // ---------------- STOP BACKGROUND SERVICE ----------------

      FlutterBackgroundService().invoke("stopService");

      // ---------------- CLEAR LOCAL STORAGE ----------------

      await prefs.setBool("trackingActive", false);
      await prefs.remove("activeTripId");
      await prefs.remove("tripMode");

      // ---------------- UPDATE UI ----------------

      if (!mounted) return;

      setState(() {
        tripStarted = false;
        tripEnding = false;
        currentTripId = null;
        tripStartTime = null;
        _routePoints.clear();
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Trip Ended Successfully")),
      );

    } catch (e) {

      appLog("❌ End Trip Error → $e");

      tripEnding = false;

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Failed to end trip")),
      );
    }
  }

  Future<void> _refreshDriverProfile() async {
    final prefs = await SharedPreferences.getInstance();
    final phone = prefs.getString("phone");

    if (phone == null) return;

    final profile = await _fetchDriverProfileByPhone(phone);
    appLog("Driver profile response → $profile");
    if (profile == null) return;

    final resolvedName = _pickText(profile["name"]) ?? "-";

    final resolvedBusId = _pickText(profile["busId"]) ?? "-";

    final resolvedBusNumber =
        _pickText(profile["busNumber"]) ?? resolvedBusId;
    final resolvedLicense = _pickText(profile["licenseNo"]) ?? "-";

    String finalRouteName =
        _pickText(profile["busName"]) ??
            _pickText(profile["routeName"]) ??
            "-";

    // SAVE TO PREFS
    await prefs.setString("driverName", resolvedName);
    await prefs.setString("busId", resolvedBusId);
    await prefs.setString("permBusId", resolvedBusId);

    await prefs.setString("busNumber", resolvedBusNumber);
    await prefs.setString("routeName", finalRouteName);
    await prefs.setString("licenseNo", resolvedLicense);

    setState(() {
      permBusNumber = resolvedBusNumber;
      permRouteName = finalRouteName;
      permBusId = resolvedBusId;
      busId = resolvedBusId;
      shift = _getShiftByTime();
    });

    await _loadBusInfo();

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
              DrawerHeader(
                decoration: const BoxDecoration(color: Color(0xFF00BFA6)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                  const CircleAvatar(
                  radius: 28,
                  backgroundColor: Colors.white,
                  child: Icon(Icons.person, color: Color(0xFF00BFA6)),
                ),
                const SizedBox(height: 12),
                Text(
                  driverName,
                  style: const TextStyle(
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

        body: RefreshIndicator(
            onRefresh: () async {
              await _refreshDriverProfile();
              await _loadBusInfo();
              await _checkStatuses();
            },
            child: SingleChildScrollView(
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
                            Text(
                              'Hi, $driverName',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 17,
                                fontWeight: FontWeight.w600,
                              ),
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
                  title: "⚠ Temporary Bus Active",
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
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
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
      children: [

        Icon(Icons.circle, size: 8, color: Colors.grey),
        SizedBox(width: 10),

        Expanded(child: Text(label)),

        Text(value),
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
