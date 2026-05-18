import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../extensions/decorations.dart';
import '../../extensions/extension_util/int_extensions.dart';
import '../../extensions/extension_util/string_extensions.dart';
import '../../extensions/extension_util/widget_extensions.dart';
import '../../extensions/text_styles.dart';
import '../../main.dart';
import '../../main/components/CommonScaffoldComponent.dart';
import '../../main/models/OrderDetailModel.dart';
import '../../main/models/OrderListModel.dart';
import '../../main/network/RestApis.dart';
import '../../main/utils/Common.dart';
import '../../main/utils/Constants.dart';
import '../../main/utils/dynamic_theme.dart';
import '../components/DriverDesignSystem.dart';

class DriverTrackingScreen extends StatefulWidget {
  static String tag = '/DriverTrackingScreen';

  final OrderData orderData;

  DriverTrackingScreen({required this.orderData});

  @override
  DriverTrackingScreenState createState() => DriverTrackingScreenState();
}

class DriverTrackingScreenState extends State<DriverTrackingScreen> {
  Timer? timer;
  bool _isRefreshing = false;

  List<Marker> markers = [];
  Set<Polyline> _polylines = {};
  List<LatLng> polylineCoordinates = [];

  LatLng? sourceLocation;
  LatLng? destinationLocation;

  static const MarkerId _driverMarkerId = MarkerId('DriverLocation');
  static const MarkerId _pickupMarkerId = MarkerId('OrderPickup');
  static const MarkerId _dropoffMarkerId = MarkerId('OrderDropOff');

  OrderData? liveOrderData;
  List<OrderHistory> liveOrderHistory = [];

  String _latestStatusMessage = '';
  DateTime? _latestStatusTimestamp;
  int? _latestHistoryId;

  final List<String> _driverFlowStages = [
    ORDER_PENDING,
    ORDER_ASSIGNED,
    ORDER_ACCEPTED,
    ORDER_ARRIVED,
    ORDER_PICKED_UP,
    ORDER_DEPARTED,
    ORDER_DELIVERED,
  ];

  @override
  void initState() {
    super.initState();
    liveOrderData = widget.orderData;
    _latestStatusMessage = _statusMessageFor(
      widget.orderData.status.validate(),
    );
    _latestStatusTimestamp = DateTime.now();
    init();
  }

  Future<void> init() async {
    await _refreshTrackingData(isInitial: true);
    timer = Timer.periodic(
      const Duration(seconds: 4),
      (Timer t) => _refreshTrackingData(),
    );
  }

  bool _isPickupStage(String? status) {
    return status == ORDER_PENDING ||
        status == ORDER_ASSIGNED ||
        status == ORDER_ACCEPTED ||
        status == ORDER_ARRIVED;
  }

  bool _isTerminalStatus(String? status) {
    return status == ORDER_DELIVERED ||
        status == ORDER_CANCELLED ||
        status == ORDER_FAIL;
  }

  double? _toCoordinate(dynamic value) {
    if (value == null) return null;
    return double.tryParse(value.toString());
  }

  LatLng? _pointFromStop(PickupPoint? point) {
    final double? latitude = _toCoordinate(point?.latitude);
    final double? longitude = _toCoordinate(point?.longitude);
    if (latitude == null || longitude == null) return null;
    return LatLng(latitude, longitude);
  }

  LatLng? _resolveDestinationLocation(OrderData order) {
    if (_isPickupStage(order.status.validate())) {
      return _pointFromStop(order.pickupPoint) ??
          _pointFromStop(order.deliveryPoint);
    }
    return _pointFromStop(order.deliveryPoint) ??
        _pointFromStop(order.pickupPoint);
  }

  DateTime _parseDate(String? dateTime) {
    if (dateTime.isEmptyOrNull) return DateTime.fromMillisecondsSinceEpoch(0);
    return DateTime.tryParse(dateTime.validate())?.toLocal() ??
        DateTime.fromMillisecondsSinceEpoch(0);
  }

  String _formatTime(DateTime dateTime) {
    int hour = dateTime.hour % 12;
    if (hour == 0) hour = 12;
    String minute = dateTime.minute.toString().padLeft(2, '0');
    String period = dateTime.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $period';
  }

