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

  LatLng _studentLocation = const LatLng(13.0827, 80.2707);
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

  // STUDENT LOCATION
  Future<void> _getStudentLocation() async {

    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();

    if (!serviceEnabled) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Enable GPS")),
      );
      return;
    }

    LocationPermission permission =
    await Geolocator.requestPermission();

    Position position =
    await Geolocator.getCurrentPosition();

    setState(() {

      _studentLocation =
          LatLng(position.latitude, position.longitude);

      _studentMarker = Marker(
        markerId: const MarkerId("student"),
        position: _studentLocation,
        icon: BitmapDescriptor.defaultMarkerWithHue(
          BitmapDescriptor.hueBlue,
        ),
      );

    });

  }


  // BUS LISTENER
  Future<void> _listenToBusLocation() async {

    bool hasInternet = await _checkInternet();
    if (!hasInternet) return;

    final prefs =
    await SharedPreferences.getInstance();

    // 🔥 FINAL FIX HERE
    String? busId =
    prefs.getString("busId")?.toUpperCase();

    print("Student listening busId = $busId");

    if (busId == null) return;


    _busListener = FirebaseDatabase.instance
        .ref("buses/$busId")
        .onValue
        .listen((event) {

      final data = event.snapshot.value;

      print("Firebase data = $data");

      if (data == null) return;

      final map =
      Map<String, dynamic>.from(data as Map);

      double lat =
      (map["lat"] as num).toDouble();

      double lng =
      (map["lng"] as num).toDouble();

      double bearing =
      (map["bearing"] ?? 0).toDouble();

      LatLng newBusLocation =
      LatLng(lat, lng);

      _routePoints.add(newBusLocation);

      _polylines.clear();

      _polylines.add(
        Polyline(
          polylineId:
          const PolylineId("route"),
          points: _routePoints,
          width: 5,
          color: Colors.blue,
        ),
      );


      setState(() {

        _busLocation = newBusLocation;

        _busMarker = Marker(

          markerId:
          const MarkerId("bus"),

          position: newBusLocation,

          icon: _busIcon ??
              BitmapDescriptor.defaultMarker,

          rotation: bearing,

          anchor:
          const Offset(0.5, 0.5),

        );

      });


      _mapController?.animateCamera(
        CameraUpdate.newLatLng(newBusLocation),
      );


      _calculateETA();

    });

  }



  Future<void> _loadBusIcon() async {

    _busIcon =
    await BitmapDescriptor.fromAssetImage(

      const ImageConfiguration(size: Size(48, 48)),

      "assets/images/bus.png",

    );

  }



  // ETA
  void _calculateETA() {

    if (_busLocation == null) return;

    double distance =
    Geolocator.distanceBetween(

      _busLocation!.latitude,
      _busLocation!.longitude,

      _studentLocation.latitude,
      _studentLocation.longitude,

    );

    double speed = 30 * 1000 / 3600;

    double time =
        distance / speed;

    setState(() {

      etaMinutes =
          (time / 60).ceilToDouble();

    });

  }



  Future<bool> _checkInternet() async {

    var result =
    await Connectivity().checkConnectivity();

    return result != ConnectivityResult.none;

  }



  @override
  Widget build(BuildContext context) {

    return Scaffold(

      appBar:
      AppBar(title: const Text("Live Bus Map")),

      body:

      GoogleMap(

        initialCameraPosition:

        CameraPosition(
          target: _studentLocation,
          zoom: 14,
        ),

        onMapCreated: (controller) {
          _mapController = controller;
        },

        myLocationEnabled: true,

        markers: {

          if (_studentMarker != null)
            _studentMarker!,

          if (_busMarker != null)
            _busMarker!,

        },

        polylines: _polylines,

      ),

    );

  }

}