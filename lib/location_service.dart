import 'dart:async';
import 'package:geolocator/geolocator.dart';
import 'package:firebase_database/firebase_database.dart';

class LocationService {
  static StreamSubscription<Position>? _positionStream;

  /// START tracking (called when Trip starts)
  static Future<void> startTracking(String busId) async {
    // 1️⃣ Check GPS
    bool enabled = await Geolocator.isLocationServiceEnabled();
    if (!enabled) {
      return;
    }

    // 2️⃣ Check permission
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.deniedForever) {
      return;
    }

    // 3️⃣ Stop existing stream if any
    await stopTracking();

    // 4️⃣ Start foreground location stream
    _positionStream = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 5,
      ),
    ).listen((position) {
      FirebaseDatabase.instance.ref("buses/$busId/current").set({
        "lat": position.latitude,
        "lng": position.longitude,
        "speed": position.speed * 3.6, // km/h
        "updatedAt": ServerValue.timestamp,
      });
    });
  }

  /// STOP tracking (called when Trip ends)
  static Future<void> stopTracking() async {
    await _positionStream?.cancel();
    _positionStream = null;
  }
}
