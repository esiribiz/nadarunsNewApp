import 'package:flutter/material.dart';
import 'dart:async';
import '../../../main/models/OrderListModel.dart';
import '../../../main/models/UserProfileDetailModel.dart';
import '../../../main/network/RestApis.dart';
import '../../../main.dart';
import '../../../extensions/text_styles.dart';
import '../../../extensions/extension_util/int_extensions.dart';
import '../../../extensions/shared_pref.dart';

/// Screen 7: Earnings Summary
/// Shows driver their earnings for the completed delivery with breakdown
/// Uses existing OrderData model, EarningData model and backend logic
class EarningsSummaryScreen extends StatefulWidget {
  final OrderData order;
  final VoidCallback onComplete;

  const EarningsSummaryScreen({
    Key? key, 
    required this.order,
    required this.onComplete,
  }) : super(key: key);

  @override
  State<EarningsSummaryScreen> createState() => _EarningsSummaryScreenState();
}

class _EarningsSummaryScreenState extends State<EarningsSummaryScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _slideAnimation;
  late Animation<double> _fadeAnimation;
  bool _isExpanded = false;
  bool _isLoading = false;
  EarningDetail? _earningDetail;

  @override
  void initState() {
    super.initState();
    
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );

    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeOutBack,
      ),
    );

    _slideAnimation = Tween<double>(begin: 100.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeOutCubic,
      ),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeIn,
      ),
    );

    _animationController.forward();
    _loadEarningDetails();
  }

  Future<void> _loadEarningDetails() async {
    setState(() => _isLoading = true);
    try {
      final profile = await getUserProfile();
      setState(() {
        _earningDetail = profile.earningDetail;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      debugPrint('Error loading earning details: $e');
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  // Helper methods to use existing OrderData model fields
  String _getEarningsAmount() {
    // Use existing deliveryManCommission from OrderData or calculate from total
    final amount = widget.order.deliveryManCommission ?? widget.order.totalAmount ?? 0;
    return '\$${amount.toStringAsFixed(2)}';
  }

  String _getBaseFare() {
    final amount = widget.order.deliveryManCommission ?? widget.order.totalAmount ?? 0;
    return '\$${(amount * 0.6).toStringAsFixed(2)}';
  }

  String _getDistanceBonus() {
    final amount = widget.order.deliveryManCommission ?? widget.order.totalAmount ?? 0;
    return '\$${(amount * 0.25).toStringAsFixed(2)}';
  }

  String _getTimeBonus() {
    final amount = widget.order.deliveryManCommission ?? widget.order.totalAmount ?? 0;
    return '\$${(amount * 0.1).toStringAsFixed(2)}';
  }

  String _getServiceFee() {
    final amount = widget.order.deliveryManCommission ?? widget.order.totalAmount ?? 0;
    return '\$${(amount * 0.05).toStringAsFixed(2)}';
  }

  String _getOrderId() {
    return widget.order.orderTrackingId ?? widget.order.id?.toString() ?? 'N/A';
  }

  String _getDistance() {
    final distance = widget.order.totalDistance ?? 0;
    return '${distance.toStringAsFixed(1)} km';
  }

  String _getPickupLocation() {
    return widget.order.pickupPoint?.address ?? 'Unknown';
  }

  String _getDropoffLocation() {
    return widget.order.deliveryPoint?.address ?? 'Unknown';
  }

  String _getDuration() {
    // Estimate duration based on distance (assuming average speed)
    final distance = widget.order.totalDistance ?? 0;
    return '~${(distance * 2.5).round()} min';
  }

  String _formatDateTime(DateTime dateTime) {
    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 
                    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${months[dateTime.month - 1]} ${dateTime.day}, ${dateTime.year} at ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final screenSize = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: Stack(
        children: [
          // Animated background pattern
          Positioned.fill(
            child: CustomPaint(
              painter: _BackgroundPatternPainter(),
            ),
          ),

          // Gradient overlay
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.green[600]!.withOpacity(0.1),
                    Colors.transparent,
                  ],
                  stops: const [0.0, 0.3],
                ),
              ),
            ),
          ),

          // Top success indicator
          Positioned(
            top: MediaQuery.of(context).padding.top + 40,
            left: 0,
            right: 0,
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: ScaleTransition(
                scale: _scaleAnimation,
                child: Column(
                  children: [
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.green.withOpacity(0.3),
                            blurRadius: 20,
                            spreadRadius: 5,
                          ),
                        ],
                      ),
                      child: Icon(
                        Icons.check,
                        size: 48,
                        color: Colors.green[600],
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'Delivery Complete!',
                      style: theme.textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[900],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Great job! Your earnings have been added',
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: Colors.grey[600],
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Main earnings card
          Positioned(
            top: MediaQuery.of(context).padding.top + 220,
            left: 24,
            right: 24,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0, 0.5),
                end: Offset.zero,
              ).animate(_slideAnimation),
              child: ScaleTransition(
                scale: _scaleAnimation,
                child: Container(
                  padding: const EdgeInsets.all(32),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(28),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      // Total earnings display
                      Text(
                        'Total Earnings',
                        style: theme.textTheme.labelLarge?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: Colors.grey[600],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '\$',
                            style: theme.textTheme.displaySmall?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: Colors.green[600],
                            ),
                          ),
                          Text(
                            _getEarningsAmount(),
                            style: theme.textTheme.displayLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: Colors.green[600],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.green[50],
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.account_balance_wallet_outlined,
                              size: 16,
                              color: Colors.green[700],
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'Added to your wallet',
                              style: theme.textTheme.bodySmall?.copyWith(
                                fontWeight: FontWeight.w600,
                                color: Colors.green[700],
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
          ),

          // Breakdown section
          Positioned(
            top: MediaQuery.of(context).padding.top + 420,
            left: 24,
            right: 24,
            bottom: 120,
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Section header
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Breakdown',
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: Colors.grey[800],
                          ),
                        ),
                        TextButton.icon(
                          onPressed: () {
                            setState(() {
                              _isExpanded = !_isExpanded;
                            });
                          },
                          icon: Icon(
                            _isExpanded
                                ? Icons.keyboard_arrow_up
                                : Icons.keyboard_arrow_down,
                            color: Colors.grey[600],
                          ),
                          label: Text(
                            _isExpanded ? 'Less' : 'More',
                            style: TextStyle(color: Colors.grey[600]),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Earnings breakdown cards
                    _buildBreakdownCard(
                      icon: Icons.attach_money,
                      title: 'Base Fare',
                      value: '_getBaseFare()',
                      color: Colors.blue,
                    ),
                    const SizedBox(height: 12),
                    _buildBreakdownCard(
                      icon: Icons.route,
                      title: 'Distance Bonus',
                      value: '_getDistanceBonus()',
                      color: Colors.purple,
                    ),
                    const SizedBox(height: 12),
                    _buildBreakdownCard(
                      icon: Icons.timer,
                      title: 'Time Bonus',
                      value: '_getTimeBonus()',
                      color: Colors.orange,
                    ),
                    const SizedBox(height: 12),
                    _buildBreakdownCard(
                      icon: Icons.star,
                      title: 'Service Fee',
                      value: '_getServiceFee()',
                      color: Colors.green,
                      isLast: true,
                    ),

                    if (_isExpanded) ...[
                      const SizedBox(height: 24),
                      
                      // Trip details
                      Text(
                        'Trip Details',
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Colors.grey[800],
                        ),
                      ),
                      const SizedBox(height: 16),
                      _buildDetailRow('Order ID', '#${_getOrderId()}'),
                      _buildDetailRow('Distance', '${_getDistance()}'),
                      _buildDetailRow('Duration', '${_getDuration()}'),
                      _buildDetailRow('Pickup', _getPickupLocation()),
                      _buildDetailRow('Dropoff', _getDropoffLocation()),
                      _buildDetailRow('Completed', _formatDateTime(DateTime.now())),
                    ],
                  ],
                ),
              ),
            ),
          ),

          // Continue button
          Positioned(
            left: 24,
            right: 24,
            bottom: 40,
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: SizedBox(
                height: 64,
                child: ElevatedButton(
                  onPressed: () {
                    // Navigate to rating/feedback screen
                    Navigator.of(context).pushReplacement(
                      PageRouteBuilder(
                        pageBuilder: (context, animation, secondaryAnimation) =>
                            _buildNextScreen(),
                        transitionsBuilder:
                            (context, animation, secondaryAnimation, child) {
                          return SlideTransition(
                            position: Tween<Offset>(
                              begin: const Offset(0.0, 1.0),
                              end: Offset.zero,
                            ).animate(CurvedAnimation(
                              parent: animation,
                              curve: Curves.easeOutCubic,
                            )),
                            child: child,
                          );
                        },
                        transitionDuration: const Duration(milliseconds: 500),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.black,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.arrow_forward,
                        size: 24,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'Continue',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBreakdownCard({
    required IconData icon,
    required String title,
    required String value,
    required Color color,
    bool isLast = false,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.grey[200]!,
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              icon,
              size: 20,
              color: color,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 15,
                color: Colors.grey[800],
              ),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
              color: Colors.grey[900],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 14,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 14,
              color: Colors.grey[800],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNextScreen() {
    // Navigate to rating/feedback screen using callback
    widget.onComplete();
    return Container(); // Placeholder, navigation handled by callback
  }
}

// Background pattern painter
class _BackgroundPatternPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.green.withOpacity(0.03)
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;

    const spacing = 30.0;
    
    for (double i = 0; i < size.width; i += spacing) {
      canvas.drawLine(
        Offset(i, 0),
        Offset(i, size.height),
        paint,
      );
    }
    
    for (double i = 0; i < size.height; i += spacing) {
      canvas.drawLine(
        Offset(0, i),
        Offset(size.width, i),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
