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
const String googleKey = "AIzaSyAeAYcObFrWvXkt3HEGutI7W6Pp7MOWv2k";

class KalmanLatLng {
  double q = 0.00001;
  double r = 0.001;

  double pLat = 1;
  double pLng = 1;

  double lat = 0;
  double lng = 0;

  bool initialized = false;

  LatLng process(LatLng measurement) {

    if (!initialized) {
      lat = measurement.latitude;
      lng = measurement.longitude;
      initialized = true;
      return measurement;
    }

    pLat = pLat + q;
    pLng = pLng + q;

    double kLat = pLat / (pLat + r);
    double kLng = pLng / (pLng + r);

    lat = lat + kLat * (measurement.latitude - lat);
    lng = lng + kLng * (measurement.longitude - lng);

    pLat = (1 - kLat) * pLat;
    pLng = (1 - kLng) * pLng;

    return LatLng(lat, lng);
  }
}

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

  final KalmanLatLng _gpsKalman = KalmanLatLng();

  final DatabaseReference _busRef =
  FirebaseDatabase.instance.ref();

  bool _followBus = true;
  LatLng? _realGpsLocation;
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
  Timer? _publishTimer;
  BitmapDescriptor? _busIcon;
  Set<Marker> _stopMarkers = {};
  Marker? _busMarker;
  Set<Polyline> _polylines = {};
  StreamSubscription<DatabaseEvent>? _polylineListener;
  List<Map<String, dynamic>> _routeStops = [];
  List<LatLng> _routePoints = [];
  int _currentRouteIndex = 0;
  bool _arrivalTriggered = false;
  LatLng? _lastRouteUpdate;
  DateTime? _lastDynamicRouteTime;
  StreamSubscription<DatabaseEvent>? _altRoutesListener;
  List<dynamic> _alternativeRoutes = [];

  int _lastSnappedIndex = 0;

  bool _routeFitted = false;
  String? busId;
  bool _firstLocationFix = false;

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

    await _loadBusIcon();

    await _listenRoutePolyline();
    await _listenAlternativeRoutes();
    await _fetchRouteStops();
    await _startDriverGPS();

    Timer.periodic(
      const Duration(minutes: 2),
          (_) => _checkBetterRoute(),
    );

    // 🚍 publish GPS every 3 seconds
    _publishTimer = Timer.periodic(
      const Duration(seconds: 3),
          (_) {
        _publishDriverLocation();
      },
    );

    _etaTimer?.cancel();

    _etaTimer = Timer.periodic(
      const Duration(seconds: 20),
          (_) => _fetchDriverETA(),
    );
  }

