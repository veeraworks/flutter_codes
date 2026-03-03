import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'service/api_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'dart:math';

class DriverMapPage extends StatefulWidget {
  const DriverMapPage({super.key});

  @override
  State<DriverMapPage> createState() => _DriverMapPageState();
}

class _DriverMapPageState extends State<DriverMapPage> {

  GoogleMapController? _mapController;

  LatLng? _driverLocation;
  double _driverBearing = 0;
  double _currentSpeed = 0;

  final DatabaseReference _busRef =
  FirebaseDatabase.instance.ref();

  bool _followBus = true;
  LatLng? _lastEtaLocation;
  LatLng? _cameraPosition;
  Timer? _cameraTimer;

  double _lookAheadDistance = 40; // meters ahead
  IconData _navIcon = Icons.navigation;
  double? _etaMinutes;
  String? _nextStopName;
  List<dynamic> _navSteps = [];
  String? _nextInstruction;
  String? _instructionDistance;

  double? _remainingMeters;
  LatLng? _currentStepTarget;

  Timer? _etaTimer;
  BitmapDescriptor? _busIcon;
  Set<Marker> _stopMarkers = {};
  Marker? _busMarker;
  Set<Polyline> _polylines = {};
  StreamSubscription<DatabaseEvent>? _polylineListener;
  StreamSubscription<DatabaseEvent>? _busLocationListener;
  List<Map<String, dynamic>> _routeStops = [];
  List<LatLng> _routePoints = [];
  bool _arrivalTriggered = false;

  bool _routeFitted = false;
  String? busId;

  // ================= INIT =================

  @override
  void initState() {
    super.initState();
    _initDriverMap();
  }

  Future<void> _initDriverMap() async {
    await _loadPrefs();

    if (busId == null) {
      print("❌ busId not found");
      return;
    }

    _listenToBusLocation();
    await _loadBusIcon();
    _driverLocation = const LatLng(12.9516, 80.1462);
    _updateDriverMarker();

    await _listenRoutePolyline();

    _etaTimer = Timer.periodic(
      const Duration(seconds: 20),
          (_) => _fetchDriverETA(),
    );
  }
  void _updateNavigationInstruction() {
    if (_navSteps.isEmpty) return;

    final step = _navSteps.first;

    String maneuver = step["maneuver"] ?? "straight";

    IconData icon;

    switch (maneuver) {
      case "turn-left":
        icon = Icons.turn_left;
        break;

      case "turn-right":
        icon = Icons.turn_right;
        break;

      case "keep-left":
        icon = Icons.turn_slight_left;
        break;

      case "keep-right":
        icon = Icons.turn_slight_right;
        break;

      case "roundabout-left":
      case "roundabout-right":
        icon = Icons.roundabout_left;
        break;

      default:
        icon = Icons.straight;
    }

    setState(() {
      _nextInstruction = step["instruction"];
      _instructionDistance = step["distanceText"];
      _navIcon = icon;
    });
  }
  void _listenToBusLocation() {
    if (busId == null) return;

    _busLocationListener = FirebaseDatabase.instance
        .ref("buses/$busId/current")
        .onValue
        .listen((event) {

      final data = event.snapshot.value as Map?;
      if (data == null) return;

      final lat = data["lat"];
      final lng = data["lng"];
      final bearing = data["bearing"];
      final speed = data["speed"];

      if (lat == null || lng == null) return;

      setState(() {
        _driverLocation = LatLng(
          (lat as num).toDouble(),
          (lng as num).toDouble(),
        );

        _driverBearing = (bearing ?? 0).toDouble();
        _currentSpeed = (speed ?? 0).toDouble();

        _updateDriverMarker();
      });
      if (_followBus && _driverLocation != null) {
        _startNavigationCamera(_driverLocation!);
      }
    });
  }
  Future<void> _loadPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    busId = prefs.getString("busId")?.toUpperCase();

    print("BUS ID = $busId");
  }

  Future<void> _loadBusIcon() async {
    _busIcon = await BitmapDescriptor.fromAssetImage(
      const ImageConfiguration(size: Size(100, 100)),
      "assets/images/bus_icon_map.png",
    );
  }
  void _startNavigationCamera(LatLng busPos) {
    if (!_followBus || _mapController == null) return;

    _cameraTimer?.cancel();

    _cameraTimer =
        Timer.periodic(const Duration(milliseconds: 40), (timer) {
          LatLng lookAhead =
          _projectForward(busPos, _driverBearing, _lookAheadDistance);

          _cameraPosition ??= lookAhead;

          double lat = _cameraPosition!.latitude +
              (lookAhead.latitude - _cameraPosition!.latitude) * 0.08;

          double lng = _cameraPosition!.longitude +
              (lookAhead.longitude - _cameraPosition!.longitude) * 0.08;

          _cameraPosition = LatLng(lat, lng);

          _mapController?.moveCamera(
            CameraUpdate.newCameraPosition(
              CameraPosition(
                target: _cameraPosition!,
                zoom: 17,
                tilt: 55,
                bearing: _driverBearing,
              ),
            ),
          );
        });
  }

  LatLng _projectForward(LatLng start,
      double bearing,
      double distanceMeters,) {
    const earthRadius = 6371000.0;

    double brng = bearing * (pi / 180);

    double lat1 = start.latitude * (pi / 180);
    double lon1 = start.longitude * (pi / 180);

    double lat2 = asin(
      sin(lat1) * cos(distanceMeters / earthRadius) +
          cos(lat1) *
              sin(distanceMeters / earthRadius) *
              cos(brng),
    );

    double lon2 = lon1 +
        atan2(
          sin(brng) *
              sin(distanceMeters / earthRadius) *
              cos(lat1),
          cos(distanceMeters / earthRadius) -
              sin(lat1) * sin(lat2),
        );

    return LatLng(lat2 * 180 / pi, lon2 * 180 / pi);
  }

