import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class DriverFullMapPage extends StatelessWidget {
  final LatLng currentLatLng;
  final Marker? marker;
  final List<LatLng> routePoints;

  const DriverFullMapPage({
    super.key,
    required this.currentLatLng,
    this.marker,
    required this.routePoints,
  });

  Set<Polyline> _buildPolylines() {
    if (routePoints.length < 2) return {};

    return {
      Polyline(
        polylineId: const PolylineId("route"),
        points: routePoints,
        color: Colors.blue,
        width: 5,
        startCap: Cap.roundCap,
        endCap: Cap.roundCap,
        jointType: JointType.round,
      ),
    };
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Live Bus Location")),
      body: GoogleMap(
        initialCameraPosition: CameraPosition(
          target: currentLatLng,
          zoom: 15,
        ),
        markers: marker != null ? {marker!} : {},
        polylines: _buildPolylines(), // ✅ KEY LINE
        myLocationEnabled: true,
        myLocationButtonEnabled: true,
      ),
    );
  }
}
