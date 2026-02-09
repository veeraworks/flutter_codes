import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'driver_full_map_page.dart';
import 'temporary_bus_change_page.dart';
import 'driver_profile_page.dart';
import 'driver_settings_page.dart';
import 'issue_reporting_page.dart';
import 'location_service.dart';

class DriverHomePage extends StatefulWidget {
  const DriverHomePage({super.key});

  @override
  State<DriverHomePage> createState() => _DriverHomePageState();
}

class _DriverHomePageState extends State<DriverHomePage> {
  bool tripStarted = false;
  bool _initialized = false;
  bool locationPermissionDenied = false;
  bool isTripActionInProgress = false;
  bool gpsOn = false;
  bool internetOn = false;
  bool locationSyncOn = false;

  String? busId;
  String driverName = "";
  String busNumber = "";
  String route = "";

  String originalBusNumber = "";
  String originalRoute = "";
  bool isTempBusActive = false;

  // 🗺️ MAP STATE
  GoogleMapController? _mapController;
  Marker? _driverMarker;
  LatLng _currentLatLng = const LatLng(13.0827, 80.2707); // default

  // 🧵 ROUTE POLYLINE STATE
  final List<LatLng> _routePoints = [];
  Set<Polyline> _polylines = {};


  @override
  void initState() {
    super.initState();
    _initialize();
    _loadDriverData();
  }

  Future<void> _initialize() async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.setBool("trackingActive", false);

    await _loadBusId();
    await _loadBusInfo();
    await _checkStatuses();

    setState(() {
      _initialized = true;
    });
  }

  @override
  void dispose() {
    super.dispose();
  }

  // ================= LOAD BUS ID ====================================
  Future<void> _loadBusId() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      busId = prefs.getString("busId");
    });
  }
