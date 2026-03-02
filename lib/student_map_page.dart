import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'service/api_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'dart:math';

class MapPage extends StatefulWidget {
  const MapPage({super.key});

  @override
  State<MapPage> createState() => _MapPageState();
}

class _MapPageState extends State<MapPage> {
  GoogleMapController? _mapController;

  LatLng _studentLocation = const LatLng(13.0827, 80.2707);
  LatLng? _busLocation;
  LatLng? _studentStopLocation;

  LatLng? _previousBusLocation;
  Timer? _animationTimer;
  Timer? _etaTimer;

  Marker? _busMarker;
  Marker? _studentMarker;
  BitmapDescriptor? _busIcon;

  Set<Marker> _stopMarkers = {};
  Set<Polyline> _polylines = {};

  List<LatLng> _roadPath = [];
  List<LatLng> _routePoints = [];
  int _roadIndex = 0;
  Timer? _roadAnimationTimer;

  LatLng? _cameraPosition;
  Timer? _cameraTimer;
  double _lookAheadDistance = 35; // meters

  DateTime? _lastGpsTime;
  LatLng? _lastGpsPosition;
  double _busSpeedMps = 0; // meters per second
  bool _gpsJustUpdated = false;
  Timer? _rotationTimer;

  double _currentRotation = 0;
  double _targetRotation = 0;

  StreamSubscription<DatabaseEvent>? _busListener;
  StreamSubscription<DatabaseEvent>? _stopListener;
  StreamSubscription<DatabaseEvent>? _polylineListener;

  double? etaMinutes;
  Timer? _countdownTimer;
  int? _etaSeconds;
  bool _followBus = true;

  String? busId;
  String? stopName;

  Timer? _predictiveTimer;
  LatLng? _predictedPosition;

  String? _nextStopName;
  int? _nextStopOrder;

  @override
  void initState() {
    super.initState();
    _initAll();
  }

  Future<void> _initAll() async {
    await _loadPrefs();

    // ✅ subscribe notifications
    if (busId != null) {
      await FirebaseMessaging.instance
          .subscribeToTopic("route_$busId");

      print("✅ Subscribed to route_$busId");
    }

    // ✅ SAFETY CHECK (YOUR CODE GOES HERE)
    if (busId == null) {
      print("❌ busId not found");
      return;
    }

    await _getStudentLocation();
    await _loadBusIcon();
    _listenRoutePolyline();
    await _fetchRouteStopsFromBackend();
    await _listenBusRealtime();

    _etaTimer = Timer.periodic(
      const Duration(seconds: 20),
          (_) => _fetchETAFromBackend(),
    );
  }

  void _startCountdown(int seconds) {
    _countdownTimer?.cancel();

    _etaSeconds = seconds;

    _countdownTimer =
        Timer.periodic(const Duration(seconds: 1), (timer) {
          if (_etaSeconds == null || _etaSeconds! <= 0) {
            timer.cancel();
            return;
          }

          setState(() {
            _etaSeconds = _etaSeconds! - 1;
            etaMinutes = _etaSeconds! / 60.0;
          });
        });
  }

  Future<void> _loadPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    busId = prefs.getString("busId");
    stopName = prefs.getString("stopName");
  }

  Future<void> _getStudentLocation() async {
    bool enabled = await Geolocator.isLocationServiceEnabled();
    if (!enabled) return;

    await Geolocator.requestPermission();
    Position position = await Geolocator.getCurrentPosition();

    setState(() {
      _studentLocation = LatLng(position.latitude, position.longitude);
      _studentMarker = Marker(
        markerId: const MarkerId("student"),
        position: _studentLocation,
        icon: BitmapDescriptor.defaultMarkerWithHue(
          BitmapDescriptor.hueBlue,
        ),
      );
    });
  }

  Future<void> _loadBusIcon() async {
    _busIcon = await BitmapDescriptor.fromAssetImage(
      const ImageConfiguration(size: Size(100, 100)),
      "assets/images/bus_icon_map.png",
    );
  }

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

  double _distanceMeters(LatLng a, LatLng b) {
    return Geolocator.distanceBetween(
      a.latitude,
      a.longitude,
      b.latitude,
      b.longitude,
    );
  }

// ================= ROUTE ENGINE (ADD HERE) =================
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

  LatLng _projectPosition(LatLng start,
      double bearingDeg,
      double distanceMeters,) {
    const earthRadius = 6371000.0;

    double bearing = bearingDeg * (pi / 180);

    double lat1 = start.latitude * (pi / 180);
    double lon1 = start.longitude * (pi / 180);

    double lat2 = asin(
      sin(lat1) * cos(distanceMeters / earthRadius) +
          cos(lat1) *
              sin(distanceMeters / earthRadius) *
              cos(bearing),
    );

    double lon2 = lon1 +
        atan2(
          sin(bearing) *
              sin(distanceMeters / earthRadius) *
              cos(lat1),
          cos(distanceMeters / earthRadius) -
              sin(lat1) * sin(lat2),
        );

    return LatLng(
      lat2 * 180 / pi,
      lon2 * 180 / pi,
    );
  }

  LatLng _calculateLookAheadPosition(LatLng current,
      double bearing,) {
    return _projectPosition(
      current,
      bearing,
      _lookAheadDistance,
    );
  }

