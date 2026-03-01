import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'service/api_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_database/firebase_database.dart';
import 'driver_full_map_page.dart';

class DriverMapPage extends StatefulWidget {
  const DriverMapPage({super.key});

  @override
  State<DriverMapPage> createState() => _DriverMapPageState();
}

class _DriverMapPageState extends State<DriverMapPage> {

  GoogleMapController? _mapController;

  LatLng? _driverLocation;
  double _driverBearing = 0;

  final DatabaseReference _busRef =
  FirebaseDatabase.instance.ref();

  double? _etaMinutes;
  String? _nextStopName;
  Timer? _etaTimer;
  BitmapDescriptor? _busIcon;
  Set<Marker> _markers = {};
  Set<Polyline> _polylines = {};

  List<Map<String, dynamic>> _routeStops = [];
  List<LatLng> _routePoints = [];
  bool _arrivalTriggered = false;

  StreamSubscription<Position>? _gpsSubscription;

  String? busId;

  // ================= INIT =================

  @override
  void initState() {
    super.initState();
    _initDriverMap();
  }

  Future<void> _initDriverMap() async {
    await _loadPrefs();
    await _loadBusIcon();
    await _startDriverGPS();
    await _fetchRouteStops();
    await _fetchDriverETA();

    _etaTimer = Timer.periodic(
      const Duration(seconds: 20),
          (_) => _fetchDriverETA(),
    );
  }

  Future<void> _loadPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    busId = prefs.getString("busId");
  }

  Future<void> _loadBusIcon() async {
    _busIcon = await BitmapDescriptor.fromAssetImage(
      const ImageConfiguration(size: Size(100, 100)),
      "assets/images/bus_icon_map.png",
    );
  }

  // ================= DRIVER CAMERA =================

  void _updateDriverCamera(LatLng pos, double bearing) {
    if (_mapController == null) return;

    _mapController!.moveCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(
          target: pos,
          zoom: 17,
          tilt: 55,
          bearing: bearing,
        ),
      ),
    );
  }

  // ================= GPS LISTENER =================

  Future<void> _startDriverGPS() async {
    bool enabled = await Geolocator.isLocationServiceEnabled();
    if (!enabled) return;

    await Geolocator.requestPermission();

    _gpsSubscription =
        Geolocator.getPositionStream(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.bestForNavigation,
            distanceFilter: 3,
          ),
        ).listen((Position position) {
          _driverLocation = LatLng(
            position.latitude,
            position.longitude,
          );

          _driverBearing = position.heading;

          _updateDriverCamera(
            _driverLocation!,
            _driverBearing,
          );

          _updateDriverMarker();
          _publishDriverLocation();
          _checkStopArrival();
        });
  }

// ================= DRIVER ETA =================

  Future<void> _fetchDriverETA() async {
    if (busId == null) return;

    try {
      final response =
      await ApiService.get("/drivers/eta/$busId");

      if (response.statusCode != 200) return;

      final data = jsonDecode(response.body);

      setState(() {
        _etaMinutes =
            (data["etaMinutes"] as num?)?.toDouble();
        _nextStopName = data["nextStop"];
      });
      _fetchRouteStops();
    } catch (e) {
      print("Driver ETA error: $e");
    }
  }

// ================= DISTANCE HELPER =================

  double _distanceMeters(LatLng a, LatLng b) {
    return Geolocator.distanceBetween(
      a.latitude,
      a.longitude,
      b.latitude,
      b.longitude,
    );
  }

  BitmapDescriptor _getStopColor(String stopName) {
    if (_nextStopName == null) {
      return BitmapDescriptor.defaultMarkerWithHue(
        BitmapDescriptor.hueOrange,
      );
    }

    if (stopName == _nextStopName) {
      return BitmapDescriptor.defaultMarkerWithHue(
        BitmapDescriptor.hueBlue,
      ); // NEXT STOP
    }

    final nextIndex = _routeStops.indexWhere(
          (s) => s["stopName"] == _nextStopName,
    );

    final stopIndex = _routeStops.indexWhere(
          (s) => s["stopName"] == stopName,
    );

    if (stopIndex < nextIndex) {
      return BitmapDescriptor.defaultMarkerWithHue(
        BitmapDescriptor.hueGreen,
      ); // PASSED
    }

    return BitmapDescriptor.defaultMarkerWithHue(
      BitmapDescriptor.hueOrange,
    ); // UPCOMING
  }

// ================= AUTO STOP DETECTION =================

  Future<void> _checkStopArrival() async {
    if (_driverLocation == null ||
        _nextStopName == null ||
        _arrivalTriggered) return;

    final nextStop = _routeStops.firstWhere(
          (s) => s["stopName"] == _nextStopName,
      orElse: () => {},
    );

    if (nextStop.isEmpty) return;

    LatLng stopPos = LatLng(
      (nextStop["lat"] as num).toDouble(),
      (nextStop["lng"] as num).toDouble(),
    );

    double distance =
    _distanceMeters(_driverLocation!, stopPos);

    // 🚍 ARRIVED CONDITION (25 meters)
    if (distance < 25) {
      _arrivalTriggered = true;

      print("✅ Arrived at $_nextStopName");

      await _notifyBackendArrival();
    }
  }

