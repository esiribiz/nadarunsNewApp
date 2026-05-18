import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

/// A placeholder widget for displaying Google Maps with optional markers and routes
class MapPlaceholderWidget extends StatelessWidget {
  final bool showRoute;
  final bool showCurrentLocation;
  final bool showPickupMarker;
  final bool showDropoffMarker;
  final PickupPoint? pickupLocation;
  final PickupPoint? dropoffLocation;
  final LatLng? currentLocation;
  final Set<Polyline>? polylines;
  final Function(GoogleMapController)? onMapCreated;

  const MapPlaceholderWidget({
    Key? key,
    this.showRoute = false,
    this.showCurrentLocation = true,
    this.showPickupMarker = false,
    this.showDropoffMarker = false,
    this.pickupLocation,
    this.dropoffLocation,
    this.currentLocation,
    this.polylines,
    this.onMapCreated,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GoogleMap(
      initialCameraPosition: CameraPosition(
        target: _getInitialLatLng(),
        zoom: 15,
      ),
      markers: _buildMarkers(),
      polylines: showRoute && polylines != null ? polylines! : {},
      myLocationEnabled: showCurrentLocation,
      myLocationButtonEnabled: showCurrentLocation,
      mapToolbarEnabled: false,
      zoomControlsEnabled: false,
      onMapCreated: (controller) {
        if (onMapCreated != null) {
          onMapCreated!(controller);
        }
      },
    );
  }

  LatLng _getInitialLatLng() {
    if (currentLocation != null) {
      return currentLocation!;
    }
    if (pickupLocation != null && pickupLocation!.latitude != null) {
      return LatLng(
        double.parse(pickupLocation!.latitude!),
        double.parse(pickupLocation!.longitude!),
      );
    }
    // Default to a central location if nothing is provided
    return const LatLng(24.8607, 67.0011); // Karachi coordinates as default
  }

  Set<Marker> _buildMarkers() {
    final Set<Marker> markers = {};

    if (showPickupMarker && pickupLocation != null) {
      markers.add(
        Marker(
          markerId: const MarkerId('pickup'),
          position: LatLng(
            double.parse(pickupLocation!.latitude!),
            double.parse(pickupLocation!.longitude!),
          ),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
          infoWindow: InfoWindow(
            title: 'Pickup Location',
            snippet: pickupLocation!.address ?? '',
          ),
        ),
      );
    }

    if (showDropoffMarker && dropoffLocation != null) {
      markers.add(
        Marker(
          markerId: const MarkerId('dropoff'),
          position: LatLng(
            double.parse(dropoffLocation!.latitude!),
            double.parse(dropoffLocation!.longitude!),
          ),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
          infoWindow: InfoWindow(
            title: 'Dropoff Location',
            snippet: dropoffLocation!.address ?? '',
          ),
        ),
      );
    }

    return markers;
  }
}
