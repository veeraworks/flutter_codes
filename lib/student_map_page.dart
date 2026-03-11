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
import 'utils/app_logger.dart';

class MapPage extends StatefulWidget {
  const MapPage({super.key});

  @override
  State<MapPage> createState() => _MapPageState();
}

class _MapPageState extends State<MapPage> {
  GoogleMapController? _mapController;
  List<LatLng> _getRemainingRoute() {

    if (_busLocation == null || _routePoints.isEmpty) {
      return _routePoints;
    }

    int closestIndex = 0;
    double minDistance = double.infinity;

    int start = (_lastRouteIndex - 30).clamp(0, _routePoints.length - 1);
    int end = (_lastRouteIndex + 30).clamp(0, _routePoints.length - 1);

    for (int i = start; i <= end; i++) {

      double d = Geolocator.distanceBetween(
        _busLocation!.latitude,
        _busLocation!.longitude,
        _routePoints[i].latitude,
        _routePoints[i].longitude,
      );

      if (d < minDistance) {
        minDistance = d;
        closestIndex = i;
      }
    }

    return _routePoints.sublist(closestIndex);
  }

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
  final double _lookAheadDistance = 35; // meters

  DateTime? _lastGpsTime;
  LatLng? _lastGpsPosition;
  double _busSpeedMps = 0; // meters per second
  double? _distanceToBus;
  bool _gpsJustUpdated = false;
  Timer? _rotationTimer;

  double _currentRotation = 0;
  double _targetRotation = 0;

  int _lastRouteIndex = -1;
  double _tripProgress = 0;


  StreamSubscription<DatabaseEvent>? _busListener;
  StreamSubscription<DatabaseEvent>? _polylineListener;

  double? etaMinutes;
  Timer? _countdownTimer;
  int? _etaSeconds;
  bool _followBus = true;

  String? busId;
  String? stopName;
  String? _busStatus;

  Timer? _predictiveTimer;
  LatLng? _predictedPosition;
  LatLng? _lastBusRouteConnection;

  String? _nextStopName;
  int? _nextStopOrder;

  @override
  void initState() {
    super.initState();
    _initAll();
  }

  Future<void> _initAll() async {
    await _loadPrefs();

    if (busId != null) {
      await FirebaseMessaging.instance
          .subscribeToTopic("route_${busId!.toUpperCase()}");
      appLog("✅ Subscribed to route_$busId");
    }

    if (busId == null) {
      appLog("❌ busId not found");
      return;
    }

    await _getStudentLocation();
    await _loadBusIcon();

    _listenRoutePolyline();

    await _fetchRouteStopsFromBackend();
    await _listenBusRealtime();

    // ⭐ Fix timer
    _etaTimer?.cancel();

    _etaTimer = Timer.periodic(
      const Duration(seconds: 20),
          (_) {
        if (_busLocation != null && _studentStopLocation != null) {
          _fetchETAFromBackend();
        }
      },
    );
  }
  void _updateBusMarker(LatLng position) {
    final marker = Marker(
      markerId: const MarkerId("bus"),
      position: position,
      icon: _busIcon ?? BitmapDescriptor.defaultMarker,
      rotation: _currentRotation,
      anchor: const Offset(0.5, 0.5),
      flat: true,
    );

    if (!mounted) return;

    setState(() {
      _busMarker = marker;
    });
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
    busId = prefs.getString("busId")?.toUpperCase();
    stopName = prefs.getString("boardingPoint");

    appLog("Loaded busId: $busId");
    appLog("Loaded stopName: $stopName");
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
    _busIcon = await BitmapDescriptor.asset(
      ImageConfiguration(size: Size(48, 48)),
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

    if (_mapController != null && mounted) {
      _mapController!.animateCamera(
        CameraUpdate.newLatLngBounds(bounds, 80),
      );
    }
  }

  double _distanceMeters(LatLng a, LatLng b) {
    return Geolocator.distanceBetween(
      a.latitude,
      a.longitude,
      b.latitude,
      b.longitude,
    );
  }

// ================= ROUTE ENGINE =================
  LatLng _snapToRoute(LatLng gpsPoint) {
    if (_routePoints.isEmpty) return gpsPoint;

    double minDistance = double.infinity;
    int closestIndex = 0;

    int start = (_lastRouteIndex - 30).clamp(0, _routePoints.length - 1);
    int end = (_lastRouteIndex + 30).clamp(0, _routePoints.length - 1);

    for (int i = start; i <= end; i++) {
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

    return _routePoints[closestIndex];
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
            currentStopName
                .toLowerCase()
                .replaceAll(" ", "")
                .trim() ==
                stopName
                    ?.toLowerCase()
                    .replaceAll(" ", "")
                    .trim();

        appLog("Route Stop: $currentStopName");
        appLog("Student Stop: $stopName");
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
          markerHue = BitmapDescriptor.hueViolet;
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
          appLog("✅ STUDENT STOP MATCHED: $currentStopName");
          appLog("📍 Student Stop Location: $_studentStopLocation");
        }
      }

      setState(() {
        _stopMarkers = markers;
      });

      if (_mapController != null) {
        _fitRouteToScreen(routePoints);
      }
    } catch (e) {
      appLog("Route fetch error: $e");
    }
  }


