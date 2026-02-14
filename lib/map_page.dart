import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

class MapPage extends StatefulWidget {
  const MapPage({super.key});

  @override
  State<MapPage> createState() => _MapPageState();
}

class _MapPageState extends State<MapPage> {

  GoogleMapController? _mapController;

  LatLng _studentLocation = const LatLng(13.0827, 80.2707); // default Chennai
  LatLng? _busLocation;

  Marker? _studentMarker;
  Marker? _busMarker;
  BitmapDescriptor? _busIcon;
  double? etaMinutes;
  Set<Polyline> _polylines = {};
  List<LatLng> _routePoints = [];
  StreamSubscription<DatabaseEvent>? _busListener;

  @override
  void initState() {
    super.initState();
    _getStudentLocation();
    _loadBusIcon();
    _listenToBusLocation();
  }

  @override
  void dispose() {
    _busListener?.cancel();
    super.dispose();
  }

  // 🔥 GET STUDENT CURRENT LOCATION
  Future<void> _getStudentLocation() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();

    if (!serviceEnabled) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Please enable GPS to track bus"),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    LocationPermission permission = await Geolocator.checkPermission();

    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.deniedForever) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Location permission permanently denied"),
          backgroundColor: Colors.red,
        ),
      );
      await Geolocator.openAppSettings();
      return;
    }

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

  // 🔥 LISTEN TO BUS LOCATION FROM FIREBASE
  Future<void> _listenToBusLocation() async {
    bool hasInternet = await _checkInternet();
    if (!hasInternet) return;
    final prefs = await SharedPreferences.getInstance();
    String? busId = prefs.getString("busId");

    if (busId == null) {
      print("Bus ID not found");
      return;
    }

    _busListener = FirebaseDatabase.instance
        .ref("buses/$busId")
        .onValue
        .listen((event) {

      final data = event.snapshot.value;
      if (data == null) return;

      final map = Map<String, dynamic>.from(data as Map);

      double lat = map["lat"];
      double lng = map["lng"];
      double bearing = map["bearing"] ?? 0;

      LatLng newBusLocation = LatLng(lat, lng);
      _routePoints.add(newBusLocation);

      _polylines.clear(); // remove old polyline

      _polylines.add(
        Polyline(
          polylineId: const PolylineId("busRoute"),
          points: _routePoints,
          color: Colors.blue,
          width: 5,
        ),
      );

      setState(() {
        _busLocation = newBusLocation;

        _busMarker = Marker(
          markerId: const MarkerId("bus"),
          position: newBusLocation,
          icon: _busIcon ?? BitmapDescriptor.defaultMarker,
          rotation: bearing,
          anchor: const Offset(0.5, 0.5),
        );
      });
      //auto move camera to bus location
      _mapController?.animateCamera(
          CameraUpdate.newLatLng(newBusLocation)
      );
      _calculateETA();
    });
  }

  Future<void> _loadBusIcon() async {
    _busIcon = await BitmapDescriptor.fromAssetImage(
      const ImageConfiguration(size: Size(48, 48)),
      'assets/images/bus.png',
    );
  }

  // 🔥 ETA CALCULATION
  void _calculateETA() {
    if (_busLocation == null) return;

    double distanceInMeters = Geolocator.distanceBetween(
      _busLocation!.latitude,
      _busLocation!.longitude,
      _studentLocation.latitude,
      _studentLocation.longitude,
    );

    // 🔥 Bus Arrived
    if (distanceInMeters < 50) {
      setState(() {
        etaMinutes = 0;
      });
      return;
    }

    if (distanceInMeters < 300) {
      setState(() {
        etaMinutes = -1; // special value for nearby
      });
      return;
    }

    // 🔥 Normal ETA
    double speedMetersPerSecond = 30 * 1000 / 3600;
    double timeInSeconds = distanceInMeters / speedMetersPerSecond;

    setState(() {
      etaMinutes = (timeInSeconds / 60).ceilToDouble();
    });
  }

  Future<bool> _checkInternet() async {
    var connectivityResult = await Connectivity().checkConnectivity();

    if (connectivityResult == ConnectivityResult.none) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("No internet connection"),
          backgroundColor: Colors.red,
        ),
      );
      return false;
    }

    return true;
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
            myLocationButtonEnabled: true,
            markers: {
              if (_studentMarker != null) _studentMarker!,
              if (_busMarker != null) _busMarker!,
            },
            polylines: _polylines,
          ),

          // 🔥 SMART ETA DISPLAY
          if (etaMinutes != null)
            Positioned(
              top: 20,
              left: 20,
              right: 20,
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.black87,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Builder(
                  builder: (context) {
                    String etaText;

                    if (etaMinutes == 0) {
                      etaText = "🚌 Bus has arrived!";
                    } else if (etaMinutes == -1) {
                      etaText = "🚌 Bus is nearby";
                    } else {
                      etaText =
                      "🚌 Bus arriving in ${etaMinutes!.toInt()} mins";
                    }

                    return Text(
                      etaText,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                      ),
                      textAlign: TextAlign.center,
                    );
                  },
                ),
              ),
            ),
        ],
      ),
    );
  }
}