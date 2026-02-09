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
  bool isTemporaryApplied = false; // Track if temporary change is active

  final List<String> routes = [
    "Madambakkam",
    "Velachery",
    "Koyambedu",
    "Ashok Pillar",
    "Tambaram",
    "Chengalpattu",
  ];

  // Store original values for reset
  String? originalBus;
  String? originalRoute;

  @override
  void initState() {
    super.initState();
    _loadBusInfo();
  }

  // 🔹 Load current bus & route
  Future<void> _loadBusInfo() async {
    final prefs = await SharedPreferences.getInstance();

    setState(() {
      currentBus = prefs.getString("busNumber") ?? "9";
      currentRoute = prefs.getString("route") ?? "Madambakkam";
      selectedRoute = currentRoute;
      originalBus = prefs.getString("originalBus") ?? currentBus;
      originalRoute = prefs.getString("originalRoute") ?? currentRoute;
      isTemporaryApplied = prefs.getBool("isTemporaryApplied") ?? false;
    });
  }

  // 🔹 Apply temporary bus + route change
  Future<void> _applyTempChange() async {
    final prefs = await SharedPreferences.getInstance();
    final String? busId = prefs.getString("busId");

    print("🔥 APPLY TEMP BUS CLICKED");
    print("🔥 busId = $busId");

    if (busId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Bus ID not found")),
      );
      return;
    }

    // ---------- SAVE TEMP DATA LOCALLY ----------
    if (busController.text.trim().isNotEmpty) {
      await prefs.setString("busNumber", busController.text.trim());
      currentBus = busController.text.trim();
    }

    await prefs.setString("route", selectedRoute);
    currentRoute = selectedRoute;

    // ✅ SET FLAG TO TRUE so "Clear" button appears
    await prefs.setBool("isTemporaryApplied", true);

    // ---------- BACKEND SYNC ----------
    await FirebaseDatabase.instance
        .ref("temporaryBus/$busId")
        .set({
      "active": true,
      "tempBusNumber": currentBus,
      "tempRoute": currentRoute,
      "updatedAt": ServerValue.timestamp,
    }).then((_) {
      print("✅ TEMP BUS WRITTEN TO FIREBASE");
    }).catchError((e) {
      print("❌ FIREBASE ERROR: $e");
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Temporary bus applied")),
    );

    // Update UI to show "Clear" button
    setState(() {
      isTemporaryApplied = true;
    });

    // Navigate back to home page and notify to reload
    if (mounted) {
      Navigator.pop(context, true);
    }
  }

  // 🔹 Clear temporary change — revert to original
  Future<void> _clearTempChange() async {
    final prefs = await SharedPreferences.getInstance();
    final String? busId = prefs.getString("busId");

    if (busId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Bus ID not found")),
      );
      return;
    }

    // ---------- LOCAL RESET ----------
    final String originalBus =
        prefs.getString("originalBus") ?? "9";
    final String originalRoute =
        prefs.getString("originalRoute") ?? "Madambakkam";

    await prefs.setString("busNumber", originalBus);
    await prefs.setString("route", originalRoute);
    await prefs.setBool("isTemporaryApplied", false);

    // ---------- BACKEND UPDATE ----------
    await FirebaseDatabase.instance
        .ref("temporaryBus/$busId")
        .update({
      "active": false,
      "clearedAt": ServerValue.timestamp,
    }).then((_)
    {
      print("✅ TEMP BUS CLEARED IN FIREBASE");
    }).catchError((e)
    {
      print("❌ CLEAR TEMP BUS ERROR: $e");
    });

    // ---------- UI ----------
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Temporary bus cleared")),
    );

    // Go back & notify home page to reload
    Navigator.pop(context, true);
  }

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

            // ================= CURRENT BUS INFO =================
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Current Bus Information",
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _infoRow("Bus Number", currentBus),
                  _infoRow("Route", currentRoute),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // ================= TEMP CHANGE =================
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Temporary Bus Change",
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 12),

                  // 🔢 BUS NUMBER
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

                  // 🛣 ROUTE DROPDOWN
                  DropdownButtonFormField<String>(
                    value: selectedRoute,
                    items: routes
                        .map(
                          (route) => DropdownMenuItem(
                        value: route,
                        child: Text(route),
                      ),
                    )
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

                  // Show "Clear Temporary Change" button only if temporary change is applied
                  if (isTemporaryApplied) ...[
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
                            fontSize: 16,
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
