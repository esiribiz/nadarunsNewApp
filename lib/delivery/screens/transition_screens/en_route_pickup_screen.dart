import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../../main/models/OrderListModel.dart';
import '../../components/DriverDesignSystem.dart';

/// Screen 3: En Route to Pickup Screen
/// 
/// Active navigation screen showing real-time progress to pickup
/// Features:
/// - Full-screen map with live navigation
/// - Turn-by-turn instruction card
/// - Distance and time remaining
/// - Contact buttons (customer/support)
/// - Cancel trip option
class EnRouteToPickupScreen extends StatefulWidget {
  final OrderData? order;
  final VoidCallback? onArrivedAtPickup;
  final VoidCallback? onCancelTrip;
  final Function()? onContactCustomer;
  final Function()? onContactSupport;

  const EnRouteToPickupScreen({
    super.key,
    this.order,
    this.onArrivedAtPickup,
    this.onCancelTrip,
    this.onContactCustomer,
    this.onContactSupport,
  });

  @override
  State<EnRouteToPickupScreen> createState() => _EnRouteToPickupScreenState();
}

class _EnRouteToPickupScreenState extends State<EnRouteToPickupScreen>
    with TickerProviderStateMixin {
  GoogleMapController? _mapController;
  final Set<Marker> _markers = {};
  final Set<Polyline> _polylines = {};
  
  // Navigation state
  double _distanceRemaining = 2.4; // km
  int _timeRemaining = 8; // minutes
  String _nextInstruction = 'Turn right onto Main Street';
  
  // Animation controllers
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  late AnimationController _slideController;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _initAnimations();
    _loadNavigationData();
    
    // Simulate real-time updates
    _startNavigationUpdates();
  }

  void _initAnimations() {
    // Pulse animation for navigation arrow
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    // Slide up animation for bottom sheet
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

  void _loadNavigationData() {
    if (widget.order == null) return;

    final order = widget.order!;

    // Driver current location
    if (order.latitude != null && order.longitude != null) {
      _markers.add(Marker(
        markerId: const MarkerId('driver'),
        position: LatLng(order.latitude!, order.longitude!),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
        infoWindow: const InfoWindow(title: 'Your Location'),
      ));
    }

    // Pickup location - using pickupPoint from OrderData model
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

    // Draw active route - from current location to pickup point
    if (order.latitude != null &&
        order.pickupPoint != null &&
        order.pickupPoint!.latitude != null &&
        order.longitude != null &&
        order.pickupPoint!.longitude != null) {
      _polylines.add(Polyline(
        polylineId: const PolylineId('active_route'),
        points: [
          LatLng(double.parse(order.latitude!), double.parse(order.longitude!)),
          LatLng(double.parse(order.pickupPoint!.latitude!), double.parse(order.pickupPoint!.longitude!)),
        ],
        color: DriverPalette.routeLineActive,
        width: 6,
        patterns: [PatternItem.dash(20), PatternItem.gap(10)],
      ));
    }

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

      _mapController!.animateCamera(
        CameraUpdate.newLatLngBounds(bounds, 120),
      );
    }
  }

  void _startNavigationUpdates() {
    // Simulate navigation updates (in real app, this would come from GPS)
    Timer.periodic(const Duration(seconds: 5), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      
      setState(() {
        if (_timeRemaining > 0) {
          _timeRemaining = (_timeRemaining - 1).clamp(0, 999);
        }
        if (_distanceRemaining > 0) {
          _distanceRemaining = (_distanceRemaining - 0.05).clamp(0.0, 999.0);
        }
        
        // Check if arrived
        if (_distanceRemaining < 0.1) {
          timer.cancel();
          _showArrivedDialog();
        }
      });
    });
  }

  void _showArrivedDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Arrived at Pickup?'),
        content: const Text('Have you reached the pickup location?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Not Yet'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: DriverPalette.primary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: () {
              Navigator.pop(context);
              if (widget.onArrivedAtPickup != null) {
                widget.onArrivedAtPickup!();
              }
            },
            child: const Text('Yes, Arrived'),
          ),
        ],
      ),
    );
  }

  void _handleCancelTrip() {
    HapticFeedback.mediumImpact();
    if (widget.onCancelTrip != null) {
      widget.onCancelTrip!();
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
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
          // Full-screen map
          Positioned.fill(
            child: GoogleMap(
              initialCameraPosition: CameraPosition(
                target: order?.latitude != null
                    ? LatLng(order!.latitude!, order.longitude ?? 0)
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
              compassEnabled: false,
              trafficEnabled: true,
            ),
          ),

          // Top navigation header
          Positioned(
            top: MediaQuery.of(context).padding.top + 16,
            left: 16,
            right: 16,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
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
                  AnimatedBuilder(
                    animation: _pulseAnimation,
                    builder: (context, child) {
                      return Transform.rotate(
                        angle: _pulseAnimation.value * 0.1,
                        child: const Icon(
                          Icons.navigation,
                          color: DriverPalette.primary,
                          size: 28,
                        ),
                      );
                    },
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'En Route to Pickup',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: DriverPalette.textPrimary,
                          ),
                        ),
                        Text(
                          _nextInstruction,
                          style: TextStyle(
                            fontSize: 13,
                            color: DriverPalette.textSecondary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: DriverPalette.primaryLight,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${_timeRemaining} min',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: DriverPalette.primary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Bottom navigation card
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: SlideTransition(
              position: _slideAnimation,
              child: Container(
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
                        children: [
                          // Distance and time
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: [
                              _StatCard(
                                icon: Icons.directions_walk,
                                value: '${_distanceRemaining.toStringAsFixed(1)} km',
                                label: 'Distance',
                                color: DriverPalette.info,
                              ),
                              Container(
                                width: 1,
                                height: 40,
                                color: DriverPalette.divider,
                              ),
                              _StatCard(
                                icon: Icons.access_time,
                                value: '$_timeRemaining min',
                                label: 'Time',
                                color: DriverPalette.warning,
                              ),
                              Container(
                                width: 1,
                                height: 40,
                                color: DriverPalette.divider,
                              ),
                              _StatCard(
                                icon: Icons.local_gas_station,
                                value: '\$${order?.deliveryCharge ?? "0.00"}',
                                label: 'Earnings',
                                color: DriverPalette.earningsText,
                              ),
                            ],
                          ),

                          const SizedBox(height: 24),

                          // Contact buttons
                          Row(
                            children: [
                              Expanded(
                                child: _ContactButton(
                                  icon: Icons.phone,
                                  label: 'Call Customer',
                                  onTap: widget.onContactCustomer,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _ContactButton(
                                  icon: Icons.headset_mic,
                                  label: 'Support',
                                  onTap: widget.onContactSupport,
                                  isSecondary: true,
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 20),

                          // Arrived button
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: DriverPalette.primary,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 24,
                                  vertical: 18,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                elevation: 0,
                              ),
                              onPressed: () => _showArrivedDialog(),
                              child: const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.location_on, size: 24),
                                  SizedBox(width: 8),
                                  Text(
                                    'I\'ve Arrived at Pickup',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),

                          const SizedBox(height: 12),

                          // Cancel trip
                          TextButton(
                            onPressed: _handleCancelTrip,
                            child: Text(
                              'Cancel Trip',
                              style: TextStyle(
                                color: DriverPalette.error,
                                fontSize: 14,
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

// Stat Card Widget
class _StatCard extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final Color color;

  const _StatCard({
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: color, size: 24),
        const SizedBox(height: 6),
        Text(
          value,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: DriverPalette.textPrimary,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: DriverPalette.textSecondary,
          ),
        ),
      ],
    );
  }
}

// Contact Button Widget
class _ContactButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool isSecondary;

  const _ContactButton({
    required this.icon,
    required this.label,
    this.onTap,
    this.isSecondary = false,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: isSecondary
                ? DriverPalette.softBackground
                : DriverPalette.primaryLight,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                color: isSecondary
                    ? DriverPalette.textPrimary
                    : DriverPalette.primary,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: isSecondary
                      ? DriverPalette.textPrimary
                      : DriverPalette.primary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
