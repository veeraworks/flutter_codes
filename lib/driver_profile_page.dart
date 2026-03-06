import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class DriverProfilePage extends StatefulWidget {
  const DriverProfilePage({super.key});

  @override
  State<DriverProfilePage> createState() => _DriverProfilePageState();
}

class _DriverProfilePageState extends State<DriverProfilePage> {

  String driverName = "-";
  String busId = "-";
  String routeName = "-";
  String busNumber = "-";
  String phoneNumber = "-";
  String licenseNo = "-";

  @override
  void initState() {
    super.initState();
    _loadDriverData();
  }

  Future<void> _loadDriverData() async {
    final prefs = await SharedPreferences.getInstance();

    print("RouteName from prefs: ${prefs.getString("routeName")}");

    if (!mounted) return;

    setState(() {
      driverName = prefs.getString("driverName") ?? "-";
      busId = prefs.getString("busId") ?? "-";
      routeName = prefs.getString("routeName") ?? "-";
      busNumber = prefs.getString("busNumber") ?? "-";
      phoneNumber = prefs.getString("phone") ?? "-";
      licenseNo = prefs.getString("licenseNo") ?? "-";
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F3F7),

      appBar: AppBar(
        title: const Text("Driver Profile"),
        backgroundColor: const Color(0xFF00BFA6),
        foregroundColor: Colors.white,
        elevation: 0,
      ),

      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [

            /// PROFILE CARD
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    spreadRadius: 2,
                  )
                ],
              ),

              child: Column(
                children: [

                  const CircleAvatar(
                    radius: 40,
                    backgroundColor: Color(0xFFE0F7F3),
                    child: Icon(
                      Icons.person,
                      size: 40,
                      color: Color(0xFF00BFA6),
                    ),
                  ),

                  const SizedBox(height: 16),

                  const Text(
                    "Driver Details",
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  const SizedBox(height: 20),

                  ProfileRow("Name", driverName),
                  ProfileRow("Bus ID", busId),
                  ProfileRow("Bus Number", busNumber),
                  ProfileRow("Route", routeName),
                  ProfileRow("License", licenseNo),
                  ProfileRow("Phone", phoneNumber),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ProfileRow extends StatelessWidget {
  final String label;
  final String value;

  const ProfileRow(this.label, this.value, {super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),

      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,

        children: [
          Text(
            label,
            style: const TextStyle(
              color: Colors.black54,
              fontSize: 15,
            ),
          ),

          Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 15,
            ),
          ),
        ],
      ),
    );
  }
}