// ================= BUS SMOOTH ANIMATION =================
  Future<void> _animateBus(LatLng newPosition) async {

    if (_driverLocation == null) {
      _driverLocation = newPosition;

      if (mounted) {
        setState(() {
          _updateDriverMarker();
        });
      }
      return;
    }

    const int steps = 4;

    for (int i = 0; i < steps; i++) {

      await Future.delayed(
        Duration(milliseconds: _calculateAnimationDelay()),
      );

      if (_driverLocation == null) return;

      LatLng predicted = _predictNextPosition(newPosition);

      _driverLocation = LatLng(
        _driverLocation!.latitude +
            (predicted.latitude - _driverLocation!.latitude) * 0.3,
        _driverLocation!.longitude +
            (predicted.longitude - _driverLocation!.longitude) * 0.3,
      );

      if (!mounted) return;

      setState(() {
        _updateDriverMarker();
      });
    }
  }
  StreamSubscription<Position>? _gpsSubscription;

  Future<void> _startDriverGPS() async {

    await _gpsSubscription?.cancel();
    _gpsSubscription = null;

    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      print("GPS disabled");
      return;
    }

    LocationPermission permission = await Geolocator.checkPermission();

    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      print("Location permission denied");
      return;
    }

    _gpsSubscription = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.bestForNavigation,
        distanceFilter: 0,
      ),
    ).listen(
          (position) async {

        try {

          final rawPoint = LatLng(position.latitude, position.longitude);

          // ignore small GPS drift when stopped
          if (_driverLocation != null && position.speed < 0.5) {
            double drift = Geolocator.distanceBetween(
              _driverLocation!.latitude,
              _driverLocation!.longitude,
              rawPoint.latitude,
              rawPoint.longitude,
            );

            if (drift < 3) return;
          }

          LatLng filteredPoint =
          _snapToRoute(_gpsKalman.process(rawPoint));

          _realGpsLocation = rawPoint;

          await _animateBus(filteredPoint);

          double newHeading = position.heading;

          if (!newHeading.isNaN && newHeading >= 0) {
            _driverBearing =
                _driverBearing + (newHeading - _driverBearing) * 0.2;
          }

          _currentSpeed = position.speed;
          if (_currentSpeed < 0.3) {
            _currentSpeed = 0;
          }

        } catch (e) {
          print("GPS processing error: $e");
        }
      },

      onError: (error) {
        print("GPS stream error: $error");
      },
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

    if (_cameraTimer != null) return;

    _cameraTimer =
        Timer.periodic(const Duration(milliseconds: 250), (timer) {

          if (_driverLocation == null) return;

          LatLng lookAhead =
          _projectForward(_driverLocation!, _driverBearing, _lookAheadDistance);

          _cameraPosition ??= lookAhead;

          double lat = _cameraPosition!.latitude +
              (lookAhead.latitude - _cameraPosition!.latitude) * 0.15;

          double lng = _cameraPosition!.longitude +
              (lookAhead.longitude - _cameraPosition!.longitude) * 0.15;

          _cameraPosition = LatLng(lat, lng);

          _mapController?.animateCamera(
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

  LatLng _predictNextPosition(LatLng current) {

    if (_currentSpeed < 1) return current;

    double distance = _currentSpeed * 1.2;

    return _projectForward(
      current,
      _driverBearing,
      distance,
    );
  }
// ================= DRIVER ETA =================
  Future<void> _fetchDriverETA() async {
    print("==== DRIVER ETA START ====");
    print("busId = $busId");
    print("driverLocation = $_driverLocation");
    print("routeStops length = ${_routeStops.length}");

    if (busId == null) return;

    // ✅ prevent crash if location not ready
    if (_driverLocation == null) {
      print("❌ ETA skipped — driverLocation is null");
      return;
    }

    // ✅ prevent invalid GPS
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

          double eta = duration.toDouble() / 60.0;

          // adjust ETA using current bus speed
          if (_currentSpeed < 2) {
            eta *= 1.4;
          } else if (_currentSpeed < 5) {
            eta *= 1.2;
          }

          _etaMinutes = eta;

        } else {
          _etaMinutes = null;
        }

        _nextStopName = data["nextStop"];
      });
      await _fetchRouteStops(); // 🔥 refresh stop markers

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
    int closestIndex = _lastSnappedIndex;

    // search only forward on the route (prevents backward jump)
    int searchEnd = (_lastSnappedIndex + 50).clamp(0, _routePoints.length - 1);

    for (int i = _lastSnappedIndex; i <= searchEnd; i++) {

      final d = Geolocator.distanceBetween(
        gpsPoint.latitude,
        gpsPoint.longitude,
        _routePoints[i].latitude,
        _routePoints[i].longitude,
      );

      if (d < minDistance) {
        minDistance = d;
        closestIndex = i;
      }
    }

    _lastSnappedIndex = closestIndex;

    if (_routePoints.isEmpty) return gpsPoint;

    return _routePoints[closestIndex];
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
// ================= FIREBASE PUBLISH =================
  Future<void> _publishDriverLocation() async {
    if (busId == null || _realGpsLocation == null) return;

    if (_driverLocation == null) return;

    if (_driverLocation!.latitude == 0 || _driverLocation!.longitude == 0) {
      return;
    }
    await _busRef.child("buses/$busId/current").update({
      "lat": _realGpsLocation!.latitude,
      "lng": _realGpsLocation!.longitude,
      "bearing": _driverBearing,
      "speed": _currentSpeed,
      "updatedAt": ServerValue.timestamp,
    });
  }
// ================= ROUTE STOPS =================
  Future<void> _fetchRouteStops() async {
    if (busId == null) return;

    try {
      final response = await ApiService.get("/routes/$busId");

      if (response.statusCode != 200) return;

      final List stops = jsonDecode(response.body);

      _routeStops = List<Map<String, dynamic>>.from(stops);

      Set<Marker> stopMarkers = <Marker>{};
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

    } catch (e) {
      print("Route fetch error: $e");
    }
  }
// ================= ROUTE POLYLINE LISTENER =================

  Future<void> _generateDynamicRoute() async {

    if (_driverLocation == null || _nextStopName == null) return;

    final nextStop = _routeStops.firstWhere(
          (s) => s["stopName"] == _nextStopName,
      orElse: () => {},
    );

    if (nextStop.isEmpty) return;

    LatLng destination = LatLng(
      (nextStop["lat"] as num).toDouble(),
      (nextStop["lng"] as num).toDouble(),
    );

    String url =
        "https://maps.googleapis.com/maps/api/directions/json"
        "?origin=${_driverLocation!.latitude},${_driverLocation!.longitude}"
        "&destination=${destination.latitude},${destination.longitude}"
        "&mode=driving"
        "&key=$googleKey";

    final response = await ApiService.getExternal(url);

    if (response.statusCode != 200) return;

    final data = jsonDecode(response.body);

    if (data["routes"] == null || data["routes"].isEmpty) return;

    String encoded = data["routes"][0]["overview_polyline"]["points"];

    PolylinePoints polylinePoints = PolylinePoints();

    List<PointLatLng> decoded =
    polylinePoints.decodePolyline(encoded);

    List<LatLng> points =
    decoded.map((p) => LatLng(p.latitude, p.longitude)).toList();

    setState(() {

      _polylines.removeWhere(
              (p) => p.polylineId.value == "dynamicRoute");

      _polylines.add(
        Polyline(
          polylineId: const PolylineId("dynamicRoute"),
          points: points,
          width: 7,
          color: Colors.grey,
        ),
      );
    });
  }

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
      if (encodedPolyline.isEmpty) return;

      PolylinePoints polylinePoints = PolylinePoints();

      List<PointLatLng> decoded =
      polylinePoints.decodePolyline(encodedPolyline);

      List<LatLng> points =
      decoded.map((p) => LatLng(p.latitude, p.longitude)).toList();

      setState(() {
        _routePoints = points;

        _polylines.removeWhere(
              (p) => p.polylineId.value == "route",
        );

        _polylines.add(
          Polyline(
            polylineId: const PolylineId("route"),
            points: points,
            width: 6,
            color: Colors.blue,
          ),
        );
      });

      print("Polyline data = $data");
      print("Decoded count = ${decoded.length}");

    });
  }
  Future<void> _listenAlternativeRoutes() async {

    if (busId == null) return;

    _altRoutesListener?.cancel();

    _altRoutesListener = FirebaseDatabase.instance
        .ref("busRoutes/$busId/routeAlternatives")
        .onValue
        .listen((event) {

      final data = event.snapshot.value;

      if (data == null) return;

      if (data is! List) return;

      final routes = List.from(data);
      _alternativeRoutes = routes;

      print("🚍 Alternative routes loaded: ${routes.length}");
    });
  }


  void _checkBetterRoute() {

    if (_alternativeRoutes.isEmpty) return;

    int bestIndex = 0;
    int bestDuration = _alternativeRoutes[0]["duration"];

    for (int i = 1; i < _alternativeRoutes.length; i++) {

      int duration = _alternativeRoutes[i]["duration"];

      if (duration < bestDuration) {
        bestDuration = duration;
        bestIndex = i;
      }
    }

    String encodedPolyline =
    _alternativeRoutes[bestIndex]["polyline"];

    PolylinePoints polylinePoints = PolylinePoints();

    List<PointLatLng> decoded =
    polylinePoints.decodePolyline(encodedPolyline);

    List<LatLng> points =
    decoded.map((p) => LatLng(p.latitude, p.longitude)).toList();

    setState(() {

      _polylines.removeWhere(
              (p) => p.polylineId.value == "route");

      _polylines.add(
        Polyline(
          polylineId: const PolylineId("route"),
          points: points,
          width: 6,
          color: Colors.blue,
        ),
      );

    });

    print("🚦 Switched to better route");
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

  int _calculateAnimationDelay() {

    double speed = _currentSpeed.clamp(1, 15);

    int delay = (80 - (speed * 3)).toInt();

    return delay.clamp(25, 120);
  }

  LatLng _interpolate(LatLng a, LatLng b, double t) {
    return LatLng(
      a.latitude + (b.latitude - a.latitude) * t,
      a.longitude + (b.longitude - a.longitude) * t,
    );
  }

// ================= DISPOSE =================

  @override
  void dispose() {
    _gpsSubscription?.cancel();
    _polylineListener?.cancel();
    _altRoutesListener?.cancel();
    _etaTimer?.cancel();
    _cameraTimer?.cancel();
    _publishTimer?.cancel();
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