import 'dart:async';
import 'package:geolocator/geolocator.dart';
import 'package:firebase_database/firebase_database.dart';

class LocationService {
  static StreamSubscription<Position>? _positionStream;
//========================= START TRACKING =====================================
  static Future<void> startTracking(String busId) async {
    bool enabled = await Geolocator.isLocationServiceEnabled();
    if (!enabled) {
      return;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.deniedForever) {
      return;
    }

    await stopTracking();

    _positionStream = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 5,
      ),
    ).listen((position) {
      FirebaseDatabase.instance.ref("buses/$busId").update({
        "lat": position.latitude,
        "lng": position.longitude,
        "bearing": position.heading,
        "updatedAt": ServerValue.timestamp,
      });
    });
  }

//========================= STOP TRACKING =====================================
  static Future<void> stopTracking() async {
    await _positionStream?.cancel();
    _positionStream = null;
  }
}
