import 'package:flutter/material.dart';
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

  final List<String> routes = [
    "Madambakkam",
    "Velachery",
    "Koyambedu",
    "Ashok Pillar",
    "Tambaram",
    "Chengalpattu",
  ];

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
    });
  }

  // 🔹 Apply temporary bus + route change
  Future<void> _applyTempChange() async {
    final prefs = await SharedPreferences.getInstance();

    if (busController.text.trim().isNotEmpty) {
      await prefs.setString("busNumber", busController.text.trim());
      currentBus = busController.text.trim();
    }

    await prefs.setString("route", selectedRoute);
    currentRoute = selectedRoute;

    busController.clear();

    setState(() {});

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("Temporary bus & route updated"),
      ),
    );
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