// ================= BUS REALTIME =================
  Future<void> _listenBusRealtime() async {
    if (busId == null) return;

    final connectivity = await Connectivity().checkConnectivity();

    if (connectivity == ConnectivityResult.none) {
      appLog("No internet");
      return;
    }

    _busListener = FirebaseDatabase.instance
        .ref("buses/$busId")
        .onValue
        .listen((event) {

      if (!mounted) return;

      final data = event.snapshot.value;
      if (data == null) return;

      final root = Map<String, dynamic>.from(data as Map);
      String? busStatus;

      if (root["status"] != null) {
        busStatus = root["status"].toString();
      }

      if (busStatus != null) {
        setState(() {
          _busStatus = busStatus;
        });
      }

      Map<String, dynamic>? source;

// ⭐ use smooth first
      if (root["smooth"] != null) {
        source = Map<String, dynamic>.from(root["smooth"]);
      }

// ⭐ fallback to current
      else if (root["current"] != null) {
        source = Map<String, dynamic>.from(root["current"]);
      }

      if (source == null) return;

      LatLng newPos = LatLng(
        (source["lat"] as num).toDouble(),
        (source["lng"] as num).toDouble(),
      );

      double bearing = (source["bearing"] ?? 0).toDouble();

      if (_previousBusLocation != null) {
        double move = Geolocator.distanceBetween(
          _previousBusLocation!.latitude,
          _previousBusLocation!.longitude,
          newPos.latitude,
          newPos.longitude,
        );

        if (move < 1) {
          return;
        }
      }
      appLog("🔥 BUS REALTIME EVENT TRIGGERED");

      // mark GPS update
      _gpsJustUpdated = true;

      final now = DateTime.now();

      // ===== SPEED CALCULATION =====
      if (_lastGpsPosition != null && _lastGpsTime != null) {

        double distance =
        _distanceMeters(_lastGpsPosition!, newPos);

        double seconds =
            now.difference(_lastGpsTime!).inMilliseconds / 1000;

        if (seconds > 0) {
          _busSpeedMps = (distance / seconds).clamp(0, 15);
        }
      }

      _lastGpsPosition = newPos;
      _lastGpsTime = now;

      // ===== ROTATION =====
      _smoothRotate(bearing);

      LatLng snappedPos;

      if (_routePoints.isEmpty) {
        snappedPos = newPos;
      } else {

        double routeDistance = Geolocator.distanceBetween(
          newPos.latitude,
          newPos.longitude,
          _routePoints.first.latitude,
          _routePoints.first.longitude,
        );

        if (routeDistance > 500) {
          snappedPos = newPos; // bus still far from route
        } else {
          snappedPos = _snapToRoute(newPos);
        }
      }
      _busLocation = snappedPos;
      // calculate distance from student
      if (_studentStopLocation != null) {
        _distanceToBus = Geolocator.distanceBetween(
          _studentStopLocation!.latitude,
          _studentStopLocation!.longitude,
          snappedPos.latitude,
          snappedPos.longitude,
        ) / 1000;
      }
      // show driver marker immediately
      _updateBusMarker(snappedPos);

      // 📍 move camera to bus when first GPS arrives
      if (_mapController != null && _cameraPosition == null) {
        _cameraPosition = snappedPos;

        _mapController!.animateCamera(
          CameraUpdate.newCameraPosition(
            CameraPosition(
              target: snappedPos,
              zoom: 17,
              tilt: 45,
            ),
          ),
        );
      }

      if (_routePoints.isNotEmpty && _busLocation != null) {

        int closestIndex = 0;
        double minDistance = double.infinity;

        int start = (_lastRouteIndex - 30).clamp(0, _routePoints.length - 1);
        int end = (_lastRouteIndex + 30).clamp(0, _routePoints.length - 1);

        for (int i = start; i <= end; i++) {

          double d = Geolocator.distanceBetween(
            _busLocation!.latitude,
            _busLocation!.longitude,
            _routePoints[i].latitude,
            _routePoints[i].longitude,
          );

          if (d < minDistance) {
            minDistance = d;
            closestIndex = i;
          }
        }

        // update only when bus moves forward
        if (closestIndex != _lastRouteIndex) {

          // 🚍 TRIP PROGRESS
          if (_routePoints.isNotEmpty) {
            _tripProgress = (closestIndex / _routePoints.length) * 100;
          }

          if (_lastBusRouteConnection == null ||
              Geolocator.distanceBetween(
                _lastBusRouteConnection!.latitude,
                _lastBusRouteConnection!.longitude,
                _busLocation!.latitude,
                _busLocation!.longitude,
              ) > 200) {

            _lastBusRouteConnection = _busLocation;
          }
          _lastRouteIndex = closestIndex;

          LatLng snappedRoutePoint = _routePoints[closestIndex];

          List<LatLng> remaining = [
            snappedRoutePoint,
            ..._routePoints.sublist(closestIndex + 1)
          ];

          setState(() {
            _polylines = {
              Polyline(
                polylineId: const PolylineId("route"),
                points: remaining,
                width: 8,
                color: Colors.blue,
              ),
            };
          });

          _animateBus(snappedPos, bearing);
          _startCinematicCamera(snappedPos);
        }
      }
    });
  }
  void _animateBus(LatLng newPosition, double bearing) {
    if (_previousBusLocation == null) {
      _previousBusLocation = newPosition;
    }

    const duration = 500;
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

          if (!mounted) {
            timer.cancel();
            return;
          }

          _updateBusMarker(pos);

          if (step >= steps) {
            timer.cancel();
            _previousBusLocation = newPosition;
          }
        });
  }

  // ================= ROUTE POLYLINE LISTENER =================
  Future<void> _listenRoutePolyline() async {
    if (busId == null) return;

    appLog("🔥 Listening encoded polyline for $busId");

    _polylineListener?.cancel();

    _polylineListener = FirebaseDatabase.instance
        .ref("busRoutes/$busId/navigationPolyline")
        .onValue
        .listen((event) {

      final data = event.snapshot.value;

      if (data == null) {
        appLog("❌ No polyline data");
        return;
      }

      // ✅ Firebase gives STRING
      String encodedPolyline = data.toString();
      if (encodedPolyline.isEmpty) {
        appLog("Polyline empty");
        return;
      }

      appLog("✅ Polyline string received");

      PolylinePoints polylinePoints = PolylinePoints();

      List<PointLatLng> decoded =
      polylinePoints.decodePolyline(encodedPolyline);

      List<LatLng> points = decoded
          .map((p) => LatLng(p.latitude, p.longitude))
          .toList();

      if (points.isEmpty) {
        appLog("Decoded polyline empty");
        return;
      }

      if (_mapController != null) {
        _fitRouteToScreen(points);
      }

      setState(() {

        _routePoints = points;

        _polylines = {
          Polyline(
            polylineId: const PolylineId("route"),
            points: points,   // show full route
            width: 8,
            color: Colors.blue,
          ),
        };
      });
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

              if (!mounted) {
                timer.cancel();
                return;
              }

              _updateBusMarker(pos);

              if (_followBus) {
                if (_mapController != null && mounted) {
                  _mapController!.animateCamera(
                    CameraUpdate.newLatLng(pos),
                  );
                }
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

          if (!mounted) {
            timer.cancel();
            return;
          }

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
    double speed = _busSpeedMps.clamp(1, 15);
    int delay = (80 - (speed * 3)).toInt();
    return delay.clamp(25, 120);
  }

  void _startPredictiveMotion(LatLng gpsPos, double bearing) {
    _predictiveTimer?.cancel();

    _predictedPosition = gpsPos;
    DateTime lastTick = DateTime.now();

    _predictiveTimer =
        Timer.periodic(const Duration(milliseconds: 120), (timer) {

          if (!mounted) {
            timer.cancel();
            return;
          }
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

          _updateBusMarker(_predictedPosition!);

          if (_followBus && _mapController != null && mounted) {
            _mapController!.animateCamera(
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
          if (!mounted || _cameraPosition == null || _mapController == null) return;

          double lat = _cameraPosition!.latitude +
              (lookAhead.latitude - _cameraPosition!.latitude) * 0.06;
          ;

          double lng = _cameraPosition!.longitude +
              (lookAhead.longitude - _cameraPosition!.longitude) * 0.06;
          ;

          _cameraPosition = LatLng(lat, lng);

          if (_mapController != null && mounted) {
            _mapController!.moveCamera(
              CameraUpdate.newCameraPosition(
                CameraPosition(
                  target: _cameraPosition!,
                  zoom: 16,
                  tilt: 45,
                  bearing: _currentRotation,
                ),
              ),
            );
          }

          double diffLat = (lookAhead.latitude - lat).abs();
          double diffLng = (lookAhead.longitude - lng).abs();

          if (diffLat < 0.00001 && diffLng < 0.00001) {
            timer.cancel();
          }
        });
  }

// ================= BACKEND SMART ETA =================
  Future<void> _fetchETAFromBackend() async {
    appLog("==== CALLING ETA ====");
    appLog("busId: $busId");
    appLog("busLocation: $_busLocation");
    appLog("studentStopLocation: $_studentStopLocation");

    if (_busLocation != null) {
      appLog("originLat: ${_busLocation!.latitude}");
      appLog("originLng: ${_busLocation!.longitude}");
    }

    if (_studentStopLocation != null) {
      appLog("destLat: ${_studentStopLocation!.latitude}");
      appLog("destLng: ${_studentStopLocation!.longitude}");
    }

    if (busId == null ||
        _busLocation == null ||
        _studentStopLocation == null) {
      return;
    }

    try {
      final url = "/eta/$busId";
      final response =
      await ApiService.get(url)
          .timeout(const Duration(seconds: 8));

      if (response.statusCode != 200) {
        appLog("ETA API failed");
        return;
      }

      final data = jsonDecode(response.body);
// ✅ UPDATE NEXT STOP INFO
      if (data["nextStop"] != null) {
        _nextStopName = data["nextStop"];
      }

      if (data["nextStopOrder"] != null) {
        _nextStopOrder = data["nextStopOrder"];
      }

// 🔁 refresh stop markers
      await _fetchRouteStopsFromBackend();
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
          // Keep Firebase route polyline
// Only update ETA values
        }
      }
    } catch (e) {
      appLog("❌ ETA error: $e");
    }
  }

  @override
  void dispose() {
    _animationTimer?.cancel();
    _etaTimer?.cancel();
    _busListener?.cancel();
    _roadAnimationTimer?.cancel();
    _rotationTimer?.cancel();
    _predictiveTimer?.cancel();
    _followBus = false;
    _cameraTimer?.cancel();
    _countdownTimer?.cancel();
    _polylineListener?.cancel();
    _mapController?.dispose();
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
              zoom: 16.5,
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

          if (_busStatus == "OFFLINE")
            Positioned(
              top: 60,
              left: 20,
              right: 20,
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.redAccent,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Text(
                  "⚠️ Bus temporarily offline\nLocation updating...",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
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

          /// ⭐ ADD THIS BLOCK HERE
          if (_distanceToBus != null && _tripProgress > 0)
              Positioned(
                top: 140,
                left: 20,
                right: 20,
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.black87,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    "Trip progress: ${_tripProgress.toStringAsFixed(0)}%",
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
          if (_distanceToBus != null)
            Positioned(
              top: 80,
              left: 20,
              right: 20,
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.black87,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  "Bus distance to $stopName: ${_distanceToBus!.toStringAsFixed(2)} km",
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
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

