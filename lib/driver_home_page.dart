import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:geolocator/geolocator.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import 'driver_full_map_page.dart';
import 'temporary_bus_change_page.dart';
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
  String? tripMode;
  bool _initialized = false;
  // 🔑 BUS INFO STATE (ADDED)
  String busNumber = "-";
  String routeName = "-";
  String shift = "-";
  bool isTempBusActive = false;

  // NEW: keep permanent and temporary values separate
  String permBusNumber = "-";
  String permRouteName = "-";
  String? tempBusNumber;
  String? tempRouteName;

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

  // 🗺️ MAP STATE
  GoogleMapController? _mapController;
  Marker? _driverMarker;
  Marker? _startMarker;
  Marker? _endMarker;
  LatLng _currentLatLng = const LatLng(13.0827, 80.2707); // default

  // 🧵 ROUTE POLYLINE STATE
  final List<LatLng> _routePoints = [];
  Set<Polyline> _polylines = {};

  @override
  void initState() {
    super.initState();
    _initialize();

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

      _startLocationUpdates();
    }

    await _checkStatuses();

    setState(() {
      _initialized = true;
    });
  }

  @override
  void dispose() {
    positionStream?.cancel();
    _tempBusListener?.cancel();
    _gpsCheckTimer?.cancel();
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
      shift = prefs.getString("shift") ?? "-";

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

    _tempBusListener = FirebaseDatabase.instance
        .ref("temporaryBusChanges/$permId")
        .onValue
        .listen((event) {

      final data = event.snapshot.value as Map?;

      if (data != null && data["status"] == "ACTIVE") {

        setState(() {
          isTempBusActive = true;
          tempBusNumber = data["newBus"];
          tempRouteName = data["tempRoute"];

          // ✅ VERY IMPORTANT
          busId = data["newBus"];
        });

      } else {

        setState(() {
          isTempBusActive = false;
          tempBusNumber = null;
          tempRouteName = null;

          busId = permBusId;
        });
      }
    });
  }

  // ---------------- CHECK GPS / INTERNET ---------------------------------------
  Future<void> _checkStatuses() async {
    final gpsEnabled = await Geolocator.isLocationServiceEnabled();

    final ConnectivityResult connectivity =
    await Connectivity().checkConnectivity();

    final bool netEnabled = connectivity != ConnectivityResult.none;

    setState(() {
      gpsOn = gpsEnabled;
      internetOn = netEnabled;
      locationSyncOn = tripStarted && gpsOn && internetOn;
    });

    // AUTO STOP TRIP IF GPS TURNED OFF
    if (tripStarted && !gpsOn && !tripEnding) {
      tripEnding = true;

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
        distanceFilter: 5,
      ),
    ).listen((position) {
      print("GPS UPDATE → ${position.latitude}, ${position.longitude}");

    if (!tripStarted) {
      print("GPS running but trip not started");
      return;
    }

      final latLng = LatLng(position.latitude, position.longitude);

      setState(() {
        _currentLatLng = latLng;

        _driverMarker = Marker(
          markerId: const MarkerId("driver"),
          position: latLng,
          icon: BitmapDescriptor.defaultMarkerWithHue(
            BitmapDescriptor.hueGreen,
          ),
        );

        _routePoints.add(latLng);
        print("Route points now = ${_routePoints.length}");

        _polylines.clear();
        _polylines.add(
          Polyline(
            polylineId: const PolylineId("route"),
            points: _routePoints,
            color: Colors.blue,
            width: 5,
          ),
        );
        _polylines = {
          Polyline(
            polylineId: const PolylineId("route"),
            points: _routePoints,
            color: Colors.blue,
            width: 6,
            jointType: JointType.round,
            startCap: Cap.roundCap,
            endCap: Cap.roundCap,
          ),
        };
      });

      _mapController?.animateCamera(
        CameraUpdate.newLatLng(latLng),
      );

      // Update Firebase only if busId exists (non-blocking)
      // Update Firebase only if busId exists AND internet is ON
      if (busId != null && internetOn) {
        FirebaseDatabase.instance.ref("buses/$busId").update({
          "lat": position.latitude,
          "lng": position.longitude,
          "bearing": position.heading,
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Bus ID not found")),
      );
      return;
    }
    await _checkStatuses();

    if (!gpsOn || !internetOn) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Enable GPS & Internet first")),
      );
      return;
    }

    final response = await http.post(
      Uri.parse("https://null-sheldon-unstudded.ngrok-free.dev/drivers/start-trip"),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({
        "busId": busId,
        "mode": mode,
      }),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);

      currentTripId = data["tripId"];

      setState(() {
        tripStarted = true;
        FlutterBackgroundService().startService();
        FlutterBackgroundService().invoke("setBusId", {
          "busId": busId
        });
        tripMode = mode;
      });
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool("trackingActive", true);
      await prefs.setString("activeTripId", currentTripId!);
      await prefs.setString("tripMode", mode);

      await _checkStatuses();

      _startLocationUpdates();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("$mode trip started")),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Failed to start trip")),
      );
    }
  }

  //==================== END TRIP WITH MODE (NEW) =================
  Future<void> _endTripFromBackend() async {
    if (busId == null || currentTripId == null) return;

    final prefs = await SharedPreferences.getInstance();

    // 🔥 CLEAR LOCAL TRIP DATA
    await prefs.setBool("trackingActive", false);
    await prefs.remove("activeTripId");
    await prefs.remove("tripMode");

    final response = await http.post(
      Uri.parse(
          "https://null-sheldon-unstudded.ngrok-free.dev/drivers/end-trip"),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({
        "busId": busId,
        "tripId": currentTripId,
      }),
    );

    await positionStream?.cancel();
    FlutterBackgroundService().invoke("stopService");
    setState(() {
      tripStarted = false;
      currentTripId = null;
      tripEnding = false;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Trip Ended")),
    );
  }

  Future<void> _refreshDriverProfile() async {
    final prefs = await SharedPreferences.getInstance();
    final phone = prefs.getString("phone");

    if (phone == null) return;

    final response = await http.get(
      Uri.parse(
          "https://null-sheldon-unstudded.ngrok-free.dev/drivers/profile?phone=$phone"),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);

      await prefs.setString("driverName", data["name"]);
      await prefs.setString("phoneNumber", data["phone"]);
      await prefs.setString("busId", data["busId"]);
      await prefs.setString("busNumber", data["busId"]);
      await prefs.setString("routeName", data["busName"]);
      await prefs.setString("shift", data["shift"]);

      setState(() {
        permBusNumber = data["busId"];
        permRouteName = data["busName"];
        busId = data["busId"];
        shift = data["shift"] ?? "-";
        permBusId = data["busId"];
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
          const SizedBox(height: 20),

// 1️⃣ BUS INFORMATION CARD
          _infoCard(
            title: 'Bus Information',
            children: [
              _infoRow('Route', permRouteName),
              _infoRow('Bus Number', permBusNumber),
              _infoRow('Shift', shift),
            ],
          ),

          const SizedBox(height: 16),

// 2️⃣ TEMPORARY CARD (SEPARATE — NOT INSIDE)
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

// 3️⃣ LOCATION STATUS
          _infoCard(
            title: 'Location Status',
            children: [
              _statusRow('GPS', gpsOn, tripStarted),
              _statusRow('Internet', internetOn, tripStarted),
              _statusRow('Location Sync', locationSyncOn, tripStarted),
            ],
          ),

          if (tripStarted)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Stack(
                    children: [
                      SizedBox(
                        height: 250,
                        child: GoogleMap(
                          initialCameraPosition: CameraPosition(
                            target: _currentLatLng,
                            zoom: 16,
                          ),
                          onMapCreated: (controller) {
                            _mapController = controller;
                          },
                          myLocationEnabled: true,
                          myLocationButtonEnabled: true,
                          markers: {
                            if (_driverMarker != null) _driverMarker!,
                            if (_startMarker != null) _startMarker!,
                            if (_endMarker != null) _endMarker!,
                          },
                          polylines: _polylines,
                        ),
                      ),
                      Positioned.fill(
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () {
                              print("Route points count = ${_routePoints.length}");

                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => DriverFullMapPage(
                                    currentLatLng: _currentLatLng,
                                    marker: _driverMarker,

                                    routePoints: List.from(_routePoints),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
            child: tripStarted
                ? GestureDetector(
              onTap: _endTripFromBackend,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 18),
                decoration: BoxDecoration(
                  color: Colors.red,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: const Center(
                  child: Text(
                    'End Trip',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            )
                : Column(
              children: [
                GestureDetector(
                  onTap: () => _startTripWithMode("MORNING"),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    decoration: BoxDecoration(
                      color: const Color(0xFF00BFA6),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: const Center(
                      child: Text(
                        'Start Morning Trip',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                GestureDetector(
                  onTap: () => _startTripWithMode("EVENING"),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    decoration: BoxDecoration(
                      color: Colors.orange,
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: const Center(
                      child: Text(
                        'Start Evening Trip',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                ),
              ],
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
