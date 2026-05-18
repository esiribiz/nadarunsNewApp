import 'package:flutter/material.dart';
import '../../../main/models/OrderListModel.dart';
import '../../../main/models/UserProfileDetailModel.dart';
import '../../../main/network/RestApis.dart';
import '../../../extensions/text_styles.dart';
import 'package:intl/intl.dart';

/// Single Trip Summary Screen
/// Displays details, earnings, and stats for the *just completed* trip only.
/// Replaces the old "Delivery Complete" summary before returning to the map.
class TripHistoryScreen extends StatefulWidget {
  final OrderData completedTrip;
  final double tripEarnings;
  final double? ratingGiven;

  const TripHistoryScreen({
    Key? key,
    required this.completedTrip,
    required this.tripEarnings,
    this.ratingGiven,
  }) : super(key: key);

  @override
  State<TripHistoryScreen> createState() => _TripHistoryScreenState();
}

class _TripHistoryScreenState extends State<TripHistoryScreen>
    with SingleTickerProviderStateMixin {
  bool _isLoading = true;
  UserProfileDetail? _userProfile;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _initAnimations();
    _loadTripDetails();
  }

  void _initAnimations() {
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.2),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _animationController, curve: Curves.easeOut));

    _animationController.forward();
  }

  Future<void> _loadTripDetails() async {
    setState(() => _isLoading = true);
    try {
      // Fetch latest profile to ensure wallet balance is up to date after this trip
      final profile = await RestApis.getUserProfile();
      if (mounted) {
        setState(() {
          _userProfile = profile;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        // Silently fail loading profile, still show trip data
      }
    }
  }

  void _handleBackToMap() {
    // Navigate back to the root/main map screen, clearing the delivery flow stack
    Navigator.of(context).pushNamedAndRemoveUntil('/home', (route) => false);
  }

  String _formatCurrency(double amount) {
    return NumberFormat.currency(symbol: '₦', decimalDigits: 2).format(amount);
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Background Gradient
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFF1A1A1A), Color(0xFF000000)],
              ),
            ),
          ),
          
          if (_isLoading)
            const Center(child: CircularProgressIndicator(color: Colors.white))
          else
            SafeArea(
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: SlideTransition(
                  position: _slideAnimation,
                  child: CustomScrollView(
                    slivers: [
                      // Success Header
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.all(24.0),
                          child: Column(
                            children: [
                              const Icon(
                                Icons.check_circle_outline,
                                color: Colors.green,
                                size: 64,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'Trip Completed!',
                                style: theme.textTheme.headlineSmall?.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'You earned ${_formatCurrency(widget.tripEarnings)}',
                                style: theme.textTheme.titleLarge?.copyWith(
                                  color: Colors.green.shade400,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      // Trip Details Card
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20.0),
                          child: _buildDetailCard(theme),
                        ),
                      ),

                      const SliverToBoxAdapter(
                        child: SizedBox(height: 30),
                      ),

                      // Back to Map Button
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20.0),
                          child: SizedBox(
                            width: double.infinity,
                            height: 56,
                            child: ElevatedButton.icon(
                              icon: const Icon(Icons.map, size: 24),
                              label: const Text(
                                'Back to Map',
                                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.white,
                                foregroundColor: Colors.black,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                elevation: 0,
                              ),
                              onPressed: _handleBackToMap,
                            ),
                          ),
                        ),
                      ),
                      
                      const SliverToBoxAdapter(
                        child: SizedBox(height: 40),
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

  Widget _buildDetailCard(ThemeData theme) {
    final trip = widget.completedTrip;
    
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF2C2C2C),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              color: Color(0xFF383838),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Trip #${trip.id ?? "N/A"}',
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: Colors.white70,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    'Completed',
                    style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
          
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Route Visualization
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildLocationRow(
                            Icons.location_on,
                            Colors.blue,
                            trip.pickupAddress ?? 'Pickup Location',
                            'Pickup',
                          ),
                          const SizedBox(height: 12),
                          const Icon(Icons.keyboard_arrow_down, color: Colors.grey, size: 20),
                          const SizedBox(height: 12),
                          _buildLocationRow(
                            Icons.flag,
                            Colors.orange,
                            trip.dropoffAddress ?? 'Dropoff Location',
                            'Dropoff',
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                
                const Divider(color: Colors.white24, height: 32),
                
                // Earnings Breakdown
                Text(
                  'Earnings Breakdown',
                  style: theme.textTheme.labelLarge?.copyWith(color: Colors.white70),
                ),
                const SizedBox(height: 12),
                _buildEarningRow('Base Fare', _formatCurrency(widget.tripEarnings * 0.7)),
                _buildEarningRow('Service Fee', _formatCurrency(widget.tripEarnings * 0.3)),
                const Divider(color: Colors.white24, height: 24),
                _buildEarningRow(
                  'Total Earned',
                  _formatCurrency(widget.tripEarnings),
                  isTotal: true,
                ),
                
                const SizedBox(height: 24),
                
                // Trip Stats
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildStatColumn('Distance', '${trip.distance?.toStringAsFixed(1) ?? '0'} km'),
                    _buildStatColumn('Duration', '24 min'),
                    _buildStatColumn('Items', '${trip.items?.length ?? 0}'),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLocationRow(IconData icon, Color color, String title, String label) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: color.withOpacity(0.2),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(color: Colors.grey, fontSize: 12),
              ),
              Text(
                title,
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildEarningRow(String label, String amount, {bool isTotal = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              color: isTotal ? Colors.white : Colors.white70,
              fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
              fontSize: isTotal ? 16 : 14,
            ),
          ),
          Text(
            amount,
            style: TextStyle(
              color: isTotal ? Colors.green : Colors.white,
              fontWeight: FontWeight.w600,
              fontSize: isTotal ? 18 : 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatColumn(String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(color: Colors.grey, fontSize: 12),
        ),
      ],
    );
  }
}
