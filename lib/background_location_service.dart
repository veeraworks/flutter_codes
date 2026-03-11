import 'dart:async';
import 'package:flutter/widgets.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_background_service_android/flutter_background_service_android.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:geolocator/geolocator.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_core/firebase_core.dart';
import 'utils/app_logger.dart';

String? activeBusId;
double _lastSpeed = 0;

/// INITIALIZE BACKGROUND SERVICE
Future<void> initializeService() async {

  final service = FlutterBackgroundService();

  const AndroidNotificationChannel channel = AndroidNotificationChannel(
    'bus_tracking_channel',
    'Bus Tracking Service',
    description: 'Tracks bus driver location in background',
    importance: Importance.low,
  );

  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
  FlutterLocalNotificationsPlugin();

  await flutterLocalNotificationsPlugin
      .resolvePlatformSpecificImplementation<
      AndroidFlutterLocalNotificationsPlugin>()
      ?.createNotificationChannel(channel);

  await service.configure(
    androidConfiguration: AndroidConfiguration(
      onStart: onStart,
      autoStart: false,
      autoStartOnBoot: true,
      isForegroundMode: true,
      notificationChannelId: 'bus_tracking_channel',
      initialNotificationTitle: 'Smart Bus Tracking',
      initialNotificationContent: 'Tracking bus location...',
      foregroundServiceNotificationId: 999,
    ),
    iosConfiguration: IosConfiguration(
      autoStart: false,
      onForeground: onStart,
      onBackground: onIosBackground,
    ),
  );
}

/// iOS BACKGROUND HANDLER
@pragma('vm:entry-point')
Future<bool> onIosBackground(ServiceInstance service) async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  return true;
}

/// SERVICE START
@pragma('vm:entry-point')
Future<void> onStart(ServiceInstance service) async {

  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();

  final db = FirebaseDatabase.instance.ref();

  /// FOREGROUND NOTIFICATION FOR ANDROID
  if (service is AndroidServiceInstance) {

    service.setAsForegroundService();

    service.setForegroundNotificationInfo(
      title: "Smart Bus Tracking",
      content: "Tracking bus location...",
    );
  }

  /// RECEIVE BUS ID FROM DRIVER APP
  service.on("setBusId").listen((event) {
    activeBusId = event?["busId"]?.toString().toUpperCase();
    appLog("🔥 Background busId updated → $activeBusId");
  });

  /// STOP SERVICE EVENT
  service.on("stopService").listen((event) {
    appLog("🛑 Background service stopping...");
    service.stopSelf();
  });

  /// LOCATION UPDATE LOOP
  Timer.periodic(const Duration(seconds: 4), (timer) async {

    if (service is AndroidServiceInstance) {
      if (!await service.isForegroundService()) {
        appLog("⚠ Service not in foreground, stopping timer");
        timer.cancel();
        return;
      }
    }

    try {

      if (activeBusId == null) return;

      bool gpsEnabled = await Geolocator.isLocationServiceEnabled();
      if (!gpsEnabled) return;

      LocationPermission permission = await Geolocator.checkPermission();

      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return;
      }

      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.bestForNavigation,
        timeLimit: const Duration(seconds: 10),
      );

      double realSpeed = position.speed;

      if (realSpeed < 0.5) realSpeed = 0;

      realSpeed = (_lastSpeed * 0.7) + (realSpeed * 0.3);
      realSpeed = double.parse(realSpeed.toStringAsFixed(1));

      _lastSpeed = realSpeed;

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
      appLog("❌ Background GPS error: $e");
    }
  });
}