// ================= FETCH ROUTE STOPS =================
  Future<void> _fetchRouteStopsFromBackend() async {
    if (busId == null) return;

    try {
      final response = await ApiService.get("/routes/$busId");

      if (response.statusCode != 200) return;

      final List stops = jsonDecode(response.body);

      Set<Marker> markers = {};
      List<LatLng> routePoints = [];

      for (var stop in stops) {
        LatLng pos = LatLng(
          (stop["lat"] as num).toDouble(),
          (stop["lng"] as num).toDouble(),
        );

        routePoints.add(pos);

        String currentStopName =
        stop["stopName"].toString().trim();

        int currentOrder = stop["stopOrder"];

        bool isStudentStop =
            currentStopName ==
                stopName?.trim();

        double markerHue = BitmapDescriptor.hueOrange;

        // 🟢 NEXT STOP
        if (_nextStopName != null &&
            currentStopName ==
                _nextStopName!.trim()) {
          markerHue = BitmapDescriptor.hueGreen;
        }

        // 🔵 PASSED STOPS
        else if (_nextStopOrder != null &&
            currentOrder < _nextStopOrder!) {
          markerHue = BitmapDescriptor.hueAzure;
        }

        // 🔷 STUDENT STOP
        else if (isStudentStop) {
          markerHue = BitmapDescriptor.hueBlue;
        }

        markers.add(
          Marker(
            markerId: MarkerId(currentStopName),
            position: pos,
            infoWindow: InfoWindow(title: currentStopName),
            icon: BitmapDescriptor.defaultMarkerWithHue(markerHue),
          ),
        );

        if (isStudentStop) {
          _studentStopLocation = pos;
        }
      }

      setState(() {
        _stopMarkers = markers;
      });

      Future.delayed(const Duration(milliseconds: 500), () {
        _fitRouteToScreen(routePoints);
      });
    } catch (e) {
      print("Route fetch error: $e");
    }
  }


// ================= BUS REALTIME =================
  Future<void> _listenBusRealtime() async {
    if (busId == null) return;

    final connectivity = await Connectivity().checkConnectivity();

    if (connectivity == ConnectivityResult.none) {
      print("No internet");
      return;
    }
    _busListener = FirebaseDatabase.instance
        .ref("buses/$busId/current")
        .onValue
        .listen((event) {
      final data = event.snapshot.value;
      if (data == null) return;

      final map = Map<String, dynamic>.from(data as Map);

      LatLng newPos = LatLng(

        (map["lat"] as num).toDouble(),
        (map["lng"] as num).toDouble(),

      );

      // ✅ mark GPS arrival
      _gpsJustUpdated = true;

      final now = DateTime.now();

      if (_lastGpsPosition != null && _lastGpsTime != null) {
        double distance =
        _distanceMeters(_lastGpsPosition!, newPos);

        double seconds =
            now
                .difference(_lastGpsTime!)
                .inMilliseconds / 1000;

        if (seconds > 0) {
          _busSpeedMps = (distance / seconds).clamp(0, 25);
        }
      }

      _lastGpsPosition = newPos;
      _lastGpsTime = now;

      double bearing = (map["bearing"] ?? 0).toDouble();
      _smoothRotate(bearing);
      // 🔥 SNAP TO ROAD
      final snappedPos = _snapToRoute(newPos);

      _busLocation = snappedPos;
      _fetchETAFromBackend();
      _startPredictiveMotion(snappedPos, bearing);

      if (_roadPath.isNotEmpty) {
        if (!(_roadAnimationTimer?.isActive ?? false)) {
          _animateBusAlongRoad(bearing);
        }
      } else {
        _animateBus(snappedPos, bearing);
      }
      _startCinematicCamera(snappedPos);
    });
  }

  void _animateBus(LatLng newPosition, double bearing) {
    if (_previousBusLocation == null) {
      _previousBusLocation = newPosition;
    }

    const duration = 1500;
    const frame = 16;
    int steps = duration ~/ frame;
    int step = 0;

    double latDelta =
        (newPosition.latitude - _previousBusLocation!.latitude) / steps;
    double lngDelta =
        (newPosition.longitude - _previousBusLocation!.longitude) / steps;

    _animationTimer?.cancel();

    _animationTimer =
        Timer.periodic(const Duration(milliseconds: frame), (timer) {
          step++;

          LatLng pos = LatLng(
            _previousBusLocation!.latitude + latDelta * step,
            _previousBusLocation!.longitude + lngDelta * step,
          );

          setState(() {
            _busMarker = Marker(
              markerId: const MarkerId("bus"),
              position: pos,
              icon: _busIcon ?? BitmapDescriptor.defaultMarker,
              rotation: _currentRotation,
              anchor: const Offset(0.5, 0.5),
              flat: true,
            );
          });

          if (step >= steps) {
            timer.cancel();
            _previousBusLocation = newPosition;
          }
        });
  }
  // ================= ROUTE POLYLINE LISTENER =================
  Future<void> _listenRoutePolyline() async {
    if (busId == null) return;

    print("🔥 Listening encoded polyline for $busId");

    _polylineListener?.cancel();

    _polylineListener = FirebaseDatabase.instance
        .ref("busRoutes/$busId/fullRoadPolyline")
        .onValue
        .listen((event) {

      final data = event.snapshot.value;

      if (data == null) {
        print("❌ No polyline data");
        return;
      }

      // ✅ Firebase gives STRING
      String encodedPolyline = data.toString();

      print("✅ Polyline string received");

      PolylinePoints polylinePoints = PolylinePoints();

      List<PointLatLng> decoded =
      polylinePoints.decodePolyline(encodedPolyline);

      List<LatLng> points = decoded
          .map((p) => LatLng(p.latitude, p.longitude))
          .toList();

      print("✅ Decoded points = ${points.length}");

      setState(() {
        _polylines = {
          Polyline(
            polylineId: const PolylineId("route"),
            points: points,
            width: 6,
            color: Colors.blue,
          ),
        };

        // 🔥 VERY IMPORTANT
        _routePoints = points;
      });

      _fitRouteToScreen(points);
    });
  }