// ================= DRIVER ETA =================
  Future<void> _fetchDriverETA() async {
    print("==== DRIVER ETA START ====");
    print("busId = $busId");
    print("driverLocation = $_driverLocation");
    print("routeStops length = ${_routeStops.length}");

    if (busId == null) return;
    if (_driverLocation == null) return;
    if (_driverLocation!.latitude == 0 ||
        _driverLocation!.longitude == 0) {
      print("❌ ETA skipped — invalid GPS (0,0)");
      return;
    }
    if (_routeStops.isEmpty) {
      print("❌ ETA skipped — routeStops empty");
      return;
    }

    final lastStop = _routeStops.last;

    final destLat = lastStop["lat"];
    final destLng = lastStop["lng"];

    if (destLat == null || destLng == null) {
      print("❌ ETA skipped — invalid stop coordinates");
      print("LastStop = $lastStop");
      return;
    }

    // Avoid frequent calls if bus hasn't moved much
    if (_lastEtaLocation != null &&
        Geolocator.distanceBetween(
          _lastEtaLocation!.latitude,
          _lastEtaLocation!.longitude,
          _driverLocation!.latitude,
          _driverLocation!.longitude,
        ) < 15) {
      return;
    }

    _lastEtaLocation = _driverLocation;

    try {
      print("📡 Calling ETA API safely...");

      final data = await ApiService.getDriverEta(
        busId: busId!,
        originLat: _driverLocation!.latitude,
        originLng: _driverLocation!.longitude,
        destLat: (destLat as num).toDouble(),
        destLng: (destLng as num).toDouble(),
        nextStop: _nextStopName ?? "",
      );

      if (data == null) {
        print("❌ ETA API returned null");
        return;
      }

      print("✅ ETA Response received");

      // ================= TURN BY TURN =================
      _navSteps = data["steps"] ?? [];
      _updateNavigationInstruction();
      _prepareStepTarget();

      // ================= ETA UPDATE =================
      setState(() {
        final duration = data["durationValue"];

        if (duration != null && duration is num) {
          _etaMinutes = duration.toDouble() / 60.0;
        } else {
          _etaMinutes = null;
        }

        _nextStopName = data["nextStop"];
      });

    } catch (e) {
      print("❌ Driver ETA error: $e");
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

// ================= MAP MATCHING (ROUTE ENGINE) =================

  LatLng _snapToRoute(LatLng gpsPoint) {
    if (_routePoints.isEmpty) return gpsPoint;

    double minDistance = double.infinity;
    LatLng closestPoint = gpsPoint;

    for (final p in _routePoints) {
      final d = Geolocator.distanceBetween(
        gpsPoint.latitude,
        gpsPoint.longitude,
        p.latitude,
        p.longitude,
      );

      if (d < minDistance) {
        minDistance = d;
        closestPoint = p;
      }
    }

    return closestPoint;
  }

  void _prepareStepTarget() {
    if (_routePoints.isEmpty || _driverLocation == null) return;

    // find closest route point
    int closestIndex = 0;
    double minDist = double.infinity;

    for (int i = 0; i < _routePoints.length; i++) {
      final d = Geolocator.distanceBetween(
        _driverLocation!.latitude,
        _driverLocation!.longitude,
        _routePoints[i].latitude,
        _routePoints[i].longitude,
      );

      if (d < minDist) {
        minDist = d;
        closestIndex = i;
      }
    }

    int targetIndex = (closestIndex + 20)
        .clamp(0, _routePoints.length - 1);

    _currentStepTarget = _routePoints[targetIndex];
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

  void _updateStepDistance() {
    if (_driverLocation == null || _currentStepTarget == null) return;

    final distance = Geolocator.distanceBetween(
      _driverLocation!.latitude,
      _driverLocation!.longitude,
      _currentStepTarget!.latitude,
      _currentStepTarget!.longitude,
    );

    setState(() {
      _remainingMeters = distance;
    });
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

    _busMarker = Marker(
      markerId: const MarkerId("bus"),
      position: _driverLocation!,
      icon: _busIcon ?? BitmapDescriptor.defaultMarker,
      rotation: _driverBearing,
      anchor: const Offset(0.5, 0.5),
      flat: true,
    );
  }
// ================= ROUTE STOPS =================
  Future<void> _fetchRouteStops() async {
    if (busId == null) return;

    try {
      final response = await ApiService.get("/routes/$busId");

      if (response.statusCode != 200) return;

      final List stops = jsonDecode(response.body);

      _routeStops = List<Map<String, dynamic>>.from(stops);

      Set<Marker> stopMarkers = {};
      List<LatLng> routePoints = [];

      for (var stop in stops) {
        bool isLastStop =
            stop["stopOrder"] == stops.last["stopOrder"];

        LatLng pos = LatLng(
          (stop["lat"] as num).toDouble(),
          (stop["lng"] as num).toDouble(),
        );

        routePoints.add(pos);

        stopMarkers.add(
          Marker(
            markerId: MarkerId(stop["stopName"]),
            position: pos,
            infoWindow: InfoWindow(
              title: stop["stopName"],
            ),
            icon: isLastStop
                ? BitmapDescriptor.defaultMarkerWithHue(
                BitmapDescriptor.hueRed) // 🔴 FINAL DROP
                : _getStopColor(stop["stopName"]),
          ),
        );
      }

      print("Stops API raw response: ${response.body}");
      print("Stops status code: ${response.statusCode}");

      setState(() {
        _stopMarkers = stopMarkers;   // ✅ ONLY STOP MARKERS
      });

      // Fit route once
      if (!_routeFitted && routePoints.isNotEmpty) {
        _fitRouteToScreen(routePoints);
        _routeFitted = true;
      }

    } catch (e) {
      print("Route fetch error: $e");
    }
  }
// ================= ROUTE POLYLINE LISTENER =================
  Future<void> _listenRoutePolyline() async {
    if (busId == null) return;

    _polylineListener?.cancel();

    _polylineListener = FirebaseDatabase.instance
        .ref("busRoutes/$busId/fullRoadPolyline")
        .onValue
        .listen((event) {
      final data = event.snapshot.value;

      if (data == null) return;

      String encodedPolyline = data.toString();

      PolylinePoints polylinePoints = PolylinePoints();

      List<PointLatLng> decoded =
      polylinePoints.decodePolyline(encodedPolyline);

      List<LatLng> points =
      decoded.map((p) => LatLng(p.latitude, p.longitude)).toList();

      setState(() {
        _polylines = {
          Polyline(
            polylineId: const PolylineId("route"),
            points: points,
            width: 6,
            color: Colors.blue,
          ),
        };
        print("Polyline data = $data");
        print("Decoded count = ${decoded.length}");
        _routePoints = points;
      });
    });
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

    _mapController?.animateCamera(
      CameraUpdate.newLatLngBounds(bounds, 80),
    );
  }

// ================= DISPOSE =================

  @override
  void dispose() {
    _polylineListener?.cancel();
    _etaTimer?.cancel();
    _busLocationListener?.cancel();
    _cameraTimer?.cancel();
    _mapController?.dispose();
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

          // 🚍 DRIVER NEXT STOP PANEL

          // 🔥 TURN BY TURN CARD
          if (_nextInstruction != null)
            Positioned(
              top: 90,
              left: 20,
              right: 20,
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: const [
                    BoxShadow(
                      color: Colors.black26,
                      blurRadius: 8,
                    )
                  ],
                ),
                child: Row(
                  children: [

                    Icon(
                      _navIcon,
                      size: 32,
                      color: Colors.blue,
                    ),

                    const SizedBox(width: 12),

                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [

                          Text(
                            _nextInstruction!,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),

                          Text(
                            _remainingMeters != null
                                ? "in ${_remainingMeters!.toInt()} m"
                                : "in $_instructionDistance",
                            style: const TextStyle(
                              color: Colors.grey,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

          Positioned(
            bottom: 120,
            right: 20,
            child: FloatingActionButton(
              backgroundColor:
              _followBus ? Colors.blue : Colors.grey,
              onPressed: () {
                setState(() {
                  _followBus = !_followBus;
                });
              },
              child: Icon(
                _followBus
                    ? Icons.navigation
                    : Icons.navigation_outlined,
              ),
            ),
          ),


          // 🗺️ GOOGLE MAP
          GoogleMap(
            initialCameraPosition: const CameraPosition(
              target: LatLng(13.0827, 80.2707),
              zoom: 14,
            ),
            onMapCreated: (controller) async {
              _mapController = controller;
              await _fetchRouteStops();   // ✅ ONLY HERE
              _fetchDriverETA();  // ✅ trigger first ETA after stops loaded
            },
            myLocationEnabled: false,
            myLocationButtonEnabled: false,
            markers: {
              if (_busMarker != null) _busMarker!,
              ..._stopMarkers,
            },
            polylines: _polylines,
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