  Color _statusColor(String status) {
    switch (status) {
      case ORDER_PENDING:
        return const Color(0xFFF59E0B);
      case ORDER_ASSIGNED:
        return const Color(0xFF8B5CF6);
      case ORDER_ACCEPTED:
        return const Color(0xFF2563EB);
      case ORDER_ARRIVED:
        return const Color(0xFF0EA5E9);
      case ORDER_PICKED_UP:
        return const Color(0xFF06B6D4);
      case ORDER_DEPARTED:
        return const Color(0xFF4F46E5);
      case ORDER_DELIVERED:
        return const Color(0xFF10B981);
      case ORDER_CANCELLED:
      case ORDER_FAIL:
        return const Color(0xFFEF4444);
      default:
        return DriverPalette.primary;
    }
  }

  OrderHistory? _latestHistoryEntry() {
    if (liveOrderHistory.isEmpty) return null;
    List<OrderHistory> history = [...liveOrderHistory];
    history.sort(
      (a, b) => _parseDate(a.createdAt).compareTo(_parseDate(b.createdAt)),
    );
    return history.last;
  }

  String _statusMessageFor(String status, {String? fallbackMessage}) {
    String historyMessage = fallbackMessage.validate().trim();
    if (historyMessage.isNotEmpty) return historyMessage;

    switch (status) {
      case ORDER_PENDING:
        return 'Order is pending. Waiting for assignment.';
      case ORDER_ASSIGNED:
        return 'Order has been assigned to you.';
      case ORDER_ACCEPTED:
        return 'You have accepted this order. Head to pickup location.';
      case ORDER_ARRIVED:
        return 'You have arrived at pickup location.';
      case ORDER_PICKED_UP:
        return 'Parcel picked up successfully. Ready for delivery.';
      case ORDER_DEPARTED:
        return 'On the way to drop-off location.';
      case ORDER_DELIVERED:
        return 'Delivery completed successfully.';
      case ORDER_CANCELLED:
        return 'This order was cancelled.';
      case ORDER_FAIL:
        return 'This order could not be completed.';
      default:
        return 'Tracking update available.';
    }
  }

  String _flowLabel(String status) {
    switch (status) {
      case ORDER_PENDING:
        return 'Pending';
      case ORDER_ASSIGNED:
        return 'Assigned';
      case ORDER_ACCEPTED:
        return 'Accepted';
      case ORDER_ARRIVED:
        return 'At Pickup';
      case ORDER_PICKED_UP:
        return 'Picked Up';
      case ORDER_DEPARTED:
        return 'In Transit';
      case ORDER_DELIVERED:
        return 'Delivered';
      default:
        return orderStatus(status);
    }
  }

  IconData _flowIcon(String status) {
    switch (status) {
      case ORDER_PENDING:
        return Icons.search_outlined;
      case ORDER_ASSIGNED:
        return Icons.assignment_ind_outlined;
      case ORDER_ACCEPTED:
        return Icons.check_circle_outline;
      case ORDER_ARRIVED:
        return Icons.place_outlined;
      case ORDER_PICKED_UP:
        return Icons.inventory_2_outlined;
      case ORDER_DEPARTED:
        return Icons.local_shipping_outlined;
      case ORDER_DELIVERED:
        return Icons.task_alt_outlined;
      default:
        return Icons.radio_button_checked;
    }
  }

  int _flowIndex(String status) {
    int index = _driverFlowStages.indexOf(status);
    if (index != -1) return index;

    int historyIndex = -1;
    for (int i = 0; i < _driverFlowStages.length; i++) {
      if (liveOrderHistory.any(
        (history) => history.historyType.validate() == _driverFlowStages[i],
      )) {
        historyIndex = i;
      }
    }
    return historyIndex >= 0 ? historyIndex : 0;
  }