// ================= ROAD FOLLOW ANIMATION =================
  void _animateBusAlongRoad(double bearing) {
    if (_busSpeedMps < 0.5) return;
    if (_roadPath.isEmpty) return;
    if (_roadAnimationTimer?.isActive ?? false) return;

    _roadAnimationTimer?.cancel();
    _roadIndex = 0;

    _roadAnimationTimer =
        Timer.periodic(
            Duration(milliseconds: _calculateAnimationDelay()),
                (timer) {
              if (_roadIndex >= _roadPath.length) {
                timer.cancel();
                return;
              }

              LatLng pos = _roadPath[_roadIndex];

              setState(() {
                _busMarker = Marker(
                  markerId: const MarkerId("bus"),
                  position: pos,
                  icon: _busIcon ?? BitmapDescriptor.defaultMarker,
                  rotation: _currentRotation,
                  anchor: const Offset(0.5, 0.5),
                  flat: true,
                );
              });

              if (_followBus) {
                _mapController?.animateCamera(
                  CameraUpdate.newLatLng(pos),
                );
              }

              _roadIndex++;
            });
  }

// ================= SMOOTH ROTATION =================

  void _smoothRotate(double newBearing) {
    _targetRotation = newBearing;

    _rotationTimer?.cancel();

    _rotationTimer =
        Timer.periodic(const Duration(milliseconds: 30), (timer) {
          double diff = _targetRotation - _currentRotation;

          // normalize shortest angle
          if (diff > 180) diff -= 360;
          if (diff < -180) diff += 360;

          // small step rotation
          setState(() {
            _currentRotation += diff * 0.15;
          });

          // stop when very close
          if (diff.abs() < 0.5) {
            setState(() {
              _currentRotation = _targetRotation;
            });
            timer.cancel();
          }
        });
  }

  int _calculateAnimationDelay() {
    double speed = _busSpeedMps.clamp(1, 20);
    int delay = (80 - (speed * 3)).toInt();
    return delay.clamp(20, 120);
  }

  void _startPredictiveMotion(LatLng gpsPos, double bearing) {
    _predictiveTimer?.cancel();

    _predictedPosition = gpsPos;
    DateTime lastTick = DateTime.now();

    _predictiveTimer =
        Timer.periodic(const Duration(milliseconds: 120), (timer) {
          // 🧠 pause prediction right after GPS update
          if (_gpsJustUpdated) {
            _gpsJustUpdated = false;
            _predictedPosition = gpsPos;
            return;
          }

          if (_busSpeedMps < 0.5) return;

          final now = DateTime.now();
          double dt =
              now
                  .difference(lastTick)
                  .inMilliseconds / 1000.0;

          lastTick = now;

          double distance = _busSpeedMps * dt;

          _predictedPosition = _projectPosition(
            _predictedPosition!,
            _currentRotation,
            distance,
          );

          setState(() {
            _busMarker = Marker(
              markerId: const MarkerId("bus"),
              position: _predictedPosition!,
              icon: _busIcon ?? BitmapDescriptor.defaultMarker,
              rotation: _currentRotation,
              anchor: const Offset(0.5, 0.5),
              flat: true,
            );
          });

          if (_followBus) {
            _mapController?.animateCamera(
              CameraUpdate.newLatLng(_predictedPosition!),
            );
          }
        });
  }

