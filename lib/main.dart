import 'package:flutter/material.dart';
import 'package:project_spt/student_login_page.dart';
import 'driver_login_page.dart';
import 'driver_home_page.dart';
import 'student_home_page.dart';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:shared_preferences/shared_preferences.dart';

final GlobalKey<NavigatorState> navigatorKey =
GlobalKey<NavigatorState>();

Future<void> _firebaseBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  print(" Background notification: ${message.notification?.title}");
}
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  print("🔔 Background message: ${message.messageId}");
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();

  FirebaseMessaging.onBackgroundMessage(_firebaseBackgroundHandler);

  // 🔥 Request notification permission (Android 13+ / iOS)
  await FirebaseMessaging.instance.requestPermission(
    alert: true,
    badge: true,
    sound: true,
  );

  FirebaseMessaging.instance.getToken().then((token) {
    print(" FCM TOKEN: $token");
  });

  FirebaseMessaging.onMessage.listen((RemoteMessage message) {
    print(" Foreground notification received");

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

  /// 🔥 NOTIFICATION CLICK LISTENER
  FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
    print("🔥 Notification clicked!");
  });

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey, // 🔥 VERY IMPORTANT
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

    // Optional test connection
    FirebaseDatabase.instance.ref("test").set("SmartBus connected");
  }

  /// 🔥 AUTO LOGIN FUNCTION
  Future<void> _checkAutoLogin() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();

    bool? isLoggedIn = prefs.getBool("isLoggedIn");
    String? role = prefs.getString("role");

    print("AutoLogin -> isLoggedIn: $isLoggedIn");
    print("AutoLogin -> role: $role");

    if (isLoggedIn == true && role != null) {

      if (role == "student") {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const StudentHomePage()),
        );
      }

      else if (role == "driver") {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const DriverHomePage()),
        );
      }
    }
  }

  void main() async {
    WidgetsFlutterBinding.ensureInitialized();
    await Firebase.initializeApp();

    FirebaseMessaging.onBackgroundMessage(
        _firebaseMessagingBackgroundHandler);

    runApp(MyApp());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
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

                      /// STUDENT LOGIN BUTTON
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
                            backgroundColor: const Color(0xFF00C9A7),
                            shape: RoundedRectangleBorder(
                              borderRadius:
                              BorderRadius.circular(25),
                            ),
                            elevation: 0,
                          ),
                          child: const Text(
                            'STUDENT LOGIN',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 20),

                      /// DRIVER LOGIN BUTTON
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
                              color: Color(0xFF00C9A7),
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
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF00C9A7),
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