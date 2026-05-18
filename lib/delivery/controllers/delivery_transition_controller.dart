import 'dart:async';
import 'package:flutter/material.dart';
import 'package:nadaruns_delivery/main/models/OrderListModel.dart';
import 'package:nadaruns_delivery/main/network/RestApis.dart';
import 'package:nadaruns_delivery/main/utils/Constants.dart';
import 'package:nadaruns_delivery/main.dart';
import 'package:nadaruns_delivery/delivery/screens/transition_screens/accept_order_screen.dart';
import 'package:nadaruns_delivery/delivery/screens/transition_screens/navigate_to_pickup_screen.dart';
import 'package:nadaruns_delivery/delivery/screens/transition_screens/en_route_pickup_screen.dart';
import 'package:nadaruns_delivery/delivery/screens/transition_screens/confirm_pickup_screen.dart';
import 'package:nadaruns_delivery/delivery/screens/transition_screens/en_route_dropoff_screen.dart';
import 'package:nadaruns_delivery/delivery/screens/transition_screens/arrived_dropoff_screen.dart';
import 'package:nadaruns_delivery/delivery/screens/transition_screens/earnings_summary_screen.dart';
import 'package:nadaruns_delivery/delivery/screens/transition_screens/rating_feedback_screen.dart';
import 'package:nadaruns_delivery/delivery/screens/transition_screens/trip_history_screen.dart';

/// Migration Controller for New Transition Screens
/// 
/// This controller acts as a bridge between the new modern UI screens
/// and the existing backend logic, services, and state management.
/// 
/// DO NOT modify backend logic - this is presentation layer only.
class DeliveryTransitionController {
  final BuildContext context;
  
  // Current order being processed
  OrderData? _currentOrder;
  
  // Stream subscription for real-time updates
  StreamSubscription? _orderStatusSubscription;
  
  DeliveryTransitionController({required this.context});

