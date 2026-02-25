import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:shared_preferences/shared_preferences.dart';

class IssueReportingPage extends StatefulWidget {
  const IssueReportingPage({super.key});

  @override
  State<IssueReportingPage> createState() => _IssueReportingPageState();
}

class _IssueReportingPageState extends State<IssueReportingPage> {
  String? activeIssue;
  StreamSubscription<DatabaseEvent>? _issueListener;

  final List<Map<String, dynamic>> issues = [
    {"title": "Bus Breakdown", "icon": Icons.build, "color": Colors.red},
    {"title": "Accident", "icon": Icons.car_crash, "color": Colors.deepOrange},
    {"title": "Tyre Puncture", "icon": Icons.tire_repair, "color": Colors.orange},
    {"title": "Fuel Issue", "icon": Icons.local_gas_station, "color": Colors.amber},
    {"title": "Heavy Traffic", "icon": Icons.traffic, "color": Colors.blue},
    {"title": "Delay", "icon": Icons.schedule, "color": Colors.purple},
  ];

  // ================= INIT =================
  @override
  void initState() {
    super.initState();
    _listenToActiveIssue();
  }

  @override
  void dispose() {
    _issueListener?.cancel();
    super.dispose();
  }

  // ================= REAL-TIME LISTENER =================
  Future<void> _listenToActiveIssue() async {
    final prefs = await SharedPreferences.getInstance();
    final busId = prefs.getString("busId");

    if (busId == null) return;

    _issueListener?.cancel();

    _issueListener = FirebaseDatabase.instance
        .ref("busIssues/$busId")
        .onValue
        .listen((event) {
      final data = event.snapshot.value;

      if (data == null) {
        setState(() => activeIssue = null);
        return;
      }

      final map = Map<String, dynamic>.from(data as Map);

      if (map["status"] == "ACTIVE") {
        setState(() {
          activeIssue = map["issueType"];
        });
      } else {
        setState(() => activeIssue = null);
      }
    });
  }

  // ================= REPORT ISSUE =================
  Future<void> reportIssue(String issue) async {
    final prefs = await SharedPreferences.getInstance();
    final busId = prefs.getString("busId");
    final routeName = prefs.getString("routeName");

    if (busId == null || routeName == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Bus or Route not found")),
      );
      return;
    }

    await FirebaseDatabase.instance.ref("busIssues/$busId").set({
      "issueType": issue,
      "route": routeName,
      "status": "ACTIVE",
      "reportedAt": ServerValue.timestamp,
      "clearedAt": null,
    });

    try {
      await http.post(
        Uri.parse(
            "https://null-sheldon-unstudded.ngrok-free.dev/drivers/report-issue"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "busId": busId,
          "issueType": issue,
        }),
      );
    } catch (e) {
      print("Notification error: $e");
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text("Issue reported: $issue"),
        backgroundColor: Colors.red,
      ),
    );
  }

  // ================= CLEAR ISSUE =================
  Future<void> clearIssue() async {
    final prefs = await SharedPreferences.getInstance();
    final busId = prefs.getString("busId");

    if (busId == null) return;

    await FirebaseDatabase.instance.ref("busIssues/$busId").update({
      "status": "CLEARED",
      "clearedAt": ServerValue.timestamp,
    });

    try {
      await http.post(
        Uri.parse(
            "https://null-sheldon-unstudded.ngrok-free.dev/drivers/clear-issue"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"busId": busId}),
      );
    } catch (e) {
      print("Clear notification error: $e");
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("Issue cleared successfully"),
        backgroundColor: Colors.green,
      ),
    );
  }

  // ================= UI =================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F3F7),
      appBar: AppBar(
        title: const Text("Issue Reporting"),
        backgroundColor: const Color(0xFF00BFA6),
        foregroundColor: Colors.white,
      ),

      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            // ACTIVE ISSUE BANNER
            if (activeIssue != null) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.red),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "ACTIVE ISSUE",
                      style: TextStyle(
                        color: Colors.red,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      activeIssue!,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
            ],

            const Text(
              "Report an Issue",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 12),

            Expanded(
              child: GridView.builder(
                itemCount: issues.length,
                gridDelegate:
                const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  childAspectRatio: 1.4,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                ),
                itemBuilder: (context, index) {
                  final issue = issues[index];
                  final bool isDisabled = activeIssue != null;

                  return GestureDetector(
                    onTap:
                    isDisabled ? null : () => reportIssue(issue["title"]),
                    child: Opacity(
                      opacity: isDisabled ? 0.4 : 1,
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(18),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 10,
                            ),
                          ],
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(issue["icon"],
                                size: 36, color: issue["color"]),
                            const SizedBox(height: 10),
                            Text(issue["title"],
                                style: const TextStyle(
                                    fontWeight: FontWeight.w600)),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),

      // CLEAR BUTTON (ALWAYS VISIBLE)
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.all(16),
        child: SizedBox(
          height: 55,
          child: ElevatedButton.icon(
            onPressed: activeIssue != null ? clearIssue : null,
            icon: const Icon(Icons.check_circle, color: Colors.white),
            label: Text(
              activeIssue != null ? "CLEAR ALERT" : "NO ACTIVE ALERT",
              style: const TextStyle(
                  color: Colors.white, fontWeight: FontWeight.bold),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor:
              activeIssue != null ? Colors.red : Colors.grey,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
        ),
      ),
    );
  }
}