// ================= CINEMATIC CAMERA =================
  void _startCinematicCamera(LatLng target) {
    if (!_followBus) return;

// 👇 look ahead position
    LatLng lookAhead =
    _calculateLookAheadPosition(target, _currentRotation);

    _cameraTimer?.cancel();

    _cameraPosition ??= lookAhead;
    _cameraTimer =
        Timer.periodic(const Duration(milliseconds: 40), (timer) {
          if (_cameraPosition == null || _mapController == null) return;

          double lat = _cameraPosition!.latitude +
              (lookAhead.latitude - _cameraPosition!.latitude) * 0.06;
          ;

          double lng = _cameraPosition!.longitude +
              (lookAhead.longitude - _cameraPosition!.longitude) * 0.06;
          ;

          _cameraPosition = LatLng(lat, lng);

          _mapController?.moveCamera(
            CameraUpdate.newCameraPosition(
              CameraPosition(
                target: _cameraPosition!,
                zoom: 16,
                tilt: 45,
                bearing: _currentRotation,
              ),
            ),
          );

          double diffLat = (lookAhead.latitude - lat).abs();
          double diffLng = (lookAhead.longitude - lng).abs();

          if (diffLat < 0.00001 && diffLng < 0.00001) {
            timer.cancel();
          }
        });
  }

// ================= BACKEND SMART ETA =================
  Future<void> _fetchETAFromBackend() async {
    if (busId == null ||
        _busLocation == null ||
        _studentStopLocation == null) {
      return;
    }

    try {
      final url =
          "/drivers/eta"
          "?originLat=${_busLocation!.latitude}"
          "&originLng=${_busLocation!.longitude}"
          "&destLat=${_studentStopLocation!.latitude}"
          "&destLng=${_studentStopLocation!.longitude}"
          "&busId=$busId"
          "&nextStop=${_nextStopName ?? ""}";

      final response =
      await ApiService.get(url)
          .timeout(const Duration(seconds: 8));

      if (response.statusCode != 200) {
        print("ETA API failed");
        return;
      }

      final data = jsonDecode(response.body);

      // ✅ START COUNTDOWN
      if (data["durationValue"] != null) {
        int seconds =
        (data["durationValue"] as num).toInt();

        _startCountdown(seconds);
      }

      // ✅ POLYLINE
      final polylineString = data["polyline"];

      if (polylineString != null &&
          polylineString
              .toString()
              .isNotEmpty) {
        PolylinePoints polylinePoints = PolylinePoints();

        List<PointLatLng> result =
        polylinePoints.decodePolyline(polylineString);

        List<LatLng> decodedPoints =
        result.map((p) =>
            LatLng(p.latitude, p.longitude)).toList();

        _roadPath = decodedPoints;

        if (mounted) {
          setState(() {
            _polylines = {
              Polyline(
                polylineId: const PolylineId("roadRoute"),
                points: decodedPoints,
                width: 5,
                color: Colors.blue,
              ),
            };
          });
        }
      }
    } catch (e) {
      print("❌ ETA error: $e");
    }
  }

  @override
  void dispose() {
    _animationTimer?.cancel();
    _etaTimer?.cancel();
    _busListener?.cancel();
    _stopListener?.cancel();
    _roadAnimationTimer?.cancel();
    _rotationTimer?.cancel();
    _predictiveTimer?.cancel();
    _cameraTimer?.cancel();
    _countdownTimer?.cancel();
    _polylineListener?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Live Bus Map")),
      body: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: CameraPosition(
              target: _studentLocation,
              zoom: 14,
            ),
            onMapCreated: (controller) {
              _mapController = controller;
            },
            myLocationEnabled: true,
            markers: {
              if (_busMarker != null) _busMarker!,
              if (_studentMarker != null) _studentMarker!,
              ..._stopMarkers,
            },
            polylines: _polylines,
          ),

          if (_etaSeconds != null)
            Positioned(
              top: 20,
              left: 20,
              right: 20,
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.black87,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  "Bus arriving in "
                      "${(_etaSeconds! ~/ 60)}m "
                      "${(_etaSeconds! % 60).toString().padLeft(2, '0')}s",
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),

          Positioned(
            bottom: 100,
            right: 20,
            child: FloatingActionButton(
              backgroundColor: _followBus ? Colors.blue : Colors.grey,
              onPressed: () {
                setState(() {
                  _followBus = !_followBus;
                });
              },
              child: Icon(
                _followBus ? Icons.gps_fixed : Icons.gps_not_fixed,
              ),
            ),
          ),
        ],
      ),
    );
  }
}