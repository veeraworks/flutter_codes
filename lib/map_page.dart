import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_polyline_points/flutter_polyline_points.dart';

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

  StreamSubscription<DatabaseEvent>? _busListener;
  StreamSubscription<DatabaseEvent>? _stopListener;

  double? etaMinutes;
  bool _followBus = true;

  String? busId;
  String? stopName;

  @override
  void initState() {
    super.initState();
    _initAll();

    // ETA refresh every 15 seconds
    _etaTimer = Timer.periodic(
      const Duration(seconds: 15),
          (_) => _fetchETAFromBackend(),
    );
  }

  Future<void> _initAll() async {
    await _loadPrefs();
    await _getStudentLocation();
    await _loadBusIcon();
    await _listenStopsRealtime();
    await _listenBusRealtime();
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
      const ImageConfiguration(size: Size(48, 48)),
      "assets/images/bus.png",
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

    _mapController!.animateCamera(
      CameraUpdate.newLatLngBounds(bounds, 80),
    );
  }

  // ================= ROUTE FROM FIREBASE =================
  Future<void> _listenStopsRealtime() async {
    if (busId == null) return;

    _stopListener = FirebaseDatabase.instance
        .ref("busRoutes/$busId")
        .onValue
        .listen((event) {
      if (!event.snapshot.exists) return;

      Map data = event.snapshot.value as Map;

      List<Map> stopsList = [];

      data.forEach((key, value) {
        stopsList.add({
          "name": key,
          "lat": value["lat"],
          "lng": value["lng"],
          "order": value["stopOrder"] ?? 0
        });
      });

      stopsList.sort((a, b) => a["order"].compareTo(b["order"]));

      List<LatLng> routeLine = [];
      Set<Marker> markers = {};

      for (var stop in stopsList) {
        LatLng pos = LatLng(
          (stop["lat"] as num).toDouble(),
          (stop["lng"] as num).toDouble(),
        );

        routeLine.add(pos);

        markers.add(
          Marker(
            markerId: MarkerId(stop["name"]),
            position: pos,
            infoWindow: InfoWindow(title: stop["name"]),
            icon: BitmapDescriptor.defaultMarkerWithHue(
              BitmapDescriptor.hueOrange,
            ),
          ),
        );

        if (stop["name"] == stopName) {
          _studentStopLocation = pos;
        }
      }

      setState(() {
        _stopMarkers = markers;
        _polylines = {
          Polyline(
            polylineId: const PolylineId("route"),
            points: routeLine,
            width: 5,
            color: Colors.blue,
          )
        };
      });

      _fitRouteToScreen(routeLine);
    });
  }

  // ================= BUS REALTIME =================
  Future<void> _listenBusRealtime() async {
    if (busId == null) return;

    var connectivity = await Connectivity().checkConnectivity();
    if (connectivity == ConnectivityResult.none) return;

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

      double bearing = (map["bearing"] ?? 0).toDouble();

      _busLocation = newPos;

      _animateBus(newPos, bearing);
      _fetchETAFromBackend();

      if (_followBus) {
        _mapController?.animateCamera(
          CameraUpdate.newLatLng(newPos),
        );
      }
    });
  }

  void _animateBus(LatLng newPosition, double bearing) {
    if (_previousBusLocation == null) {
      _previousBusLocation = newPosition;
    }

    const duration = 1000;
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
              rotation: bearing,
              anchor: const Offset(0.5, 0.5),
            );
          });

          if (step >= steps) {
            timer.cancel();
            _previousBusLocation = newPosition;
          }
        });
  }

  // ================= BACKEND ETA =================
  Future<void> _fetchETAFromBackend() async {
    if (_busLocation == null || _studentStopLocation == null) return;

    final url = Uri.parse(
      "https://null-sheldon-unstudded.ngrok-free.dev/drivers/eta"
          "?originLat=${_busLocation!.latitude}"
          "&originLng=${_busLocation!.longitude}"
          "&destLat=${_studentStopLocation!.latitude}"
          "&destLng=${_studentStopLocation!.longitude}",
    );

    try {
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        // ✅ Update ETA
        setState(() {
          etaMinutes =
              (data["durationValue"] / 60).ceilToDouble();
        });

        // ✅ Decode road polyline
        PolylinePoints polylinePoints = PolylinePoints();

        List<PointLatLng> result =
        polylinePoints.decodePolyline(data["polyline"]);

        List<LatLng> decodedPoints = result
            .map((p) => LatLng(p.latitude, p.longitude))
            .toList();

        // ✅ Draw real road
        setState(() {
          _polylines = {
            Polyline(
              polylineId: const PolylineId("roadRoute"),
              points: decodedPoints,
              width: 5,
              color: Colors.blue,
            )
          };
        });
      }
    } catch (e) {
      print("ETA error: $e");
    }
  }
  @override
  void dispose() {
    _animationTimer?.cancel();
    _etaTimer?.cancel();
    _busListener?.cancel();
    _stopListener?.cancel();
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

          if (etaMinutes != null)
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
                  "Bus arriving in ${etaMinutes!.toInt()} mins",
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