import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:shared_preferences/shared_preferences.dart';

class TemporaryBusChangePage extends StatefulWidget {
  const TemporaryBusChangePage({super.key});

  @override
  State<TemporaryBusChangePage> createState() =>
      _TemporaryBusChangePageState();
}

class _TemporaryBusChangePageState extends State<TemporaryBusChangePage> {
  final TextEditingController busController = TextEditingController();

  String currentBus = "-";
  String currentRoute = "-";
  String selectedRoute = "";

  bool isTempActive = false; // 🔥 KEY FLAG

  final List<String> routes = [
    "Ashok Pillar",
    "Koyambedu",
    "Madambakkam",
    "Nesapakkam",
    "Madipakkam",
    "Velachery",
    "Chengalpet",
    "Anakaputhur",
    "Sithalapakkam",
    "Padappai",
  ];

  @override
  void initState() {
    super.initState();
    _loadBusInfo();
  }

  // ================= LOAD BUS INFO =================
  Future<void> _loadBusInfo() async {
    final prefs = await SharedPreferences.getInstance();

    String savedBus = prefs.getString("busNumber") ?? "-";
    String savedRoute = prefs.getString("routeName") ?? "";

    // Ensure route exists in dropdown
    if (!routes.contains(savedRoute)) {
      savedRoute = routes.isNotEmpty ? routes.first : "";
    }

    setState(() {
      isTempActive = prefs.getBool("isTempBusActive") ?? false;
      currentBus = savedBus;
      currentRoute = savedRoute;
      selectedRoute = savedRoute;
    });

    if (!prefs.containsKey("originalBusNumber")) {
      await prefs.setString("originalBusNumber", savedBus);
      await prefs.setString("originalRoute", savedRoute);
    }
  }

  // ================= APPLY TEMP CHANGE =================
  Future<void> _applyTempChange() async {
    final prefs = await SharedPreferences.getInstance();
    final String? originalBus = prefs.getString("originalBusNumber");
    final String? busId = prefs.getString("busId");

    if (originalBus == null || busId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Bus information missing")),
      );
      return;
    }

    final String newBus =
    busController.text.trim().isNotEmpty
        ? busController.text.trim()
        : originalBus;

    try {
      // ✅ UPDATE LOCAL STORAGE
      await prefs.setString("tempBusNumber", newBus);
      await prefs.setString("tempRouteName", selectedRoute);
      await prefs.setBool("isTempBusActive", true);

      // ✅ UPDATE FIREBASE REALTIME DB
      await FirebaseDatabase.instance
          .ref("temporaryBusChanges/${busId.toUpperCase()}")
          .set({
        "newBus": newBus,
        "tempRoute": selectedRoute,
        "status": "ACTIVE",
        "updatedAt": ServerValue.timestamp,
      });

      // ✅ CALL BACKEND (SENDS NOTIFICATION TO BUS TOPIC)
      await http.post(
        Uri.parse("https://null-sheldon-unstudded.ngrok-free.dev/temporary-bus"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
            "busId": busId,
            "tempBusNumber": newBus,
            "active": true,
        }),
      );

      setState(() {
        isTempActive = true;
        currentBus = newBus;
        currentRoute = selectedRoute;
      });

      busController.clear();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Temporary bus applied successfully")),
      );

      Future.delayed(const Duration(milliseconds: 800), () {
        if (mounted) Navigator.pop(context, true);
      });

    } catch (e) {
      print("Temporary Bus Error: $e");

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Something went wrong")),
      );
    }
  }

  // ================= CLEAR TEMP CHANGE =================
  Future<void> _clearTempChange() async {
    final prefs = await SharedPreferences.getInstance();
    final String? originalBus = prefs.getString("originalBusNumber");
    final String? originalRoute = prefs.getString("originalRoute");
    final String? busId = prefs.getString("busId");

    if (originalBus == null || busId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Original bus not found")),
      );
      return;
    }

    try {
      // ✅ RESET LOCAL STORAGE
      await prefs.setBool("isTempBusActive", false);
      await prefs.remove("tempBusNumber");
      await prefs.remove("tempRouteName");

      // ✅ UPDATE FIREBASE
      await FirebaseDatabase.instance
          .ref("temporaryBusChanges/${busId.toUpperCase()}")
          .update({
        "newBus": null,
        "tempRoute": null,
        "status": "CLEARED",
        "updatedAt": ServerValue.timestamp,
      });

      // ✅ CALL BACKEND (NOTIFY RESTORE)
      await http.post(
        Uri.parse("https://null-sheldon-unstudded.ngrok-free.dev/temporary-bus"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "busId": busId,
          "active": false,
        }),
      );

      setState(() {
        isTempActive = false;
        currentBus = originalBus;
        currentRoute = originalRoute ?? "Madambakkam";
        selectedRoute = currentRoute;
      });

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Temporary bus cleared")),
      );

      Future.delayed(const Duration(milliseconds: 800), () {
        if (mounted) Navigator.pop(context, true);
      });

    } catch (e) {
      print("Clear Temp Error: $e");

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Something went wrong")),
      );
    }
  }
  // ================= UI =================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F3F7),
      appBar: AppBar(
        title: const Text("Temporary Bus Change"),
        backgroundColor: const Color(0xFF00BFA6),
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            // -------- CURRENT BUS INFO --------
            Container(
              padding: const EdgeInsets.all(16),
              decoration: _cardDecoration(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Current Bus Information",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 12),
                  _infoRow("Bus Number", currentBus),
                  _infoRow("Route", currentRoute),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // -------- TEMP CHANGE -----------------------------------
            Container(
              padding: const EdgeInsets.all(16),
              decoration: _cardDecoration(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Temporary Bus Change",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 12),

                  TextField(
                    controller: busController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      hintText: "Enter new bus number",
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),

                  const SizedBox(height: 14),

                  DropdownButtonFormField<String>(
                    value: selectedRoute,
                    items: routes
                        .map((route) => DropdownMenuItem(
                      value: route,
                      child: Text(route),
                    ))
                        .toList(),
                    onChanged: (val) {
                      setState(() => selectedRoute = val!);
                    },
                    decoration: InputDecoration(
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      contentPadding:
                      const EdgeInsets.symmetric(horizontal: 12),
                    ),
                  ),

                  const SizedBox(height: 16),

                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: _applyTempChange,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF00BFA6),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: const Text(
                        "Apply Temporary Change",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),

                  // 🔥 CLEAR BUTTON — ONLY WHEN ACTIVE
                  if (isTempActive) ...[
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: OutlinedButton(
                        onPressed: _clearTempChange,
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Colors.red),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: const Text(
                          "Clear Temporary Change",
                          style: TextStyle(
                            color: Colors.red,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ================= HELPERS =================
  BoxDecoration _cardDecoration() => BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(16),
    boxShadow: [
      BoxShadow(
        color: Colors.black.withOpacity(0.05),
        blurRadius: 10,
      ),
    ],
  );

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.black54)),
          Text(value,
              style: const TextStyle(fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}
