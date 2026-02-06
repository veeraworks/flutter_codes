import 'package:geolocator/geolocator.dart';
import 'package:firebase_database/firebase_database.dart';

class LocationService {

  static void startTracking(String busId) async {

    bool enabled = await Geolocator.isLocationServiceEnabled();
    if (!enabled) return;

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.deniedForever) return;

    Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 5,
      ),
    ).listen((position) {

      FirebaseDatabase.instance.ref("buses/$busId").set({
        "lat": position.latitude,
        "lng": position.longitude,
        "speed": position.speed * 3.6,
        "updatedAt": ServerValue.timestamp,
      });
    });
  }
}
