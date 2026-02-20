import 'dart:async';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_background_service_android/flutter_background_service_android.dart';
import 'package:geolocator/geolocator.dart';
import 'package:firebase_database/firebase_database.dart';

String? activeBusId;   // 🔴 STEP 3.1 IMPORTANT

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

  // 🔴 STEP 3.2 RECEIVE BUS ID FROM APP
  service.on("setBusId").listen((event) {
    activeBusId = event?["busId"];
  });

  // 🔴 STEP 3.3 STOP SERVICE WHEN TRIP ENDS
  service.on("stopService").listen((event) {
    service.stopSelf();
  });

  // 🔴 STEP 3.4 GPS LOOP
  Timer.periodic(const Duration(seconds: 5), (timer) async {

    if (activeBusId == null) return;

    Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high);

    FirebaseDatabase.instance.ref("buses/$activeBusId").update({
      "lat": position.latitude,
      "lng": position.longitude,
      "bearing": position.heading,
      "updatedAt": ServerValue.timestamp,
    });

  });
}