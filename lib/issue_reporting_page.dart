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

  final List<Map<String, dynamic>> issues = [
    {"title": "Bus Breakdown", "icon": Icons.build, "color": Colors.red},
    {"title": "Accident", "icon": Icons.car_crash, "color": Colors.deepOrange},
    {"title": "Tyre Puncture", "icon": Icons.tire_repair, "color": Colors.orange},
    {"title": "Fuel Issue", "icon": Icons.local_gas_station, "color": Colors.amber},
    {"title": "Heavy Traffic", "icon": Icons.traffic, "color": Colors.blue},
    {"title": "Delay", "icon": Icons.schedule, "color": Colors.purple},
  ];

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

    // 1️⃣ Save issue in database
    await FirebaseDatabase.instance
        .ref("busIssues/$busId")
        .set({
      "issueType": issue,
      "route": routeName,
      "status": "ACTIVE",
      "reportedAt": ServerValue.timestamp,
      "clearedAt": null,
    });

    // 2️⃣ Call backend to send notification
    try {
      await http.post(
        Uri.parse("https://null-sheldon-unstudded.ngrok-free.dev/notify-route"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "route": routeName,
          "title": "Bus Issue Alert",
          "body": "$issue reported on your route.",
        }),
      );
    } catch (e) {
      print("Notification error: $e");
    }

    setState(() {
      activeIssue = issue;
    });

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

    await FirebaseDatabase.instance
        .ref("busIssues/$busId")
        .update({
      "status": "CLEARED",
      "clearedAt": ServerValue.timestamp,
    });

    setState(() {
      activeIssue = null;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("Issue cleared successfully"),
        backgroundColor: Colors.green,
      ),
    );
  }

  // ================= UI ==============================================
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

            // 🚨 ACTIVE ISSUE BANNER
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
                    const SizedBox(height: 14),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton.icon(
                        onPressed: clearIssue,
                        icon: const Icon(Icons.check_circle,
                            color: Colors.white),
                        label: const Text(
                          "CLEAR ALERT",
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
            ],

            const Text(
              "Report an Issue",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 12),

            // 🔘 ISSUE BUTTONS
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
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
                  onTap: isDisabled
                      ? null
                      : () => reportIssue(issue["title"]),
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
                          Icon(
                            issue["icon"],
                            size: 36,
                            color: issue["color"],
                          ),
                          const SizedBox(height: 10),
                          Text(
                            issue["title"],
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
