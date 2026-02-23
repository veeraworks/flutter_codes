import 'dart:async';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_background_service_android/flutter_background_service_android.dart';
import 'package:geolocator/geolocator.dart';
import 'package:firebase_database/firebase_database.dart';

String? activeBusId;
double _lastSpeed = 0;   // 🔥 speed smoothing memory

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

void onStart(ServiceInstance service) {

  if (service is AndroidServiceInstance) {
    service.setForegroundNotificationInfo(
      title: "Smart Bus Tracking",
      content: "Tracking bus location...",
    );
  }

  // ✅ RECEIVE UPDATED BUS ID FROM DRIVER APP
  service.on("setBusId").listen((event) {
    activeBusId = event?["busId"]?.toString().toUpperCase();
    print("🔥 Background busId updated to: $activeBusId");
  });

  // ✅ STOP SERVICE WHEN TRIP ENDS
  service.on("stopService").listen((event) {
    print("🛑 Background service stopping...");
    service.stopSelf();
  });

  // ✅ GPS LOOP
  Timer.periodic(const Duration(seconds: 5), (timer) async {

    if (activeBusId == null) return;

    try {
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      // ================= SPEED STABILIZATION =================
      double realSpeed = position.speed;

      // Remove tiny GPS noise
      if (realSpeed < 0.5) {
        realSpeed = 0;
      }

      // Exponential smoothing
      realSpeed = (_lastSpeed * 0.7) + (realSpeed * 0.3);

      // Round to 1 decimal
      realSpeed = double.parse(realSpeed.toStringAsFixed(1));

      _lastSpeed = realSpeed;

      print("📡 BG UPDATE → $activeBusId | Speed: $realSpeed m/s");

      // ✅ UPDATE FIREBASE (CORRECT PATH)
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