import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class DriverFullMapPage extends StatelessWidget {
  final LatLng currentLatLng;
  final Marker? marker;

  const DriverFullMapPage({
    super.key,
    required this.currentLatLng,
    required this.marker,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Live Bus Location")),
      body: GoogleMap(
        initialCameraPosition: CameraPosition(
          target: currentLatLng,
          zoom: 17,
        ),
        markers: marker != null ? {marker!} : {},
        myLocationEnabled: true,
      ),
    );
  }
}
