import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:firebase_database/firebase_database.dart';
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
  bool _initialized = false;
  // 🔑 BUS INFO STATE (ADDED)
  String busNumber = "-";
  String routeName = "-";
  String shift = "-";
  bool isTempBusActive = false;


  bool gpsOn = false;
  bool internetOn = false;
  bool locationSyncOn = false;

  String? busId;
  StreamSubscription<Position>? positionStream;

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
    positionStream?.cancel();
    super.dispose();
  }

  // ================= LOAD BUS ID ====================================
  Future<void> _loadBusId() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      busId = prefs.getString("busId");
    });
  }
// ================= LOAD BUS INFO (ADDED) =================
  Future<void> _loadBusInfo() async {
    final prefs = await SharedPreferences.getInstance();

    setState(() {
      busNumber = prefs.getString("busNumber") ?? "-";
      routeName = prefs.getString("routeName") ?? "-";
      shift = prefs.getString("shift") ?? "-";
      isTempBusActive = prefs.getBool("isTempBusActive") ?? false;
    });
    print("HOME RELOAD → busNumber=$busNumber, isTempBusActive=$isTempBusActive");
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
    ).listen((position) {print("GPS UPDATE → ${position.latitude}, ${position.longitude}");

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
      if (busId != null) {
        FirebaseDatabase.instance.ref("buses/$busId").set({
          "lat": position.latitude,
          "lng": position.longitude,
          "bearing": position.heading,
          "updatedAt": ServerValue.timestamp,
        }).catchError((e) {
          // optional: log error but don't block UI
          print("Failed to update bus location: $e");
        });
      }
    });
  }

  // ---------------- START / END TRIP --------------------------------------
  Future<void> _toggleTrip() async {
    await _checkStatuses();

    // 🔍 DEBUG LINE — PASTE EXACTLY HERE
    print("busId: $busId, gpsOn: $gpsOn, internetOn: $internetOn");

    // Do NOT return early when busId is null — allow local start/end
    if (!tripStarted) {
      if (!gpsOn) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Please enable GPS")),
        );
        await Geolocator.openLocationSettings();
        return;
      }

      if (!internetOn) {
        // allow starting locally but warn the user
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Internet is off — tracking will run locally")),
        );
      }

      // Immediately update UI so button changes to "End Trip" and map appears
      setState(() {
        tripStarted = true;
        _routePoints.clear();
        _polylines.clear();
        _startMarker = Marker(
          markerId: const MarkerId("start"),
          position: _currentLatLng,
          icon: BitmapDescriptor.defaultMarkerWithHue(
            BitmapDescriptor.hueGreen,
          ),
        );
      });

      SharedPreferences.getInstance().then((prefs) {
        prefs.setBool("trackingActive", true);
      });

      // Start location updates without blocking the UI (don't await)
      _startLocationUpdates();

      // Update Firebase status non-blocking (only if busId present)
      if (busId != null) {
        FirebaseDatabase.instance
            .ref("busTrips/$busId/status")
            .set("STARTED")
            .catchError((e) {
          print("Failed to set STARTED status: $e");
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Bus ID not found — running in local mode")),
        );
      }
    } else {
      // End trip: cancel stream and update U I immediately
      await positionStream?.cancel();
      positionStream = null;
      if (_routePoints.isNotEmpty) {
        _endMarker = Marker(
          markerId: const MarkerId("end"),
          position: _routePoints.last,
          icon: BitmapDescriptor.defaultMarkerWithHue(
            BitmapDescriptor.hueRed,
          ),
        );
      }

      setState(() {
        tripStarted = false;
        _routePoints.clear();
        _polylines.clear();
      });

      SharedPreferences.getInstance().then((prefs) {
        prefs.setBool("trackingActive", false);
      });

      // Update Firebase status non-blocking if busId present
      if (busId != null) {
        FirebaseDatabase.instance
            .ref("busTrips/$busId/status")
            .set("ENDED")
            .catchError((e) {
          print("Failed to set ENDED status: $e");
        });
      }
      // 🔥 AUTO CLEAR TEMP BUS ON END TRIP
      final prefs = await SharedPreferences.getInstance();
      final bool isTempActive = prefs.getBool("isTempBusActive") ?? false;

      if (isTempActive) {
        await prefs.setBool("isTempBusActive", false);

        // optional backend update
        if (busId != null) {
          FirebaseDatabase.instance
              .ref("temporaryBus/$busId")
              .update({
            "active": false,
            "updatedAt": ServerValue.timestamp,
          });
        }

        // reload home page bus info
        await _loadBusInfo();
      }

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
              _infoRow('Route', routeName),
              _infoRow('Bus Number', busNumber),
              _infoRow('Shift', shift),

              if (isTempBusActive)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    "TEMPORARY BUS ACTIVE",
                    style: const TextStyle(
                      color: Colors.orange,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
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

                                    // 🔴 THIS LINE IS MANDATORY
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