// ================= BACKEND ARRIVAL NOTIFY =================

  Future<void> _notifyBackendArrival() async {
    if (busId == null || _nextStopName == null) return;

    try {
      await ApiService.post(
        "/drivers/arrived",
        {
          "busId": busId,
          "stopName": _nextStopName,
        },
      );

      print("📡 Backend notified: arrived at $_nextStopName");

      // allow next detection after cooldown
      Future.delayed(const Duration(seconds: 20), () {
        _arrivalTriggered = false;
      });
    } catch (e) {
      print("Arrival notify error: $e");
    }
  }

  // ================= DRIVER MARKER =================

  void _updateDriverMarker() {
    if (_driverLocation == null) return;

    _markers.removeWhere(
            (m) => m.markerId.value == "bus");

    _markers.add(
      Marker(
        markerId: const MarkerId("bus"),
        position: _driverLocation!,
        icon: _busIcon ?? BitmapDescriptor.defaultMarker,
        rotation: _driverBearing,
        anchor: const Offset(0.5, 0.5),
        flat: true,
      ),
    );

    setState(() {});
  }

// ================= FIREBASE PUBLISH =================

  Future<void> _publishDriverLocation() async {
    if (busId == null || _driverLocation == null) return;

    try {
      await _busRef
          .child("buses/$busId/current")
          .set({
        "lat": _driverLocation!.latitude,
        "lng": _driverLocation!.longitude,
        "bearing": _driverBearing,
        "timestamp": DateTime
            .now()
            .millisecondsSinceEpoch,
      });
    } catch (e) {
      print("Firebase publish error: $e");
    }
  }

  // ================= ROUTE STOPS =================

  Future<void> _fetchRouteStops() async {
    if (busId == null) return;

    try {
      final response =
      await ApiService.get("/routes/$busId");

      if (response.statusCode != 200) return;

      final List stops = jsonDecode(response.body);
      _routeStops = List<Map<String, dynamic>>.from(stops);

      Set<Marker> stopMarkers = {};
      List<LatLng> routePoints = [];

      for (var stop in stops) {
        LatLng pos = LatLng(
          (stop["lat"] as num).toDouble(),
          (stop["lng"] as num).toDouble(),
        );

        routePoints.add(pos);

        stopMarkers.add(
          Marker(
            markerId:
            MarkerId(stop["stopName"]),
            position: pos,
            infoWindow: InfoWindow(
              title: stop["stopName"],
            ),
            icon: _getStopColor(stop["stopName"]),
          ),
        );
      }

      setState(() {
        _markers.removeWhere(
                (m) => m.markerId.value != "bus");

        _markers.addAll(stopMarkers);
        _routePoints = routePoints;
      });

      _fitRouteToScreen(routePoints);
    } catch (e) {
      print("Route fetch error: $e");
    }
  }

  // ================= FIT ROUTE =================

  void _fitRouteToScreen(List<LatLng> points) {
    if (_mapController == null || points.isEmpty) return;

    double minLat = points.first.latitude;
    double maxLat = points.first.latitude;
    double minLng = points.first.longitude;
    double maxLng = points.first.longitude;

    for (var p in points) {
      if (p.latitude < minLat) minLat = p.latitude;
      if (p.latitude > maxLat) maxLat = p.latitude;
      if (p.longitude < minLng) minLng = p.longitude;
      if (p.longitude > maxLng) maxLng = p.longitude;
    }

    LatLngBounds bounds = LatLngBounds(
      southwest: LatLng(minLat, minLng),
      northeast: LatLng(maxLat, maxLng),
    );

    _mapController!.animateCamera(
      CameraUpdate.newLatLngBounds(bounds, 80),
    );
  }

  // ================= DISPOSE =================

  @override
  void dispose() {
    _gpsSubscription?.cancel();
    _etaTimer?.cancel();
    super.dispose();
  }

  // ================= UI =================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Driver Navigation"),
      ),

      body: Stack(
        children: [

          // 🗺️ GOOGLE MAP
          GoogleMap(
            initialCameraPosition: const CameraPosition(
              target: LatLng(13.0827, 80.2707),
              zoom: 14,
            ),
            onMapCreated: (controller) {
              _mapController = controller;
            },
            myLocationEnabled: true,
            myLocationButtonEnabled: false,
            markers: _markers,
            polylines: _polylines,
          ),

          Positioned(
            top: 20,
            right: 20,
            child: FloatingActionButton(
              heroTag: "fullMap",
              backgroundColor: Colors.black87,
              child: const Icon(Icons.fullscreen),
              onPressed: () {
                if (_driverLocation == null) return;

                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => DriverFullMapPage(
                      currentLatLng: _driverLocation!,
                      marker: _markers.firstWhere(
                            (m) => m.markerId.value == "bus",
                        orElse: () => Marker(
                          markerId: const MarkerId("bus"),
                          position: _driverLocation!,
                        ),
                      ),
                      routePoints: _routePoints,
                    ),
                  ),
                );
              },
            ),
          ),

          // 🚍 DRIVER NEXT STOP PANEL
          if (_nextStopName != null)
            Positioned(
              bottom: 20,
              left: 20,
              right: 20,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.black87,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: const [
                    BoxShadow(
                      color: Colors.black26,
                      blurRadius: 10,
                      offset: Offset(0, 4),
                    )
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [

                    const Text(
                      "NEXT STOP",
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                        letterSpacing: 1.2,
                      ),
                    ),

                    const SizedBox(height: 6),

                    Text(
                      _nextStopName!,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),

                    if (_etaMinutes != null) ...[
                      const SizedBox(height: 6),
                      Text(
                        "ETA ${_etaMinutes!.toInt()} mins",
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}