  void _applyStatusNotification({
    required String previousStatus,
    required String newStatus,
    required bool isInitial,
  }) {
    OrderHistory? latestHistory = _latestHistoryEntry();
    int? latestHistoryId = latestHistory?.id;

    _latestStatusMessage = _statusMessageFor(
      newStatus,
      fallbackMessage: latestHistory?.historyMessage,
    );
    _latestStatusTimestamp = latestHistory?.createdAt.isEmptyOrNull ?? true
        ? DateTime.now()
        : _parseDate(latestHistory!.createdAt);

    bool statusChanged =
        previousStatus.isNotEmpty && previousStatus != newStatus;
    bool historyChanged =
        latestHistoryId != null && latestHistoryId != _latestHistoryId;

    if (latestHistoryId != null) _latestHistoryId = latestHistoryId;

    if (!isInitial && (statusChanged || historyChanged) && mounted) {
      ScaffoldMessengerState? messenger = ScaffoldMessenger.maybeOf(context);
      messenger?.hideCurrentSnackBar();
      messenger?.showSnackBar(
        SnackBar(
          content: Text(_latestStatusMessage),
          duration: const Duration(seconds: 3),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _refreshTrackingData({bool isInitial = false}) async {
    if (_isRefreshing) return;
    _isRefreshing = true;

    if (isInitial) appStore.setLoading(true);

    try {
      final int orderId =
          liveOrderData?.id.validate() ?? widget.orderData.id.validate();
      final String previousStatus = liveOrderData?.status.validate() ?? '';

      final OrderDetailModel details = await getOrderDetails(orderId);
      final OrderData updatedOrder =
          details.data ?? liveOrderData ?? widget.orderData;

      liveOrderData = updatedOrder;
      liveOrderHistory = details.orderHistory ?? [];

      _applyStatusNotification(
        previousStatus: previousStatus,
        newStatus: updatedOrder.status.validate(),
        isInitial: isInitial,
      );

      await _refreshMapData(updatedOrder);

      if (_isTerminalStatus(updatedOrder.status.validate())) {
        timer?.cancel();
      }
    } catch (error) {
      debugPrint(error.toString());
    } finally {
      appStore.setLoading(false);
      _isRefreshing = false;
      setState(() {});
    }
  }

  Future<void> _refreshMapData(OrderData order) async {
    markers.clear();
    _polylines.clear();
    polylineCoordinates.clear();

    LatLng? pickupLocation = _pointFromStop(order.pickupPoint);
    LatLng? dropoffLocation = _pointFromStop(order.deliveryPoint);
    destinationLocation = _resolveDestinationLocation(order);
    sourceLocation = null;

    if (pickupLocation != null) {
      markers.add(
        Marker(
          markerId: _pickupMarkerId,
          position: pickupLocation,
          infoWindow: InfoWindow(
            title: 'Pickup',
            snippet: order.pickupPoint?.address.validate(),
          ),
          icon: await getOriginMarkerIcon(),
        ),
      );
    }

    if (dropoffLocation != null) {
      markers.add(
        Marker(
          markerId: _dropoffMarkerId,
          position: dropoffLocation,
          infoWindow: InfoWindow(
            title: 'Drop-off',
            snippet: order.deliveryPoint?.address.validate(),
          ),
          icon: await getDestinationMarkerIcon(),
        ),
      );
    }

    sourceLocation = pickupLocation ?? dropoffLocation;

    if (sourceLocation != null && destinationLocation != null) {
      bool samePoint =
          sourceLocation!.latitude == destinationLocation!.latitude &&
          sourceLocation!.longitude == destinationLocation!.longitude;
      if (!samePoint) {
        await setPolyLines(deliveryLatLng: sourceLocation!);
      }
    }
  }

  Future<void> setPolyLines({required LatLng deliveryLatLng}) async {
    if (destinationLocation == null) return;

    _polylines.clear();
    polylineCoordinates.clear();

    String origins = '${deliveryLatLng.latitude},${deliveryLatLng.longitude}';
    String destinations =
        '${destinationLocation!.latitude},${destinationLocation!.longitude}';

    await getPolylineData(origins, destinations).then((value) async {
      if (value.status == true && value.polyline != null) {
        final points = decodePolyline(value.polyline!);
        if (points.isNotEmpty) {
          polylineCoordinates.addAll(points);
          _polylines.add(
            Polyline(
              visible: true,
              width: 5,
              polylineId: const PolylineId('poly'),
              color: const Color.fromARGB(255, 40, 122, 198),
              points: polylineCoordinates,
            ),
          );
        }
      }
    });
  }

  Widget _buildFlowTimelineCard(OrderData activeOrder) {
    int currentIndex = _flowIndex(activeOrder.status.validate());
    bool isTerminal = _isTerminalStatus(activeOrder.status.validate());

    return Container(
      decoration: boxDecorationWithRoundedCorners(
        borderRadius: BorderRadius.circular(16),
        backgroundColor: Colors.white,
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('Job Flow', style: boldTextStyle(size: 14)),
              const Spacer(),
              Text(
                isTerminal ? 'Final status' : 'Live',
                style: secondaryTextStyle(size: 11),
              ),
            ],
          ),
          10.height,
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: List.generate(_driverFlowStages.length, (index) {
                String stage = _driverFlowStages[index];
                return Row(
                  children: [
                    _buildFlowStep(
                      stage: stage,
                      stageIndex: index,
                      currentIndex: currentIndex,
                    ),
                    if (index != _driverFlowStages.length - 1)
                      Container(
                        width: 20,
                        height: 2,
                        margin: const EdgeInsets.only(bottom: 24),
                        color: currentIndex > index
                            ? _statusColor(_driverFlowStages[index + 1])
                            : const Color(0xFFCBD5E1),
                      ),
                  ],
                );
              }),
            ),
          ),
          10.height,
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: DriverPalette.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.info_outline,
                  size: 16,
                  color: DriverPalette.primary,
                ),
                8.width,
                Expanded(
                  child: Text(
                    _latestStatusMessage,
                    style: primaryTextStyle(size: 12),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFlowStep({
    required String stage,
    required int stageIndex,
    required int currentIndex,
  }) {
    bool isCompleted = currentIndex >= stageIndex;
    bool isCurrent = currentIndex == stageIndex;
    Color color = isCompleted ? _statusColor(stage) : const Color(0xFF94A3B8);

    return Column(
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            color: isCompleted
                ? color.withValues(alpha: isCurrent ? 0.22 : 0.15)
                : const Color(0xFFF1F5F9),
            shape: BoxShape.circle,
            border: Border.all(
              color: isCompleted ? color : const Color(0xFFCBD5E1),
            ),
          ),
          child: Icon(_flowIcon(stage), size: 16, color: color),
        ),
        6.height,
        SizedBox(
          width: 68,
          child: Text(
            _flowLabel(stage),
            textAlign: TextAlign.center,
            style: primaryTextStyle(
              size: 10,
              color: isCompleted ? color : const Color(0xFF64748B),
              weight: isCurrent ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }

  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }

  @override
  void setState(fn) {
    if (mounted) super.setState(fn);
  }

  @override
  Widget build(BuildContext context) {
    final OrderData activeOrder = liveOrderData ?? widget.orderData;
    final LatLng? fallbackPickup = _pointFromStop(activeOrder.pickupPoint);
    final LatLng? fallbackDropoff = _pointFromStop(activeOrder.deliveryPoint);
    final LatLng? mapTarget =
        sourceLocation ??
        destinationLocation ??
        fallbackPickup ??
        fallbackDropoff;

    return CommonScaffoldComponent(
      appBarTitle: language.trackOrder,
      body: Stack(
        children: [
          if (mapTarget != null)
            GoogleMap(
              markers: markers.map((e) => e).toSet(),
              polylines: _polylines,
              mapType: MapType.normal,
              initialCameraPosition: CameraPosition(
                target: mapTarget,
                zoom: 13,
              ),
            )
          else
            Center(
              child: Text(
                'Tracking map will appear once location data is available.',
                style: secondaryTextStyle(),
                textAlign: TextAlign.center,
              ),
            ),
          Positioned(
            top: 12,
            left: 12,
            right: 12,
            child: _buildFlowTimelineCard(activeOrder),
          ),
        ],
      ),
    );
  }
}
