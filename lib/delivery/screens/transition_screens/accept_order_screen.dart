import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';
import '../../../main/models/OrderListModel.dart';
import '../../../main/utils/Constants.dart';
import '../../components/DriverDesignSystem.dart';

/// Screen 1: Accept Order Screen
/// 
/// Modern incoming order request screen inspired by Uber Driver and Wolt Courier
/// Features:
/// - Full-screen map background with pickup/dropoff markers
/// - Floating bottom sheet with order details
/// - Large accept/reject buttons for easy one-tap while driving
/// - Real-time order data display
/// - Countdown timer for decision
/// - Customer rating, distance, earnings, ETA
class AcceptOrderScreen extends StatefulWidget {
  final OrderData? order;
  final Function(bool accepted)? onDecision;
  final int decisionTimeoutSeconds;

  const AcceptOrderScreen({
    super.key,
    this.order,
    this.onDecision,
    this.decisionTimeoutSeconds = 30,
  });

  @override
  State<AcceptOrderScreen> createState() => _AcceptOrderScreenState();
}

class _AcceptOrderScreenState extends State<AcceptOrderScreen>
    with TickerProviderStateMixin {
  GoogleMapController? _mapController;
  final Set<Marker> _markers = {};
  final Set<Polyline> _polylines = {};
  Timer? _countdownTimer;
  int _remainingSeconds = 30;
  bool _isAnimating = false;

  // Animation controllers
  late AnimationController _slideController;
  late AnimationController _pulseController;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _remainingSeconds = widget.decisionTimeoutSeconds;
    _initAnimations();
    _startCountdown();
    _loadOrderMarkers();
  }

  void _initAnimations() {
    // Slide up animation for bottom sheet
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeOutCubic,
    ));

    // Pulse animation for urgency indicator
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _slideController.forward();
  }

  void _startCountdown() {
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_remainingSeconds > 0) {
        setState(() {
          _remainingSeconds--;
        });
      } else {
        _handleTimeout();
      }
    });
  }

  void _handleTimeout() {
    _countdownTimer?.cancel();
    if (widget.onDecision != null) {
      widget.onDecision!(false); // Auto-reject on timeout
    }
    if (mounted) {
      Navigator.of(context).pop(false);
    }
  }

  void _loadOrderMarkers() {
    if (widget.order == null) return;

    final order = widget.order!;
    
    // Pickup marker - using pickupPoint from OrderData model
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

    // Dropoff marker - using deliveryPoint from OrderData model
    if (order.deliveryPoint != null && 
        order.deliveryPoint!.latitude != null && 
        order.deliveryPoint!.longitude != null) {
      _markers.add(Marker(
        markerId: const MarkerId('dropoff'),
        position: LatLng(double.parse(order.deliveryPoint!.latitude!), double.parse(order.deliveryPoint!.longitude!)),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
        infoWindow: InfoWindow(
          title: 'Dropoff Location',
          snippet: order.deliveryPoint!.address ?? 'Delivery point',
        ),
      ));
    }

    // Draw route polyline
    if (order.pickupPoint != null &&
        order.deliveryPoint != null &&
        order.pickupPoint!.latitude != null &&
        order.pickupPoint!.longitude != null &&
        order.deliveryPoint!.latitude != null &&
        order.deliveryPoint!.longitude != null) {
      _polylines.add(Polyline(
        polylineId: const PolylineId('route'),
        points: [
          LatLng(double.parse(order.pickupPoint!.latitude!), double.parse(order.pickupPoint!.longitude!)),
          LatLng(double.parse(order.deliveryPoint!.latitude!), double.parse(order.deliveryPoint!.longitude!)),
        ],
        color: DriverPalette.routeLine,
        width: 4,
        patterns: [PatternItem.dash(20), PatternItem.gap(10)],
      ));
    }

    // Center map on route
    _centerMapOnRoute();
  }

  void _centerMapOnRoute() {
    if (widget.order == null || _mapController == null) return;

    final order = widget.order!;
    if (order.pickupPoint != null && 
        order.deliveryPoint != null &&
        order.pickupPoint!.latitude != null && 
        order.deliveryPoint!.latitude != null) {
      final lat1 = double.parse(order.pickupPoint!.latitude!);
      final lat2 = double.parse(order.deliveryPoint!.latitude!);
      final lng1 = order.pickupPoint!.longitude != null ? double.parse(order.pickupPoint!.longitude!) : 0;
      final lng2 = order.deliveryPoint!.longitude != null ? double.parse(order.deliveryPoint!.longitude!) : 0;

      final bounds = LatLngBounds(
        southwest: LatLng(lat1 < lat2 ? lat1 : lat2, lng1 < lng2 ? lng1 : lng2),
        northeast: LatLng(lat1 > lat2 ? lat1 : lat2, lng1 > lng2 ? lng1 : lng2),
      );

      _mapController!.animateCamera(CameraUpdate.newLatLngBounds(bounds, 100));
    }
  }

  void _handleAccept() {
    HapticFeedback.lightImpact();
    _countdownTimer?.cancel();
    
    if (widget.onDecision != null) {
      widget.onDecision!(true);
    }
    
    if (mounted) {
      Navigator.of(context).pop(true);
    }
  }

  void _handleReject() {
    HapticFeedback.mediumImpact();
    _countdownTimer?.cancel();
    
    if (widget.onDecision != null) {
      widget.onDecision!(false);
    }
    
    if (mounted) {
      Navigator.of(context).pop(false);
    }
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _slideController.dispose();
    _pulseController.dispose();
    _mapController?.dispose();
    super.dispose();
  }

  Color _getCountdownColor() {
    if (_remainingSeconds > 15) return DriverPalette.success;
    if (_remainingSeconds > 5) return DriverPalette.warning;
    return DriverPalette.error;
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
                zoom: 12,
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
              style: _getMapStyle(),
            ),
          ),

          // Top gradient overlay for better text visibility
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: 120,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withOpacity(0.6),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),

          // Top bar with timer
          Positioned(
            top: MediaQuery.of(context).padding.top + 16,
            left: 20,
            right: 20,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Urgency indicator
                AnimatedBuilder(
                  animation: _pulseAnimation,
                  builder: (context, child) {
                    return Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.timer_outlined,
                            color: _getCountdownColor(),
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '${_remainingSeconds}s',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: _getCountdownColor(),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),

                // Close button
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.close, size: 24),
                    onPressed: () => _handleReject(),
                    color: DriverPalette.textPrimary,
                  ),
                ),
              ],
            ),
          ),

          // Bottom sheet with order details
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: SlideTransition(
              position: _slideAnimation,
              child: Container(
                constraints: BoxConstraints(
                  maxHeight: screenSize.height * 0.65,
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

                    // Order details content
                    Expanded(
                      child: SingleChildScrollView(
                        physics: const BouncingScrollPhysics(),
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Header
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: DriverPalette.primaryLight,
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: const Icon(
                                    Icons.shopping_bag_outlined,
                                    color: DriverPalette.primary,
                                    size: 28,
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'New Delivery Request',
                                        style: TextStyle(
                                          fontSize: 20,
                                          fontWeight: FontWeight.bold,
                                          color: DriverPalette.textPrimary,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'Customer: ${order?.customerName ?? "Unknown"}',
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: DriverPalette.textSecondary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),

                            const SizedBox(height: 24),

                            // Key metrics grid
                            Row(
                              children: [
                                Expanded(
                                  child: _MetricCard(
                                    icon: Icons.attach_money,
                                    label: 'Earnings',
                                    value: '\$${order?.deliveryCharge ?? "0.00"}',
                                    color: DriverPalette.earningsText,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: _MetricCard(
                                    icon: Icons.directions_walk,
                                    label: 'Distance',
                                    value: '${order?.distance ?? "0"} km',
                                    color: DriverPalette.info,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: _MetricCard(
                                    icon: Icons.access_time,
                                    label: 'ETA',
                                    value: '${order?.estimatedDeliveryTime ?? "0"} min',
                                    color: DriverPalette.warning,
                                  ),
                                ),
                              ],
                            ),

                            const SizedBox(height: 24),

                            // Route details
                            _RouteDetailRow(
                              icon: Icons.my_location,
                              iconColor: DriverPalette.mapPinOrigin,
                              title: 'Pickup',
                              subtitle: order?.fromAddress ?? 'Loading...',
                            ),

                            const SizedBox(height: 16),

                            _RouteDetailRow(
                              icon: Icons.place,
                              iconColor: DriverPalette.mapPinDestination,
                              title: 'Dropoff',
                              subtitle: order?.toAddress ?? 'Loading...',
                            ),

                            const SizedBox(height: 24),

                            // Customer rating
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: DriverPalette.softBackground,
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.person_outline,
                                    color: DriverPalette.primary,
                                    size: 24,
                                  ),
                                  const SizedBox(width: 12),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Customer Rating',
                                        style: TextStyle(
                                          fontSize: 13,
                                          color: DriverPalette.textSecondary,
                                        ),
                                      ),
                                      Row(
                                        children: [
                                          const Icon(
                                            Icons.star,
                                            color: DriverPalette.warning,
                                            size: 18,
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            '${order?.customerRating ?? "0.0"}',
                                            style: TextStyle(
                                              fontSize: 18,
                                              fontWeight: FontWeight.bold,
                                              color: DriverPalette.textPrimary,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),

                            const SizedBox(height: 24),

                            // Action buttons
                            Row(
                              children: [
                                // Reject button
                                Expanded(
                                  child: _ActionButton(
                                    text: 'Decline',
                                    icon: Icons.close,
                                    backgroundColor: DriverPalette.softBackground,
                                    textColor: DriverPalette.textPrimary,
                                    onTap: _handleReject,
                                  ),
                                ),
                                const SizedBox(width: 16),
                                // Accept button
                                Expanded(
                                  flex: 2,
                                  child: _ActionButton(
                                    text: 'Accept Order',
                                    icon: Icons.check_circle,
                                    backgroundColor: DriverPalette.primary,
                                    textColor: Colors.white,
                                    onTap: _handleAccept,
                                    isPrimary: true,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
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

  String _getMapStyle() {
    return '''
    [
      {
        "featureType": "all",
        "elementType": "geometry",
        "stylers": [{"color": "#f5f5f5"}]
      },
      {
        "featureType": "road",
        "elementType": "geometry",
        "stylers": [{"color": "#ffffff"}]
      },
      {
        "featureType": "water",
        "elementType": "geometry",
        "stylers": [{"color": "#c9e6f5"}]
      }
    ]
    ''';
  }
}

// Metric Card Widget
class _MetricCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _MetricCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: DriverPalette.softBackground,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(height: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: DriverPalette.textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: DriverPalette.textPrimary,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

// Route Detail Row Widget
class _RouteDetailRow extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;

  const _RouteDetailRow({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: iconColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: iconColor, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 12,
                  color: DriverPalette.textSecondary,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: DriverPalette.textPrimary,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// Action Button Widget
class _ActionButton extends StatelessWidget {
  final String text;
  final IconData icon;
  final Color backgroundColor;
  final Color textColor;
  final VoidCallback onTap;
  final bool isPrimary;

  const _ActionButton({
    required this.text,
    required this.icon,
    required this.backgroundColor,
    required this.textColor,
    required this.onTap,
    this.isPrimary = false,
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
            color: backgroundColor,
            borderRadius: BorderRadius.circular(16),
            border: isPrimary ? null : Border.all(color: DriverPalette.borderMedium),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: textColor, size: 22),
              const SizedBox(width: 8),
              Text(
                text,
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  color: textColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
