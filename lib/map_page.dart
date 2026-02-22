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

  LatLng? _studentStopLocation;

  Marker? _busMarker;

  Marker? _studentMarker;

  BitmapDescriptor? _busIcon;

  Set<Marker> _stopMarkers = {};

  Set<Polyline> _polylines = {};

  List<LatLng> _routePoints = [];

  StreamSubscription<DatabaseEvent>? _busListener;

  double? etaMinutes;

  String? busId;
  String? stopName;

  // INIT
  @override
  void initState() {
    super.initState();

    initAll();
  }

  Future<void> initAll() async {

    await loadPrefs();

    await _getStudentLocation();

    await _loadBusIcon();

    await _loadBusStops();

    await _listenToBusLocation();

  }

  // LOAD PREFS
  Future<void> loadPrefs() async {

    final prefs = await SharedPreferences.getInstance();

    busId = prefs.getString("busId")?.toUpperCase();

    stopName = prefs.getString("stopName");

    print("Student busId = $busId");

    print("Student stopName = $stopName");

  }


  // STUDENT GPS
  Future<void> _getStudentLocation() async {

    bool serviceEnabled =
    await Geolocator.isLocationServiceEnabled();

    if (!serviceEnabled) return;

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
            BitmapDescriptor.hueBlue),
      );

    });

  }



  // LOAD BUS ICON
  Future<void> _loadBusIcon() async {

    _busIcon =
    await BitmapDescriptor.fromAssetImage(
      const ImageConfiguration(size: Size(48,48)),
      "assets/images/bus.png",
    );

  }



  // LOAD STOPS FROM FIREBASE
  Future<void> _loadBusStops() async {

    if(busId == null) return;

    final snapshot =
    await FirebaseDatabase.instance
        .ref("busRoutes/$busId")
        .once();

    if (!snapshot.snapshot.exists) {

      print("No stops found in Firebase");

      return;
    }

    Map data =
    snapshot.snapshot.value as Map;

    Set<Marker> markers = {};

    data.forEach((key,value){

      double lat =
      (value["lat"] as num).toDouble();

      double lng =
      (value["lng"] as num).toDouble();

      String name =
      key.toString();

      LatLng position =
      LatLng(lat,lng);

      markers.add(
        Marker(
          markerId: MarkerId(name),
          position: position,
          infoWindow: InfoWindow(title: name),
          icon: BitmapDescriptor.defaultMarkerWithHue(
              BitmapDescriptor.hueOrange),
        ),
      );

      if(name == stopName){

        _studentStopLocation = position;

      }

    });

    setState(() {

      _stopMarkers = markers;

    });

  }



  // BUS LISTENER
  Future<void> _listenToBusLocation() async {

    if(busId == null) return;

    bool hasInternet =
        await Connectivity().checkConnectivity()
            != ConnectivityResult.none;

    if(!hasInternet) return;


    _busListener =
        FirebaseDatabase.instance
            .ref("buses/$busId")
            .onValue
            .listen((event){

          final data =
              event.snapshot.value;

          if(data == null) return;

          final map =
          Map<String,dynamic>.from(data as Map);

          double lat =
          (map["lat"] as num).toDouble();

          double lng =
          (map["lng"] as num).toDouble();

          double bearing =
          (map["bearing"] ?? 0).toDouble();

          LatLng newBusLocation =
          LatLng(lat,lng);

          _routePoints.add(newBusLocation);

          _polylines.clear();

          _polylines.add(
            Polyline(
              polylineId: const PolylineId("route"),
              points: _routePoints,
              width:5,
              color: Colors.blue,
            ),
          );

          setState(() {

            _busLocation = newBusLocation;

            _busMarker = Marker(
              markerId: const MarkerId("bus"),
              position: newBusLocation,
              icon: _busIcon ??
                  BitmapDescriptor.defaultMarker,
              rotation: bearing,
              anchor: const Offset(0.5,0.5),
            );

          });

          _mapController?.animateCamera(
              CameraUpdate.newLatLng(newBusLocation));

          calculateETA();

        });

  }



  // ETA USING STOP LOCATION
  void calculateETA(){

    if(_busLocation == null ||
        _studentStopLocation == null) return;

    double distance =
    Geolocator.distanceBetween(

      _busLocation!.latitude,
      _busLocation!.longitude,

      _studentStopLocation!.latitude,
      _studentStopLocation!.longitude,

    );

    double speed = 30 * 1000 / 3600;

    double time = distance / speed;

    setState(() {

      etaMinutes =
          (time/60).ceilToDouble();

    });

    print("ETA = $etaMinutes");

  }




  @override
  Widget build(BuildContext context){

    return Scaffold(

      appBar: AppBar(
        title: const Text("Live Bus Map"),
      ),

      body:

      Stack(

        children: [

          GoogleMap(

            initialCameraPosition:
            CameraPosition(
              target: _studentLocation,
              zoom:14,
            ),

            onMapCreated:(controller){

              _mapController = controller;

            },

            myLocationEnabled:true,

            markers:{

              if(_busMarker!=null)
                _busMarker!,

              if(_studentMarker!=null)
                _studentMarker!,

              ..._stopMarkers,

            },

            polylines:_polylines,

          ),



          // ETA UI

          if(etaMinutes != null)

            Positioned(

              top:20,
              left:20,
              right:20,

              child:

              Container(

                padding:
                const EdgeInsets.all(12),

                decoration:
                BoxDecoration(

                  color: Colors.black87,

                  borderRadius:
                  BorderRadius.circular(10),

                ),

                child:

                Text(

                  "Bus arriving in ${etaMinutes!.toInt()} mins",

                  style:
                  const TextStyle(

                      color: Colors.white,

                      fontSize:16),

                  textAlign:
                  TextAlign.center,

                ),

              ),

            )

        ],

      ),

    );

  }



  @override
  void dispose(){

    _busListener?.cancel();

    super.dispose();

  }

}