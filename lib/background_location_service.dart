import 'dart:async';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_background_service_android/flutter_background_service_android.dart';
import 'package:geolocator/geolocator.dart';
import 'package:firebase_database/firebase_database.dart';

String? activeBusId;
double _lastSpeed = 0;

Future<void> initializeService() async {
  final service = FlutterBackgroundService();

  await service.configure(
    androidConfiguration: AndroidConfiguration(
      onStart: onStart,
      autoStart: false,
      isForegroundMode: true,
      notificationChannelId: 'bus_tracking_channel',
      initialNotificationTitle: 'Smart Bus Tracking',
      initialNotificationContent: 'Tracking bus location...',
      foregroundServiceNotificationId: 999,
    ),
    iosConfiguration: IosConfiguration(),
  );
}

@pragma('vm:entry-point')
Future<void> onStart(ServiceInstance service) async {

  if (service is AndroidServiceInstance) {
    service.setForegroundNotificationInfo(
      title: "Smart Bus Tracking",
      content: "Tracking bus location...",
    );
  }

  // 🔵 RECEIVE BUS ID FROM DRIVER APP
  service.on("setBusId").listen((event) {
    activeBusId = event?["busId"]?.toString().toUpperCase();
    print("🔥 Background busId updated → $activeBusId");
  });

  // 🔴 STOP SERVICE WHEN TRIP ENDS
  service.on("stopService").listen((event) {
    print("🛑 Background service stopping...");
    service.stopSelf();
  });

  // 🟢 LOCATION LOOP
  Timer.periodic(const Duration(seconds: 8), (timer) async {

    if (service is AndroidServiceInstance) {
      if (!(await service.isForegroundService())) {
        timer.cancel();
        return;
      }
    }
    if (activeBusId == null) return;

    try {

      // 🔹 CHECK GPS SERVICE
      bool gpsEnabled = await Geolocator.isLocationServiceEnabled();
      if (!gpsEnabled) {
        print("❌ GPS disabled");
        return;
      }

      // 🔹 CHECK LOCATION PERMISSION
      LocationPermission permission = await Geolocator.checkPermission();

      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        print("❌ Location permission denied");
        return;
      }

      // 🔹 GET CURRENT POSITION
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      // ================= SPEED STABILIZATION =================

      double realSpeed = position.speed;

      // remove GPS noise
      if (realSpeed < 0.5) {
        realSpeed = 0;
      }

      // smoothing
      realSpeed = (_lastSpeed * 0.7) + (realSpeed * 0.3);

      // round to 1 decimal
      realSpeed = double.parse(realSpeed.toStringAsFixed(1));

      _lastSpeed = realSpeed;

      print("📡 BG UPDATE → Bus:$activeBusId | Speed:$realSpeed m/s");

      // 🔹 UPDATE FIREBASE
      await FirebaseDatabase.instance
          .ref("buses/$activeBusId/current")
          .update({
        "lat": position.latitude,
        "lng": position.longitude,
        "bearing": position.heading,
        "speed": realSpeed,
        "updatedAt": ServerValue.timestamp,
      });

    } catch (e) {
      print("❌ Background GPS error: $e");
    }
  });
}