// ================= LOAD BUS INFO =================================
  Future<void> _loadBusInfo() async {
    final prefs = await SharedPreferences.getInstance();

    setState(() {
      originalBusNumber = prefs.getString("originalBus") ?? "9";
      originalRoute = prefs.getString("originalRoute") ?? "Madambakkam";

      isTempBusActive = prefs.getBool("isTemporaryApplied") ?? false;

      if (isTempBusActive) {
        // Temporary values
        busNumber = prefs.getString("busNumber") ?? originalBusNumber;
        route = prefs.getString("route") ?? originalRoute;
      } else {
        // Permanent values
        busNumber = originalBusNumber;
        route = originalRoute;
      }
    });
  }

  //--------------- LOAD DRIVER DATA FROM FIRESTORE --------------
  Future<void> _loadDriverData() async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      debugPrint("No logged-in user found");
      return;
    }

    try {
      final doc = await FirebaseFirestore.instance
          .collection('driver')
          .doc(user.uid)
          .get();

      if (!doc.exists) {
        ("Driver document not found for UID: ${user.uid}");
        return;
      }

      final data = doc.data()!;       // 5️⃣ Read data safely

      setState(() {  // 6️⃣ Update state (ONLY identity + backend mapping)
        driverName = data['name'] ?? driverName;
        busId = data['busid'] ?? busId;
      });
    } catch (e) {
      debugPrint("Error loading driver data: $e");
    }
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
  }

  // ---------------- START / END TRIP --------------------------------------
  Future<void> _toggleTrip() async {
    if (isTripActionInProgress) return;
    isTripActionInProgress = true;

    await _checkStatuses();

    debugPrint("busId: $busId, gpsOn: $gpsOn, internetOn: $internetOn");

    // ================= START TRIP =================
    if (!tripStarted) {
      // GPS must be ON
      if (!gpsOn) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Please enable GPS")),
        );
        await Geolocator.openLocationSettings();
        isTripActionInProgress = false;
        return;
      }

      // Internet warning only (do not block)
      if (!internetOn) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Internet is off — tracking will sync when online"),
          ),
        );
      }

      // Update UI immediately
      setState(() {
        tripStarted = true;
        _routePoints.clear();
        _polylines.clear();
      });

      // Save local trip state
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool("trackingActive", true);

      // 🚀 START TRACKING (SINGLE SOURCE)
      if (busId != null) {
        LocationService.startTracking(busId!);

        // Update trip status in Firebase (non-blocking)
        FirebaseDatabase.instance
            .ref("busTrips/$busId/status")
            .set("STARTED")
            .catchError((e) {
          debugPrint("Failed to set STARTED status: $e");
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Bus ID not found — tracking disabled"),
          ),
        );
      }
    }

    // ================= END TRIP =================
    else {
      // 🛑 STOP TRACKING
      await LocationService.stopTracking();

      // Update UI immediately
      setState(() {
        tripStarted = false;
        _routePoints.clear();
        _polylines.clear();
      });

      // Save local trip state
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool("trackingActive", false);

      // Update trip status in Firebase (non-blocking)
      if (busId != null) {
        FirebaseDatabase.instance
            .ref("busTrips/$busId/status")
            .set("ENDED")
            .catchError((e) {
          debugPrint("Failed to set ENDED status: $e");
        });
      }
    }

    await _checkStatuses();
    isTripActionInProgress = false;
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
            // ======= MODERN DRIVER HEADER =======
            DrawerHeader(
              margin: EdgeInsets.zero,
              padding: EdgeInsets.zero,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF00BFA5), Color(0xFF00796B)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Avatar + status
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          CircleAvatar(
                            radius: 28,
                            backgroundColor: Colors.white,
                            child: Icon(
                              Icons.person,
                              size: 32,
                              color: Color(0xFF00796B),
                            ),
                          ),
                          Container(
                            padding:
                            const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          ),
                        ],
                      ),

                      const Spacer(),

                      // Driver name
                      Text(
                        driverName.isNotEmpty ? driverName : "Driver",
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),

                      const SizedBox(height: 4),

                      if (busId != null && busId!.isNotEmpty)
                        Text(
                          "Bus No: $busId",
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 14,
                          ),
                        ),

                      const SizedBox(height: 2),

                      if (route.isNotEmpty)
                        Text(
                          route,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white60,
                            fontSize: 13,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),

            // ======= MENU ITEMS =======
            ListTile(
              leading: const Icon(Icons.person),
              title: const Text("Profile"),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const DriverProfilePage()),
                );
              },
            ),

            ListTile(
              leading: const Icon(Icons.swap_horiz, color: Colors.orange),
              title: const Text("Temporary Bus Change"),
              onTap: () async {
                Navigator.pop(context);
                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const TemporaryBusChangePage(),
                  ),
                );
                if (result == true) {
                  await _loadBusInfo();
                  setState(() {});
                }
              },
            ),

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
            children: [
              // Display permanent/original bus info as the main Bus Information
              _infoRow('Route', originalRoute),
              _infoRow('Bus Number', originalBusNumber),
              _infoRow('Shift', 'Morning'),

              // Show temporary details only if temporary change is active
              if (isTempBusActive) ...[
                const SizedBox(height: 12),
                const Divider(),
                const SizedBox(height: 12),
                const Text(
                  'Temporary Bus Changes',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.orange,
                  ),
                ),
                const SizedBox(height: 8),
                _infoRow('Temporary Route', route),
                _infoRow('Temporary Bus Number', busNumber),
              ],
            ],
          ),

          const SizedBox(height: 16),

          _infoCard(
            title: 'Location Status',
            children: [
              if (locationPermissionDenied)
                const Padding(
                  padding: EdgeInsets.only(bottom: 8),
                  child: Text(
                    "Location permission denied. Enable it in settings.",
                    style: TextStyle(color: Colors.red, fontWeight: FontWeight.w600),
                  ),
                ),
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
                          myLocationEnabled: tripStarted,
                          myLocationButtonEnabled: tripStarted,
                          markers: _driverMarker != null
                              ? {_driverMarker!}
                              : {},
                          polylines: _polylines,
                        ),
                      ),
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
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
            child: GestureDetector(
              onTap: isTripActionInProgress ? null : _toggleTrip,
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
          )
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
