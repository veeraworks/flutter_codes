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

  String currentBus = "Not Assigned";
  String currentRoute = "Madambakkam";
  String selectedRoute = "Madambakkam";

  bool isTempActive = false; // 🔥 KEY FLAG

  final List<String> routes = [
    "Ashok Pillar",
    "Koyambedu",
    "Madambakkam"
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

    setState(() {
      isTempActive = prefs.getBool("isTempBusActive") ?? false;
      currentBus = prefs.getString("busNumber") ?? "9";
      currentRoute = prefs.getString("routeName") ?? "Madambakkam";
      selectedRoute = currentRoute;
    });

    // 🔥 STORE ORIGINAL BUS/ROUTE ON FIRST LOAD (if not already stored)
    if (!prefs.containsKey("originalBusNumber")) {
      await prefs.setString("originalBusNumber", currentBus);
      await prefs.setString("originalRoute", currentRoute);
    }
  }

  // ================= APPLY TEMP CHANGE =================
  Future<void> _applyTempChange() async {
    final prefs = await SharedPreferences.getInstance();
    final String? originalBus = prefs.getString("originalBusNumber");
    final String? busId = prefs.getString("busId");

    if (originalBus == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Original bus not found")),
      );
      return;
    }

    final String newBus =
        busController.text.trim().isNotEmpty
            ? busController.text.trim()
            : originalBus;

    await prefs.setString("busNumber", newBus);
    await prefs.setString("tempBusNumber", newBus);
    await prefs.setString("routeName", selectedRoute);
    await prefs.setBool("isTempBusActive", true);

    if (busId != null) {
      await FirebaseDatabase.instance
          .ref("temporaryBus/$busId")
          .set({
        "active": true,
        "tempBusNumber": newBus,
        "tempRoute": selectedRoute,
        "updatedAt": ServerValue.timestamp,
      }).catchError((e) {
        print("Firebase error: $e");
      });
    }

    busController.clear();

    // 🔥 UPDATE UI IMMEDIATELY
    setState(() {
      isTempActive = true;
      currentBus = newBus;
      currentRoute = selectedRoute;
    });

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Temporary bus applied successfully")),
    );

    // 🔥 RETURN TRUE TO NOTIFY HOME PAGE AFTER SNACKBAR
    Future.delayed(const Duration(milliseconds: 800), () {
      if (mounted) Navigator.pop(context, true);
    });
  }

  // ================= CLEAR TEMP CHANGE =================
  Future<void> _clearTempChange() async {
    final prefs = await SharedPreferences.getInstance();
    final String? originalBus = prefs.getString("originalBusNumber");
    final String? originalRoute = prefs.getString("originalRoute");
    final String? busId = prefs.getString("busId");

    if (originalBus == null) return;

    await prefs.setBool("isTempBusActive", false);
    await prefs.remove("tempBusNumber");
    await prefs.setString("busNumber", originalBus);
    if (originalRoute != null) {
      await prefs.setString("routeName", originalRoute);
    }

    if (busId != null) {
      await FirebaseDatabase.instance
          .ref("temporaryBus/$busId")
          .update({
        "active": false,
        "updatedAt": ServerValue.timestamp,
      }).catchError((e) {
        print("Firebase error: $e");
      });
    }

    // 🔥 UPDATE UI IMMEDIATELY
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

    // 🔥 RETURN TRUE TO NOTIFY HOME PAGE AFTER SNACKBAR
    Future.delayed(const Duration(milliseconds: 800), () {
      if (mounted) Navigator.pop(context, true);
    });
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

            // -------- TEMP CHANGE --------
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
