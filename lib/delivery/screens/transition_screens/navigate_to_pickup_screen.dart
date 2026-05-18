import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../../main/models/OrderListModel.dart';
import '../components/DriverDesignSystem.dart';

/// Screen 2: Navigate to Pickup Screen
/// 
/// Navigation screen showing route to pickup location
/// Features:
/// - Full-screen map with highlighted route
/// - Turn-by-turn navigation preview
/// - Distance and time to pickup
/// - Contact customer button
/// - Cancel order option
class NavigateToPickupScreen extends StatefulWidget {
  final OrderData? order;
  final VoidCallback? onStartNavigation;
  final VoidCallback? onArrivedAtPickup;
  final VoidCallback? onCancelOrder;

  const NavigateToPickupScreen({
    super.key,
    this.order,
    this.onStartNavigation,
    this.onArrivedAtPickup,
    this.onCancelOrder,
  });

  @override
  State<NavigateToPickupScreen> createState() => _NavigateToPickupScreenState();
}

class _NavigateToPickupScreenState extends State<NavigateToPickupScreen>
    with TickerProviderStateMixin {
  GoogleMapController? _mapController;
  final Set<Marker> _markers = {};
  final Set<Polyline> _polylines = {};
  CameraPosition? _currentCameraPosition;
  
  // Animation controllers
  late AnimationController _slideController;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _initAnimations();
    _loadRouteData();
  }

  void _initAnimations() {
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeOutCubic,
    ));
    _slideController.forward();
  }

  void _loadRouteData() {
    if (widget.order == null) return;

    final order = widget.order!;

    // Driver location marker (current position)
    if (order.latitude != null && order.longitude != null) {
      _markers.add(Marker(
        markerId: const MarkerId('driver'),
        position: LatLng(order.latitude!, order.longitude!),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
        infoWindow: const InfoWindow(title: 'Your Location'),
      ));
    }

    // Pickup location marker - using pickupPoint from OrderData model
    if (order.pickupPoint != null && 
        order.pickupPoint!.latitude != null && 
        order.pickupPoint!.longitude != null) {
      _markers.add(Marker(
        markerId: const MarkerId('pickup'),
        position: LatLng(double.parse(order.pickupPoint!.latitude!), double.parse(order.pickupPoint!.longitude!)),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
        infoWindow: InfoWindow(
          title: 'Pickup Location',
          snippet: order.pickupPoint!.address ?? 'Pickup point',
        ),
      ));
    }

    // Draw route polyline from driver to pickup
    if (order.latitude != null &&
        order.pickupPoint != null &&
        order.pickupPoint!.latitude != null &&
        order.longitude != null &&
        order.pickupPoint!.longitude != null) {
      _polylines.add(Polyline(
        polylineId: const PolylineId('route_to_pickup'),
        points: [
          LatLng(double.parse(order.latitude!), double.parse(order.longitude!)),
          LatLng(double.parse(order.pickupPoint!.latitude!), double.parse(order.pickupPoint!.longitude!)),
        ],
        color: DriverPalette.routeLineActive,
        width: 6,
        patterns: const [PatternItem.dash(30), PatternItem.gap(15)],
      ));
    }

    // Center map on route
    _centerMapOnRoute();
  }

  void _centerMapOnRoute() {
    if (widget.order == null || _mapController == null) return;

    final order = widget.order!;
    if (order.latitude != null && 
        order.pickupPoint != null &&
        order.pickupPoint!.latitude != null) {
      final lat1 = double.parse(order.latitude!);
      final lat2 = double.parse(order.pickupPoint!.latitude!);
      final lng1 = order.longitude != null ? double.parse(order.longitude!) : 0;
      final lng2 = order.pickupPoint!.longitude != null ? double.parse(order.pickupPoint!.longitude!) : 0;

      final bounds = LatLngBounds(
        southwest: LatLng(lat1 < lat2 ? lat1 : lat2, lng1 < lng2 ? lng1 : lng2),
        northeast: LatLng(lat1 > lat2 ? lat1 : lat2, lng1 > lng2 ? lng1 : lng2),
      );

      _mapController!.animateCamera(CameraUpdate.newLatLngBounds(bounds, 120));
    }
  }

  void _handleArrivedAtPickup() {
    HapticFeedback.mediumImpact();
    if (widget.onArrivedAtPickup != null) {
      widget.onArrivedAtPickup!();
    }
  }

  void _handleContactCustomer() {
    HapticFeedback.lightImpact();
    // TODO: Implement phone call or chat functionality
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Contacting customer...'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _handleCancelOrder() {
    HapticFeedback.mediumImpact();
    if (widget.onCancelOrder != null) {
      widget.onCancelOrder!();
    }
  }

  @override
  void dispose() {
    _slideController.dispose();
    _mapController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final order = widget.order;
    final screenSize = MediaQuery.of(context).size;

    return Scaffold(
      body: Stack(
        children: [
          // Full-screen map background
          Positioned.fill(
            child: GoogleMap(
              initialCameraPosition: CameraPosition(
                target: order?.pickupPoint?.latitude != null
                    ? LatLng(double.parse(order!.pickupPoint!.latitude!), double.parse(order.pickupPoint!.longitude ?? '0'))
                    : const LatLng(0, 0),
                zoom: 13,
              ),
              markers: _markers,
              polylines: _polylines,
              onMapCreated: (controller) {
                _mapController = controller;
                _centerMapOnRoute();
              },
              myLocationEnabled: true,
              myLocationButtonEnabled: false,
              zoomControlsEnabled: false,
              mapToolbarEnabled: false,
              compassEnabled: true,
            ),
          ),

          // Top bar with navigation info
          Positioned(
            top: MediaQuery.of(context).padding.top + 16,
            left: 20,
            right: 20,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  // Navigation arrow icon
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: DriverPalette.primaryLight,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.navigation,
                      color: DriverPalette.primary,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Navigate to Pickup',
                          style: TextStyle(
                            fontSize: 13,
                            color: DriverPalette.textSecondary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            Text(
                              '${order?.distance ?? "0"} km',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: DriverPalette.textPrimary,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: DriverPalette.success.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                '~${order?.estimatedDeliveryTime ?? "0"} min',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: DriverPalette.success,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Bottom sheet with actions
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: SlideTransition(
              position: _slideAnimation,
              child: Container(
                constraints: BoxConstraints(
                  maxHeight: screenSize.height * 0.35,
                ),
                decoration: const BoxDecoration(
                  color: DriverPalette.surfaceCard,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(28),
                    topRight: Radius.circular(28),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: DriverPalette.shadowHeavy,
                      blurRadius: 32,
                      offset: Offset(0, -8),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Handle bar
                    Container(
                      margin: const EdgeInsets.only(top: 14),
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: DriverPalette.borderMedium,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),

                    Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Destination info
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: DriverPalette.mapPinOrigin.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Icon(
                                  Icons.my_location,
                                  color: DriverPalette.mapPinOrigin,
                                  size: 22,
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Pickup Location',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: DriverPalette.textSecondary,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      order?.fromAddress ?? 'Loading...',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: DriverPalette.textPrimary,
                                      ),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 24),

                          // Action buttons row
                          Row(
                            children: [
                              // Contact button
                              Expanded(
                                child: _ActionChip(
                                  icon: Icons.phone_outlined,
                                  label: 'Contact',
                                  onTap: _handleContactCustomer,
                                ),
                              ),
                              const SizedBox(width: 12),
                              // Arrived button
                              Expanded(
                                flex: 2,
                                child: _PrimaryButton(
                                  icon: Icons.check_circle_outline,
                                  text: 'I\'m Here',
                                  onTap: _handleArrivedAtPickup,
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 16),

                          // Cancel button
                          SizedBox(
                            width: double.infinity,
                            child: TextButton.icon(
                              onPressed: _handleCancelOrder,
                              icon: const Icon(Icons.cancel_outlined, size: 20),
                              label: const Text('Cancel Order'),
                              style: TextButton.styleFrom(
                                foregroundColor: DriverPalette.error,
                                padding: const EdgeInsets.symmetric(vertical: 14),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Action Chip Widget
class _ActionChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _ActionChip({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          decoration: BoxDecoration(
            color: DriverPalette.softBackground,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: DriverPalette.borderMedium),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 20, color: DriverPalette.textPrimary),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: DriverPalette.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Primary Button Widget
class _PrimaryButton extends StatelessWidget {
  final IconData icon;
  final String text;
  final VoidCallback onTap;

  const _PrimaryButton({
    required this.icon,
    required this.text,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
          decoration: BoxDecoration(
            color: DriverPalette.primary,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: Colors.white, size: 22),
              const SizedBox(width: 8),
              Text(
                text,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
