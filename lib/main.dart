import 'package:flutter/material.dart';
import 'package:project_spt/student_login_page.dart';
import 'driver_login_page.dart';
import 'driver_home_page.dart';
import 'student_home_page.dart';


import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:shared_preferences/shared_preferences.dart';

final GlobalKey<NavigatorState> navigatorKey =
GlobalKey<NavigatorState>();

/// 🔥 BACKGROUND HANDLER (MUST BE TOP LEVEL)
Future<void> _firebaseMessagingBackgroundHandler(
    RemoteMessage message) async {
  await Firebase.initializeApp();
  print("🔔 Background message received");
}
Future<void> saveNotification(RemoteMessage message) async {
  final user = FirebaseAuth.instance.currentUser;

  if (user == null) {
    print("⚠ No logged in user, notification not saved");
    return;
  }

  await FirebaseDatabase.instance
      .ref("notifications/${user.uid}")
      .push()
      .set({
    "title": message.notification?.title ?? "",
    "body": message.notification?.body ?? "",
    "time": ServerValue.timestamp,
    "read": false,
  });

  print("✅ Notification saved in database");
}
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();

  /// 🔥 REGISTER BACKGROUND HANDLER
  FirebaseMessaging.onBackgroundMessage(
      _firebaseMessagingBackgroundHandler);

  /// 🔥 REQUEST NOTIFICATION PERMISSION (Android 13+ / iOS)
  await FirebaseMessaging.instance.requestPermission(
    alert: true,
    badge: true,
    sound: true,
  );

  /// 🔥 PRINT FCM TOKEN
  FirebaseMessaging.instance.getToken().then((token) {
    print("🔥 FCM TOKEN: $token");
  });

  /// 🔥 FOREGROUND LISTENER
  FirebaseMessaging.onMessage.listen((RemoteMessage message) async {
    print("📩 Foreground notification received");

    // ✅ SAVE TO FIREBASE
    await saveNotification(message);

    if (message.notification != null &&
        navigatorKey.currentContext != null) {
      ScaffoldMessenger.of(navigatorKey.currentContext!)
          .showSnackBar(
        SnackBar(
          content: Text(
            message.notification!.title ?? "Notification",
          ),
          duration: const Duration(seconds: 3),
        ),
      );
    }
  });
  /// 🔥 WHEN USER CLICKS NOTIFICATION
  FirebaseMessaging.onMessageOpenedApp.listen(
          (RemoteMessage message) async {
        print("🔥 Notification clicked");

        await saveNotification(message);
      });

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.light,
        colorSchemeSeed: const Color(0xFF00C9A7),
        scaffoldBackgroundColor: Colors.white,
        useMaterial3: true,
      ),
      home: const WelcomePage(),
    );
  }
}

class WelcomePage extends StatefulWidget {
  const WelcomePage({super.key});

  @override
  State<WelcomePage> createState() => _WelcomePageState();
}

class _WelcomePageState extends State<WelcomePage> {

  @override
  void initState() {
    super.initState();
    _checkAutoLogin();

    // Optional Firebase test
    FirebaseDatabase.instance
        .ref("test")
        .set("SmartBus connected");
  }

  /// 🔥 AUTO LOGIN
  Future<void> _checkAutoLogin() async {
    SharedPreferences prefs =
    await SharedPreferences.getInstance();

    bool? isLoggedIn = prefs.getBool("isLoggedIn");
    String? role = prefs.getString("role");

    if (isLoggedIn == true && role != null) {

      if (role == "student") {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
              builder: (_) => const StudentHomePage()),
        );
      }

      else if (role == "driver") {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
              builder: (_) => const DriverHomePage()),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding:
          const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            children: [
              const SizedBox(height: 60),

              Image.asset(
                'assets/images/bus.png',
                width: 300,
                height: 300,
                fit: BoxFit.contain,
              ),

              Expanded(
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [

                      /// STUDENT LOGIN
                      SizedBox(
                        width: 220,
                        height: 50,
                        child: ElevatedButton(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) =>
                                const StudentLoginPage(),
                              ),
                            );
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor:
                            const Color(0xFF00C9A7),
                            shape: RoundedRectangleBorder(
                              borderRadius:
                              BorderRadius.circular(25),
                            ),
                          ),
                          child: const Text(
                            'STUDENT LOGIN',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight:
                              FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 20),

                      /// DRIVER LOGIN
                      SizedBox(
                        width: 220,
                        height: 50,
                        child: OutlinedButton(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) =>
                                const DriverLoginPage(),
                              ),
                            );
                          },
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(
                              color:
                              Color(0xFF00C9A7),
                              width: 2,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius:
                              BorderRadius.circular(25),
                            ),
                          ),
                          child: const Text(
                            'DRIVER LOGIN',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight:
                              FontWeight.w600,
                              color:
                              Color(0xFF00C9A7),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
