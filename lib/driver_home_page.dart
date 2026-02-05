import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
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

  final FlutterLocalNotificationsPlugin notifications =
  FlutterLocalNotificationsPlugin();

  void initNotifications() async {
    const androidSettings =
    AndroidInitializationSettings('@mipmap/ic_launcher');

    const settings = InitializationSettings(android: androidSettings);

    await notifications.initialize(settings);
  }

  Future<void> showBusAlert(String stopName) async {
    const androidDetails = AndroidNotificationDetails(
      'bus_alerts',
      'Bus Alerts',
      importance: Importance.high,
      priority: Priority.high,
    );

    const details = NotificationDetails(android: androidDetails);

    await notifications.show(
      0,
      '🚌 Bus Arriving',
      'Your bus is near $stopName',
      details,
    );
  }

  void listenForBusArrival(
      String busId,
      double stopLat,
      double stopLng,
      String stopName,
      ) {
    final busRef = FirebaseDatabase.instance.ref('buses/$busId');

    busRef.onValue.listen((event) {
      if (!event.snapshot.exists) return;

      final data = event.snapshot.value as Map;

      final double busLat = data['lat'];
      final double busLng = data['lng'];

      final double distance = Geolocator.distanceBetween(
        busLat,
        busLng,
        stopLat,
        stopLng,
      );

      if (distance <= 300) {
        showBusAlert(stopName);
      }
    });
  }

  bool tripStarted = false;

  bool gpsOn = false;
  bool internetOn = false;
  bool locationSyncOn = false;

  String? busId;
  StreamSubscription<Position>? positionStream;

  // 🗺️ MAP STATE
  GoogleMapController? _mapController;
  Marker? _driverMarker;
  LatLng _currentLatLng = const LatLng(13.0827, 80.2707); // default

  @override
  void initState() {
    super.initState();
    _loadBusId();
    _checkStatuses();

    @override
    void initState() {
      super.initState();
      _loadBusId();
      _checkStatuses();

      initNotifications();// 🔔 NEW: notification init

      listenForBusArrival( // 🔔 NEW: listen for bus arrival
        "BUS10",        // busId
        12.9516,        // stop latitude
        80.1462,        // stop longitude
        "Chrompet",     // stop name
      );
    }
  }

  @override
  void dispose() {
    positionStream?.cancel();
    super.dispose();
  }
  // 🧵 ROUTE POLYLINE STATE
  final List<LatLng> _routePoints = [];
  Set<Polyline> _polylines = {};

  // ================= LOAD BUS ID =================
  Future<void> _loadBusId() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      busId = prefs.getString("busId");
    });
  }

  // ---------------- CHECK GPS / INTERNET ----------------------
  Future<void> _checkStatuses() async {
    final gpsEnabled = await Geolocator.isLocationServiceEnabled();
    final connectivity = await Connectivity().checkConnectivity();
    final netEnabled = connectivity != ConnectivityResult.none;

    setState(() {
      gpsOn = gpsEnabled;
      internetOn = netEnabled;
      locationSyncOn = tripStarted && gpsOn && internetOn;
    });
  }

  // ================= START GPS TRACKING =================
  Future<void> _startLocationUpdates() async {
    LocationPermission permission = await Geolocator.checkPermission();

    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.deniedForever) return;

    positionStream?.cancel();

    positionStream = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 5,
      ),
    ).listen((position) {
      if (!tripStarted || busId == null) return;

      final latLng = LatLng(position.latitude, position.longitude);

      setState(() {
        // 📍 update marker
        _driverMarker = Marker(
          markerId: const MarkerId("driver"),
          position: latLng,
          icon: BitmapDescriptor.defaultMarkerWithHue(
            BitmapDescriptor.hueGreen,
          ),
        );

        // 📌 add route point
        _routePoints.add(latLng);

        // 🧵 draw polyline
        _polylines.clear();
        _polylines.add(
          Polyline(
            polylineId: const PolylineId("route"),
            points: _routePoints,
            color: Colors.blue,
            width: 5,
          ),
        );
      });

      // 🎥 move camera
      _mapController?.animateCamera(
        CameraUpdate.newLatLng(latLng),
      );

      // 🔥 Firebase update
      FirebaseDatabase.instance.ref("buses/$busId").set({
        "lat": position.latitude,
        "lng": position.longitude,
        "updatedAt": ServerValue.timestamp,
      });
    });

  }

  // ---------------- START / END TRIP ----------------
  Future<void> _toggleTrip() async {
    await _checkStatuses();

    // ❌ Bus ID missing
    if (busId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Bus ID not found")),
      );
      return;
    }

    // ================= START TRIP =================
    if (!tripStarted) {
      // GPS check
      if (!gpsOn) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Please enable GPS")),
        );
        await Geolocator.openLocationSettings();
        return;
      }

      // Internet check
      if (!internetOn) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Please enable Internet")),
        );
        return;
      }

      // 🔥 Firebase: Trip started
      await FirebaseDatabase.instance
          .ref("busTrips/$busId/status")
          .set("STARTED");

      setState(() {
        tripStarted = true;
        _routePoints.clear();   // ✅ start fresh route
        _polylines.clear();
      });

      // ▶ Start GPS tracking
      await _startLocationUpdates();

    }
    // ================= END TRIP =================
    else {
      // 🔥 Firebase: Trip ended
      await FirebaseDatabase.instance
          .ref("busTrips/$busId/status")
          .set("ENDED");

      // ⛔ Stop GPS tracking
      await positionStream?.cancel();
      positionStream = null;

      setState(() {
        tripStarted = false;
        _routePoints.clear();   // ✅ clear route
        _polylines.clear();     // ✅ remove polyline from map
      });
    }

    await _checkStatuses();
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
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const TemporaryBusChangePage()),
              ),
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
          // HEADER (unchanged)
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
                      tripStarted ? 'ON DUTY' : 'OFF DUTY',
                      style: const TextStyle(color: Colors.white70),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          _infoCard(
            title: 'Bus Information',
            children: const [
              _infoRow('Route', 'Madambakkam'),
              _infoRow('Bus Number', '9'),
              _infoRow('Shift', 'Morning'),
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

          // 🗺️ MAP (ONLY WHEN TRIP STARTED)
          if (tripStarted)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Stack(
                    children: [

                      // 🗺️ GOOGLE MAP
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
                          markers: _driverMarker != null
                              ? {_driverMarker!}
                              : {},
                          polylines: _polylines,
                        ),
                      ),

                      // 👆 TAP DETECTOR LAYER
                      Positioned.fill(
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => DriverFullMapPage(
                                    currentLatLng: _currentLatLng,
                                    marker: _driverMarker,
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
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: GestureDetector(
              onTap: _toggleTrip,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 18),
                decoration: BoxDecoration(
                  color: tripStarted ? Colors.red : const Color(0xFF00BFA6),
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
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style: const TextStyle(
                    fontSize: 18, fontWeight: FontWeight.w600)),
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
        Text(value,
            style: const TextStyle(fontWeight: FontWeight.w500)),
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
