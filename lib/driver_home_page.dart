import 'package:flutter/material.dart';
import 'location_service.dart';

class DriverHomePage extends StatefulWidget {
  const DriverHomePage({super.key});

  @override
  State<DriverHomePage> createState() => _DriverHomePageState();
}

class _DriverHomePageState extends State<DriverHomePage> {
  bool tripStarted = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F3F7),

      // ☰ DRAWER
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(20, 50, 20, 24),
              color: const Color(0xFF00BFA6),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Driver Information',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w600),
                  ),
                  SizedBox(height: 12),
                  Text('Name: Ravi Kumar',
                      style: TextStyle(color: Colors.white)),
                  Text('Driver ID: DRV102',
                      style: TextStyle(color: Colors.white)),
                  SizedBox(height: 8),
                  Text('Permanent Route: Madambakkam',
                      style: TextStyle(color: Colors.white70)),
                  Text('Route Bus Number: 9',
                      style: TextStyle(color: Colors.white70)),
                ],
              ),
            ),

            const SizedBox(height: 12),

            ListTile(
              leading: const Icon(Icons.swap_horiz),
              title: const Text('Temporary Service Update'),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const TemporaryServiceUpdatePage()),
                );
              },
            ),

            ListTile(
              leading: const Icon(Icons.report_problem, color: Colors.red),
              title: const Text('Issue Reporting'),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const IssueReportingPage()),
                );
              },
            ),
          ],
        ),
      ),

      body: Column(
        children: [
          // HEADER
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(20, 40, 20, 28),
            decoration: const BoxDecoration(
              color: Color(0xFF00BFA6),
              borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(24),
                  bottomRight: Radius.circular(24)),
            ),
            child: Row(
              children: [
                Builder(
                  builder: (context) => IconButton(
                    icon: const Icon(Icons.menu, color: Colors.white),
                    onPressed: () => Scaffold.of(context).openDrawer(),
                  ),
                ),
                const SizedBox(width: 8),
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Driver Dashboard',
                        style:
                        TextStyle(color: Colors.white, fontSize: 24)),
                    SizedBox(height: 6),
                    Text('BusTrackPro',
                        style: TextStyle(
                            color: Colors.white70, fontSize: 16)),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          _infoCard(
            title: 'Bus Information',
            children: const [
              _infoRow('Route', 'Madambakkam'),
              _infoRow('Route Bus Number', '9'),
              _infoRow('Shift', 'Morning'),
            ],
          ),

          const SizedBox(height: 16),

          _infoCard(
            title: 'Location Status',
            children: const [
              _statusRow('GPS', true),
              _statusRow('Internet', true),
              _statusRow('Location Sync', true),
            ],
          ),

          const SizedBox(height: 24),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: GestureDetector(
              onTap: () {
                setState(() {
                  tripStarted = !tripStarted;
                });

                // 👉 later we connect this to Firebase tracking
              },
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 18),
                decoration: BoxDecoration(
                  color: tripStarted ? Colors.red : const Color(0xFF00BFA6),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Center(
                  child: Text(
                    tripStarted ? 'End Trip' : 'Start Trip',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoCard(
      {required String title, required List<Widget> children}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)
            ]),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style: const TextStyle(
                    fontSize: 18, fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),
            ...children,
          ],
        ),
      ),
    );
  }
}

// ---------------- EXTRA PAGES ----------------

class TemporaryServiceUpdatePage extends StatelessWidget {
  const TemporaryServiceUpdatePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Temporary Service Update')),
      body: const Center(child: Text("Temporary update page")),
    );
  }
}

class IssueReportingPage extends StatelessWidget {
  const IssueReportingPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Issue Reporting')),
      body: const Center(child: Text("Issue reporting page")),
    );
  }
}

// ---------------- SMALL WIDGETS ----------------

class _infoRow extends StatelessWidget {
  final String label;
  final String value;
  const _infoRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
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

class _statusRow extends StatelessWidget {
  final String label;
  final bool active;
  const _statusRow(this.label, this.active);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.black54)),
          Icon(active ? Icons.check_circle : Icons.error,
              color: active ? Colors.green : Colors.red, size: 20),
        ],
      ),
    );
  }
}