  /// Start the delivery flow from accepting an order
  /// This replaces the old accept/reject dialog
  Future<void> startAcceptOrderFlow(OrderData order) async {
    _currentOrder = order;
    
    final result = await Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => AcceptOrderScreen(
          order: order,
          onDecision: (accepted) {
            if (accepted) {
              _handleOrderAccepted(order);
            } else {
              _handleOrderRejected(order);
            }
          },
        ),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(
            opacity: animation,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0.0, 1.0),
                end: Offset.zero,
              ).animate(animation),
              child: child,
            ),
          );
        },
        transitionDuration: const Duration(milliseconds: 300),
      ),
    );
    
    return result;
  }

  /// Handle order acceptance - calls existing backend API
  Future<void> _handleOrderAccepted(OrderData order) async {
    try {
      appStore.setLoading(true);
      
      // Call new acceptOrder API which uses assign-order-update endpoint
      final response = await acceptOrder(
        orderId: order.id!,
        status: ORDER_ACCEPTED,
      );
      
      appStore.setLoading(false);
      
      if (response.success == true) {
        // Navigate to next screen in flow
        _navigateToPickupScreen(order);
      } else {
        throw Exception(response.message ?? 'Failed to accept order');
      }
      
    } catch (e) {
      appStore.setLoading(false);
      debugPrint('Error accepting order: $e');
      rethrow;
    }
  }

  /// Handle order rejection - uses existing cancellation logic
  Future<void> _handleOrderRejected(OrderData order) async {
    try {
      // TODO: Implement rejection logic using existing APIs
      // This may involve calling updateOrder with cancelled status
      // or a separate cancelOrder API
      
      Navigator.pop(context, {'action': 'rejected', 'orderId': order.id});
      
    } catch (e) {
      debugPrint('Error rejecting order: $e');
      rethrow;
    }
  }

  /// Navigate to Pickup Screen (Screen 2)
  Future<void> _navigateToPickupScreen(OrderData order) async {
    final result = await Navigator.pushReplacement(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => NavigateToPickupScreen(
          order: order,
          onStartNavigation: () => _startEnRouteToPickup(order),
        ),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(
            opacity: animation,
            child: child,
          );
        },
        transitionDuration: const Duration(milliseconds: 300),
      ),
    );
    
    return result;
  }

  /// Start en route to pickup (Screen 3)
  Future<void> _startEnRouteToPickup(OrderData order) async {
    final result = await Navigator.pushReplacement(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => EnRouteToPickupScreen(
          order: order,
          onArrivedAtPickup: () => _showArrivedAtPickupUI(order),
        ),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(
            opacity: animation,
            child: child,
          );
        },
        transitionDuration: const Duration(milliseconds: 300),
      ),
    );
    
    return result;
  }

  /// Show arrived at pickup UI and prepare for confirmation (Screen 4)
  Future<void> _showArrivedAtPickupUI(OrderData order) async {
    // Update order status to ARRIVED using existing API
    try {
      appStore.setLoading(true);
      await updateOrder(
        orderStatus: ORDER_ARRIVED,
        orderId: order.id!,
      );
      appStore.setLoading(false);
      
      // Navigate to confirm pickup screen
      _navigateToConfirmPickup(order);
      
    } catch (e) {
      appStore.setLoading(false);
      debugPrint('Error updating order to arrived: $e');
      rethrow;
    }
  }

  /// Navigate to Confirm Pickup Screen (Screen 4)
  Future<void> _navigateToConfirmPickup(OrderData order) async {
    final result = await Navigator.pushReplacement(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => ConfirmPickupScreen(
          order: order,
          onConfirmPickup: () => _handlePickupConfirmed(order),
        ),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(
            opacity: animation,
            child: child,
          );
        },
        transitionDuration: const Duration(milliseconds: 300),
      ),
    );
    
    return result;
  }

  /// Handle pickup confirmation - calls existing backend logic
  Future<void> _handlePickupConfirmed(OrderData order) async {
    try {
      appStore.setLoading(true);
      
      // Update to PICKED_UP status using existing API
      await updateOrder(
        orderStatus: ORDER_PICKED_UP,
        orderId: order.id!,
      );
      
      appStore.setLoading(false);
      
      // Navigate to en route to dropoff
      _navigateToDropoff(order);
      
    } catch (e) {
      appStore.setLoading(false);
      debugPrint('Error confirming pickup: $e');
      rethrow;
    }
  }

  /// Navigate to En Route to Dropoff Screen (Screen 5)
  Future<void> _navigateToDropoff(OrderData order) async {
    final result = await Navigator.pushReplacement(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => EnRouteDropoffScreen(
          order: order,
          onArrivedAtDropoff: () => _showArrivedAtDropoffUI(order),
        ),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(
            opacity: animation,
            child: child,
          );
        },
        transitionDuration: const Duration(milliseconds: 300),
      ),
    );
    
    return result;
  }

  /// Show arrived at dropoff UI (Screen 6)
  Future<void> _showArrivedAtDropoffUI(OrderData order) async {
    // Update to DEPARTED status using existing API
    try {
      appStore.setLoading(true);
      await updateOrder(
        orderStatus: ORDER_DEPARTED,
        orderId: order.id!,
      );
      appStore.setLoading(false);
      
      // Navigate to arrived at dropoff confirmation
      _navigateToArrivedDropoff(order);
      
    } catch (e) {
      appStore.setLoading(false);
      debugPrint('Error updating order to departed: $e');
      rethrow;
    }
  }

  /// Navigate to Arrived at Dropoff Screen (Screen 6)
  Future<void> _navigateToArrivedDropoff(OrderData order) async {
    final result = await Navigator.pushReplacement(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => ArrivedDropoffScreen(
          order: order,
          onConfirmDelivery: () => _handleDeliveryConfirmed(order),
        ),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(
            opacity: animation,
            child: child,
          );
        },
        transitionDuration: const Duration(milliseconds: 300),
      ),
    );
    
    return result;
  }

  /// Handle delivery confirmation - calls existing backend logic
  Future<void> _handleDeliveryConfirmed(OrderData order) async {
    try {
      appStore.setLoading(true);
      
      // Update to DELIVERED status using existing API
      await updateOrder(
        orderStatus: ORDER_DELIVERED,
        orderId: order.id!,
      );
      
      appStore.setLoading(false);
      
      // Navigate to earnings summary
      _navigateToEarningsSummary(order);
      
    } catch (e) {
      appStore.setLoading(false);
      debugPrint('Error confirming delivery: $e');
      rethrow;
    }
  }

  /// Navigate to Earnings Summary Screen (Screen 7)
  Future<void> _navigateToEarningsSummary(OrderData order) async {
    final result = await Navigator.pushReplacement(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => EarningsSummaryScreen(
          order: order,
          onComplete: () => _navigateToRating(order),
        ),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(
            opacity: animation,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0.0, 1.0),
                end: Offset.zero,
              ).animate(animation),
              child: child,
            ),
          );
        },
        transitionDuration: const Duration(milliseconds: 300),
      ),
    );
    
    return result;
  }

  /// Navigate to Rating & Feedback Screen (Screen 8)
  Future<void> _navigateToRating(OrderData order) async {
    final result = await Navigator.pushReplacement(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => RatingFeedbackScreen(
          order: order,
          onSubmitRating: (rating, feedback) => _handleRatingSubmitted(order, rating, feedback),
        ),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(
            opacity: animation,
            child: child,
          );
        },
        transitionDuration: const Duration(milliseconds: 300),
      ),
    );
    
    return result;
  }

  /// Handle rating submission - uses existing rating API
  Future<void> _handleRatingSubmitted(OrderData order, double rating, String feedback) async {
    try {
      appStore.setLoading(true);
      
      // TODO: Call existing rating submission API
      // This would be similar to submitRating(tripId, rating, feedback)
      // For now, we'll just complete the flow
      
      appStore.setLoading(false);
      
      // Navigate to trip history
      _navigateToTripHistory();
      
    } catch (e) {
      appStore.setLoading(false);
      debugPrint('Error submitting rating: $e');
      rethrow;
    }
  }

  /// Navigate to Trip History Screen (Screen 9)
  Future<void> _navigateToTripHistory() async {
    await Navigator.pushReplacement(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => const TripHistoryScreen(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(
            opacity: animation,
            child: child,
          );
        },
        transitionDuration: const Duration(milliseconds: 300),
      ),
    );
  }

  /// Subscribe to real-time order status updates
  void subscribeToOrderUpdates(String orderId) {
    // Use existing Firestore listeners from DeliveryDashBoard
    // This maintains real-time behavior without changing backend logic
    _orderStatusSubscription = null; // Placeholder - will use existing implementation
    
    // TODO: Integrate with existing socket/Firestore listeners
    // from DeliveryDashBoard for real-time updates
  }

  /// Unsubscribe from order updates
  void unsubscribeFromOrderUpdates() {
    _orderStatusSubscription?.cancel();
  }

  /// Dispose controller resources
  void dispose() {
    unsubscribeFromOrderUpdates();
  }

  /// Get current order
  OrderData? getCurrentOrder() => _currentOrder;

  /// Set current order (for integration with existing flows)
  void setCurrentOrder(OrderData order) {
    _currentOrder = order;
  }
}
