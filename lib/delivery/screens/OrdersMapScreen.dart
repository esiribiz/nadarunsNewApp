import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../extensions/extension_util/int_extensions.dart';
import '../../extensions/extension_util/string_extensions.dart';
import '../../extensions/extension_util/widget_extensions.dart';
import '../../extensions/common.dart';
import '../../extensions/shared_pref.dart';
import '../../extensions/text_styles.dart';
import '../components/DriverDesignSystem.dart';
import '../../main.dart';
import '../../main/utils/Constants.dart';
import '../../main/utils/Images.dart';
import '../../main/utils/Widgets.dart';
import '../../main/network/RestApis.dart';
import '../../main/models/OrderListModel.dart';
import '../../main/models/OrdersLatLngResponseList.dart' as map_order;
import '../../main/utils/Common.dart';
import 'ReceivedScreenOrderScreen.dart';

class OrdersMapScreen extends StatefulWidget {
  final bool showOnlyAvailable;
  final double initialRangeKm;

  const OrdersMapScreen({
    super.key,
    this.showOnlyAvailable = true,
    this.initialRangeKm = 50,
  });

  @override
  State<OrdersMapScreen> createState() => _OrdersMapScreenState();
}

class _OrdersMapScreenState extends State<OrdersMapScreen> {
  List<Marker> markers = [];
  GoogleMapController? googleMapController;
  Set<Polyline> _polylines = {};
  List<LatLng> polylineCoordinates = [];
  List<LatLng> assignedOrders = [];
  List<LatLng> acceptedOrders = [];
  BitmapDescriptor? assignedMarkerIcon;
  BitmapDescriptor? acceptedMarkerIcon;
  final Map<int, BitmapDescriptor> _availableCountMarkerIcons = {};
  bool _isInfoWindowVisible = false;
  MapOrderInfoWindow? selectedInfoWindow;
  List<MapOrderInfoWindow> infoWindowItems = [];
  Position? driverPosition;
  late double maxRangeKm;
  final List<double> rangeOptions = [10, 25, 50, 100];
  Timer? _autoRefreshTimer;
  bool _isFetchingMapOrders = false;
  bool _isOpeningOngoingJob = false;
  bool _isAcceptingAvailableJob = false;
  LatLng? _tripRouteOrigin;
  LatLng? _tripRouteDestination;
  String? _tripRouteOriginLabel;
  String? _tripRouteDestinationLabel;

  bool get _hasTripRouteFilter =>
      _tripRouteOrigin != null && _tripRouteDestination != null;

  void onMapCreated(GoogleMapController controller) async {
    setState(() {
      googleMapController = controller;
    });
  }

  void _startAutoRefresh() {
    _autoRefreshTimer?.cancel();
    _autoRefreshTimer = Timer.periodic(const Duration(seconds: 4), (timer) {
      if (!mounted) return;
      getLatLngOfOrdersApi();
    });
  }

  @override
  void initState() {
    super.initState();
    maxRangeKm = widget.initialRangeKm;
    initializeMapData();
    _startAutoRefresh();
  }

  Future<void> initializeMapData() async {
    await setMarkerIcons();
    await getLatLngOfOrdersApi(showLoader: true);
  }

  setMarkerIcons() async {
    assignedMarkerIcon = await createMarkerIconFromAsset(ic_assigned_marker);
    acceptedMarkerIcon = await createMarkerIconFromAsset(ic_accepted_marker);
  }

  Future<Position?> getDriverCurrentPosition() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return null;

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever)
        return null;

      return await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
    } catch (e) {
      return null;
    }
  }

  double? safeCoordinate(dynamic value) {
    if (value == null) return null;
    return double.tryParse(value.toString());
  }

  double extractTotalDistance(dynamic element) {
    final dynamic distanceValue = element is OrderData
        ? element.totalDistance
        : element is map_order.Data
        ? element.totalDistance
        : null;
    final double? parsedDistance = safeCoordinate(distanceValue);
    return parsedDistance != null && parsedDistance > 0 ? parsedDistance : 0;
  }

  double _bearingBetweenPoints(LatLng from, LatLng to) {
    final double fromLat = from.latitude * (math.pi / 180);
    final double fromLng = from.longitude * (math.pi / 180);
    final double toLat = to.latitude * (math.pi / 180);
    final double toLng = to.longitude * (math.pi / 180);

    final double deltaLng = toLng - fromLng;
    final double y = math.sin(deltaLng) * math.cos(toLat);
    final double x =
        math.cos(fromLat) * math.sin(toLat) -
        math.sin(fromLat) * math.cos(toLat) * math.cos(deltaLng);
    final double bearing = math.atan2(y, x) * (180 / math.pi);
    return (bearing + 360) % 360;
  }

  double _bearingDelta(double a, double b) {
    final double diff = (a - b).abs() % 360;
    return diff > 180 ? 360 - diff : diff;
  }

  Future<LatLng?> _geocodeAddressPoint(String address) async {
    final String query = address.trim();
    if (query.isEmpty) return null;
    final List<Location> points = await locationFromAddress(query);
    if (points.isEmpty) return null;
    return LatLng(points.first.latitude, points.first.longitude);
  }

  Future<void> _openTripRouteFilterDialog() async {
    final String defaultOrigin = _tripRouteOriginLabel.validate().isNotEmpty
        ? _tripRouteOriginLabel.validate()
        : 'Current location';
    final TextEditingController originController = TextEditingController(
      text: defaultOrigin,
    );
    final TextEditingController destinationController = TextEditingController(
      text: _tripRouteDestinationLabel.validate(),
    );

    final Map<String, String>? routeInput =
        await showDialog<Map<String, String>>(
          context: context,
          builder: (dialogContext) {
            return AlertDialog(
              title: const Text('Trip itinerary'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: originController,
                    decoration: const InputDecoration(
                      hintText: 'From city/place',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: destinationController,
                    decoration: const InputDecoration(
                      hintText: 'To city/place',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: Text(language.cancel),
                ),
                TextButton(
                  onPressed: () {
                    Navigator.pop(dialogContext, <String, String>{
                      'from': originController.text.trim(),
                      'to': destinationController.text.trim(),
                    });
                  },
                  child: const Text('Apply'),
                ),
              ],
            );
          },
        );

    if (routeInput == null) return;
    final String fromText = routeInput['from'].validate();
    final String toText = routeInput['to'].validate();
    if (fromText.isEmpty || toText.isEmpty) {
      toast('Please enter both start and destination');
      return;
    }

    appStore.setLoading(true);
    try {
      final LatLng? origin = await _geocodeAddressPoint(fromText);
      final LatLng? destination = await _geocodeAddressPoint(toText);
      if (origin == null || destination == null) {
        toast('Unable to locate this route. Try a more specific place name.');
        return;
      }

      setState(() {
        _tripRouteOrigin = origin;
        _tripRouteDestination = destination;
        _tripRouteOriginLabel = fromText;
        _tripRouteDestinationLabel = toText;
      });
      await getLatLngOfOrdersApi(showLoader: true);
    } catch (e) {
      toast(e.toString());
    } finally {
      appStore.setLoading(false);
    }
  }

  void _clearTripRouteFilter() {
    setState(() {
      _tripRouteOrigin = null;
      _tripRouteDestination = null;
      _tripRouteOriginLabel = null;
      _tripRouteDestinationLabel = null;
    });
  }

  bool _matchesTripRouteForElement(dynamic element) {
    if (!_hasTripRouteFilter) return true;

    final double? pickupLat = extractPickupLatitude(element);
    final double? pickupLng = extractPickupLongitude(element);
    final double? deliveryLat = extractDeliveryLatitude(element);
    final double? deliveryLng = extractDeliveryLongitude(element);
    if (pickupLat == null ||
        pickupLng == null ||
        deliveryLat == null ||
        deliveryLng == null) {
      return false;
    }

    final LatLng origin = _tripRouteOrigin!;
    final LatLng destination = _tripRouteDestination!;
    final LatLng pickup = LatLng(pickupLat, pickupLng);
    final LatLng delivery = LatLng(deliveryLat, deliveryLng);

    final double tripBearing = _bearingBetweenPoints(origin, destination);
    final double orderBearing = _bearingBetweenPoints(pickup, delivery);
    if (_bearingDelta(tripBearing, orderBearing) > 75) return false;

    final double pickupToDestinationKm =
        Geolocator.distanceBetween(
          pickup.latitude,
          pickup.longitude,
          destination.latitude,
          destination.longitude,
        ) /
        1000;
    final double deliveryToDestinationKm =
        Geolocator.distanceBetween(
          delivery.latitude,
          delivery.longitude,
          destination.latitude,
          destination.longitude,
        ) /
        1000;
    if (deliveryToDestinationKm + 0.75 > pickupToDestinationKm) return false;

    final double tripLengthKm =
        Geolocator.distanceBetween(
          origin.latitude,
          origin.longitude,
          destination.latitude,
          destination.longitude,
        ) /
        1000;
    final double pickupToOriginKm =
        Geolocator.distanceBetween(
          pickup.latitude,
          pickup.longitude,
          origin.latitude,
          origin.longitude,
        ) /
        1000;
    final double maxPickupDistanceKm = math.max(35.0, tripLengthKm * 1.4);
    return pickupToOriginKm <= maxPickupDistanceKm;
  }

  String _distanceLabel(double value) {
    if (value <= 0) return 'Distance unavailable';
    return '${value.toStringAsFixed(value >= 10 ? 0 : 1)} km';
  }

  Future<void> _acceptAvailableJob(MapOrderInfoWindow info) async {
    final int? orderId = info.orderId;
    if (orderId == null || _isAcceptingAvailableJob) return;

    setState(() {
      _isAcceptingAvailableJob = true;
    });
    appStore.setLoading(true);
    try {
      final String status = info.status.validate();
      if (status == ORDER_ASSIGNED) {
        await updateOrder(orderStatus: ORDER_ACCEPTED, orderId: orderId);
      } else {
        final value = await updateOrderStatusForAssignedTab({
          'order_id': orderId,
          'status': ORDER_ASSIGNED,
        });
        if (value.success == false) {
          throw value.message.validate().isNotEmpty
              ? value.message.validate()
              : 'Unable to accept this job right now';
        }
      }
      toast('Job accepted successfully');
      _isInfoWindowVisible = false;
      selectedInfoWindow = null;
      await getLatLngOfOrdersApi(showLoader: true);
    } catch (e) {
      toast(e.toString());
    } finally {
      appStore.setLoading(false);
      if (mounted) {
        setState(() {
          _isAcceptingAvailableJob = false;
        });
      }
    }
  }

  int? extractOrderId(dynamic element) {
    if (element is OrderData) return element.id;
    if (element is map_order.Data) return element.id;
    return null;
  }

  String extractStatus(dynamic element) {
    if (element is OrderData) return element.status.validate();
    if (element is map_order.Data) return element.status.validate();
    return '';
  }

  String? extractOrderTrackingId(dynamic element) {
    if (element is OrderData) return element.orderTrackingId;
    if (element is map_order.Data) return element.orderTrackingId;
    return null;
  }

  String? extractParcelType(dynamic element) {
    if (element is OrderData) return element.parcelType;
    if (element is map_order.Data) return element.parcelType;
    return null;
  }

  String? extractClientName(dynamic element) {
    if (element is OrderData) return element.clientName;
    if (element is map_order.Data) return element.clientName;
    return null;
  }

  String buildJobTitle(dynamic element, int orderId) {
    final String parcelType = extractParcelType(element).validate();
    if (parcelType.isNotEmpty) return parcelType;

    final String trackingId = extractOrderTrackingId(element).validate();
    if (trackingId.isNotEmpty) return trackingId;

    final String clientName = extractClientName(element).validate();
    if (clientName.isNotEmpty) return '$clientName delivery request';

    return 'Job #$orderId';
  }

  int? extractDeliveryManId(dynamic element) {
    if (element is OrderData) return element.deliveryManId;
    if (element is map_order.Data) return element.deliveryManId;
    return null;
  }

  List<dynamic> extractCancelledIds(dynamic element) {
    dynamic rawValue;
    if (element is OrderData) {
      rawValue = element.cancelledDeliverManIds;
    } else if (element is map_order.Data) {
      rawValue = element.cancelledDeliverManIds;
    }

    if (rawValue == null) return [];
    if (rawValue is List) return rawValue;

    if (rawValue is String) {
      final trimmed = rawValue.trim();
      if (trimmed.isEmpty) return [];
      try {
        final decoded = jsonDecode(trimmed);
        if (decoded is List) return decoded;
      } catch (_) {}
      return trimmed
          .split(',')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();
    }

    return [];
  }

  dynamic extractPickupPoint(dynamic element) {
    if (element is OrderData) return element.pickupPoint;
    if (element is map_order.Data) return element.pickupPoint;
    return null;
  }

  dynamic extractDeliveryPoint(dynamic element) {
    if (element is OrderData) return element.deliveryPoint;
    if (element is map_order.Data) return element.deliveryPoint;
    return null;
  }

  double? extractPickupLatitude(dynamic element) {
    return safeCoordinate(extractPickupPoint(element)?.latitude);
  }

  double? extractPickupLongitude(dynamic element) {
    return safeCoordinate(extractPickupPoint(element)?.longitude);
  }

  String? extractPickupAddress(dynamic element) {
    return extractPickupPoint(element)?.address;
  }

  String? extractPickupStartTime(dynamic element) {
    return extractPickupPoint(element)?.startTime;
  }

  String? extractPickupEndTime(dynamic element) {
    return extractPickupPoint(element)?.endTime;
  }

  double? extractDeliveryLatitude(dynamic element) {
    return safeCoordinate(extractDeliveryPoint(element)?.latitude);
  }

  double? extractDeliveryLongitude(dynamic element) {
    return safeCoordinate(extractDeliveryPoint(element)?.longitude);
  }

  String? extractDeliveryAddress(dynamic element) {
    return extractDeliveryPoint(element)?.address;
  }

  String? extractDeliveryStartTime(dynamic element) {
    return extractDeliveryPoint(element)?.startTime;
  }

  String? extractDeliveryEndTime(dynamic element) {
    return extractDeliveryPoint(element)?.endTime;
  }

  bool isAvailableOrderForMap(dynamic element) {
    final status = extractStatus(element);
    if (status == ORDER_CREATED || status == ORDER_PENDING) return true;
    if (status == ORDER_ASSIGNED) {
      final int? deliveryManId = extractDeliveryManId(element);
      return deliveryManId == null ||
          deliveryManId == 0 ||
          deliveryManId == getIntAsync(USER_ID);
    }
    return false;
  }

  bool isOrderCancelledForCurrentDriver(dynamic element) {
    final List<dynamic> cancelledIds = extractCancelledIds(element);
    if (cancelledIds.isEmpty) return false;
    final String currentDriverId = getIntAsync(USER_ID).toString();
    return cancelledIds.any((e) => e.toString() == currentDriverId);
  }

  bool isWithinSelectedRange(double latitude, double longitude) {
    if (driverPosition == null) return true;
    final double distanceInKm =
        Geolocator.distanceBetween(
          driverPosition!.latitude,
          driverPosition!.longitude,
          latitude,
          longitude,
        ) /
        1000;
    return distanceInKm <= maxRangeKm;
  }

  String _locationGroupingKey(double latitude, double longitude) {
    return '${latitude.toStringAsFixed(6)},${longitude.toStringAsFixed(6)}';
  }

  Future<BitmapDescriptor> _buildAvailableMarkerIcon(int count) async {
    if (_availableCountMarkerIcons.containsKey(count)) {
      return _availableCountMarkerIcons[count]!;
    }

    const double markerWidth = 96;
    const double markerHeight = 118;
    const Offset bubbleCenter = Offset(markerWidth / 2, 40);
    const double bubbleRadius = 24;

    final ui.PictureRecorder pictureRecorder = ui.PictureRecorder();
    final Canvas canvas = Canvas(pictureRecorder);

    final Paint bubblePaint = Paint()..color = DriverPalette.primary;
    final Paint borderPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4;

    final Path pinPath = Path()
      ..moveTo(bubbleCenter.dx - 10, bubbleCenter.dy + bubbleRadius - 2)
      ..lineTo(bubbleCenter.dx, markerHeight - 10)
      ..lineTo(bubbleCenter.dx + 10, bubbleCenter.dy + bubbleRadius - 2)
      ..close();

    canvas.drawCircle(bubbleCenter, bubbleRadius, bubblePaint);
    canvas.drawPath(pinPath, bubblePaint);
    canvas.drawCircle(bubbleCenter, bubbleRadius, borderPaint);
    canvas.drawPath(pinPath, borderPaint);

    final TextPainter textPainter = TextPainter(
      text: TextSpan(
        text: 'P$count',
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w800,
          fontSize: 16,
        ),
      ),
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
    )..layout();

    textPainter.paint(
      canvas,
      Offset(
        bubbleCenter.dx - textPainter.width / 2,
        bubbleCenter.dy - textPainter.height / 2,
      ),
    );

    final ui.Image image = await pictureRecorder.endRecording().toImage(
      markerWidth.toInt(),
      markerHeight.toInt(),
    );
    final ByteData? byteData = await image.toByteData(
      format: ui.ImageByteFormat.png,
    );
    final Uint8List markerBytes = byteData!.buffer.asUint8List();
    final BitmapDescriptor icon = BitmapDescriptor.bytes(markerBytes);
    _availableCountMarkerIcons[count] = icon;
    return icon;
  }

  Future<OrderData?> _fetchOngoingDeliveryOrder() async {
    final List<String> preferredStatuses = [
      ORDER_ACCEPTED,
      ORDER_ARRIVED,
      ORDER_PICKED_UP,
      ORDER_DEPARTED,
    ];

    for (final status in preferredStatuses) {
      final response = await getDeliveryBoyOrderList(
        page: 1,
        deliveryBoyID: getIntAsync(USER_ID),
        cityId: getIntAsync(CITY_ID),
        countryId: getIntAsync(COUNTRY_ID),
        orderStatus: status,
      );
      final List<OrderData> data = response.data ?? [];
      if (data.isEmpty) continue;
      data.sort((a, b) => (b.id ?? 0).compareTo(a.id ?? 0));
      return data.first;
    }
    return null;
  }

  bool _shouldShowPaymentForOngoingOrder(OrderData order) {
    final bool isPaymentPending =
        order.paymentId == null || order.paymentId == 0;
    if (!isPaymentPending) return false;

    final String status = order.status.validate();
    if (status == ORDER_ACCEPTED || status == ORDER_ARRIVED) {
      return order.paymentCollectFrom == PAYMENT_ON_PICKUP;
    }
    if (status == ORDER_PICKED_UP || status == ORDER_DEPARTED) {
      return order.paymentCollectFrom == PAYMENT_ON_DELIVERY;
    }
    return false;
  }

  Future<void> _openOngoingDeliveryJob() async {
    if (_isOpeningOngoingJob) return;
    _isOpeningOngoingJob = true;
    appStore.setLoading(true);
    setState(() {});
    try {
      final OrderData? ongoingOrder = await _fetchOngoingDeliveryOrder();
      if (ongoingOrder == null) {
        toast('No ongoing delivery job found right now.');
        return;
      }

      await ReceivedScreenOrderScreen(
        orderData: ongoingOrder,
        isShowPayment: _shouldShowPaymentForOngoingOrder(ongoingOrder),
      ).launch(context, pageRouteAnimation: PageRouteAnimation.Fade);
      await getLatLngOfOrdersApi();
    } catch (e) {
      toast(e.toString());
    } finally {
      appStore.setLoading(false);
      _isOpeningOngoingJob = false;
      if (mounted) setState(() {});
    }
  }

  Future<void> getLatLngOfOrdersApi({bool showLoader = false}) async {
    if (_isFetchingMapOrders) return;
    _isFetchingMapOrders = true;
    final bool shouldShowLoader = showLoader || markers.isEmpty;
    if (shouldShowLoader) {
      appStore.setLoading(true);
    }
    try {
      driverPosition = await getDriverCurrentPosition();
      final value = await getLatLngOfOrders();
      final pendingOrders = await getDeliveryBoyOrderList(
        page: 1,
        deliveryBoyID: getIntAsync(USER_ID),
        cityId: getIntAsync(CITY_ID),
        countryId: getIntAsync(COUNTRY_ID),
        orderStatus: ORDER_PENDING,
      );

      markers.clear();
      infoWindowItems.clear();
      _isInfoWindowVisible = false;
      selectedInfoWindow = null;

      final List<dynamic> mapOrders = [];
      if (value.data != null) mapOrders.addAll(value.data!);
      if (pendingOrders.data != null) mapOrders.addAll(pendingOrders.data!);

      final Set<String> addedOrderIds = {};
      final Map<String, List<dynamic>> availableLocationOrders = {};
      final Map<String, LatLng> availableLocationPositions = {};
      final Map<String, String?> availableLocationAddress = {};
      final Map<String, String?> availableLocationStartTime = {};
      final Map<String, String?> availableLocationEndTime = {};
      final List<Map<String, dynamic>> nonAvailableMarkerData = [];

      for (final element in mapOrders) {
        try {
          final int? parsedOrderId = extractOrderId(element);
          if (parsedOrderId == null) continue;
          if (isOrderCancelledForCurrentDriver(element)) continue;

          final String orderId = parsedOrderId.toString();
          if (addedOrderIds.contains(orderId)) continue;

          final bool isAvailableOrder = isAvailableOrderForMap(element);
          if (widget.showOnlyAvailable && !isAvailableOrder) continue;

          final String status = extractStatus(element);
          if (isAvailableOrder) {
            final double? pickupLat = extractPickupLatitude(element);
            final double? pickupLng = extractPickupLongitude(element);
            if (pickupLat == null || pickupLng == null) continue;
            if (!isWithinSelectedRange(pickupLat, pickupLng)) continue;
            if (_hasTripRouteFilter && !_matchesTripRouteForElement(element)) {
              continue;
            }

            final String groupKey = _locationGroupingKey(pickupLat, pickupLng);
            availableLocationOrders.putIfAbsent(groupKey, () => []);
            availableLocationOrders[groupKey]!.add(element);
            availableLocationPositions[groupKey] = LatLng(pickupLat, pickupLng);
            availableLocationAddress[groupKey] ??= extractPickupAddress(
              element,
            );
            availableLocationStartTime[groupKey] ??= extractPickupStartTime(
              element,
            );
            availableLocationEndTime[groupKey] ??= extractPickupEndTime(
              element,
            );
          } else if (!widget.showOnlyAvailable &&
              (status == ORDER_ACCEPTED ||
                  status == ORDER_PICKED_UP ||
                  status == ORDER_ARRIVED ||
                  status == ORDER_DEPARTED)) {
            final double? deliveryLat = extractDeliveryLatitude(element);
            final double? deliveryLng = extractDeliveryLongitude(element);
            if (deliveryLat == null || deliveryLng == null) continue;
            if (!isWithinSelectedRange(deliveryLat, deliveryLng)) continue;
            nonAvailableMarkerData.add({
              'element': element,
              'position': LatLng(deliveryLat, deliveryLng),
              'address': extractDeliveryAddress(element),
              'startTime': extractDeliveryStartTime(element),
              'endTime': extractDeliveryEndTime(element),
            });
          } else {
            continue;
          }

          addedOrderIds.add(orderId);
        } catch (e) {
          debugPrint('Skipping map order due to parse error: $e');
          continue;
        }
      }

      for (final entry in availableLocationOrders.entries) {
        if (entry.value.isEmpty) continue;
        final dynamic representativeOrder = entry.value.first;
        final int? representativeOrderId = extractOrderId(representativeOrder);
        if (representativeOrderId == null) continue;

        final int orderCount = entry.value.length;
        double totalDistanceKm = 0;
        final List<int> groupedOrderIds = [];
        for (final dynamic job in entry.value) {
          totalDistanceKm += extractTotalDistance(job);
          final int? id = extractOrderId(job);
          if (id != null) groupedOrderIds.add(id);
        }
        final String markerKey = 'available_${entry.key}';
        final LatLng markerPosition = availableLocationPositions[entry.key]!;
        final String markerTitle = orderCount > 1
            ? '$orderCount active jobs at this location'
            : buildJobTitle(representativeOrder, representativeOrderId);

        markers.add(
          Marker(
            markerId: MarkerId(markerKey),
            position: markerPosition,
            icon: await _buildAvailableMarkerIcon(orderCount),
            onTap: () =>
                _onMarkerTapped(position: markerPosition, markerKey: markerKey),
          ),
        );
        infoWindowItems.add(
          MapOrderInfoWindow(
            markerKey: markerKey,
            orderId: representativeOrderId,
            startTime: availableLocationStartTime[entry.key],
            endTime: availableLocationEndTime[entry.key],
            status: extractStatus(representativeOrder),
            address: availableLocationAddress[entry.key],
            jobTitle: markerTitle,
            isAvailable: true,
            orderCount: orderCount,
            totalDistanceKm: totalDistanceKm,
            orderIds: groupedOrderIds,
          ),
        );
      }

      for (final markerData in nonAvailableMarkerData) {
        final dynamic element = markerData['element'];
        final int? parsedOrderId = extractOrderId(element);
        if (parsedOrderId == null) continue;
        final LatLng markerPosition = markerData['position'] as LatLng;
        final String markerKey = 'order_$parsedOrderId';

        markers.add(
          Marker(
            markerId: MarkerId(markerKey),
            position: markerPosition,
            icon: acceptedMarkerIcon ?? BitmapDescriptor.defaultMarker,
            onTap: () =>
                _onMarkerTapped(position: markerPosition, markerKey: markerKey),
          ),
        );
        infoWindowItems.add(
          MapOrderInfoWindow(
            markerKey: markerKey,
            orderId: parsedOrderId,
            startTime: markerData['startTime'] as String?,
            endTime: markerData['endTime'] as String?,
            status: extractStatus(element),
            address: markerData['address'] as String?,
            jobTitle: buildJobTitle(element, parsedOrderId),
            isAvailable: false,
            orderCount: 1,
            totalDistanceKm: extractTotalDistance(element),
            orderIds: [parsedOrderId],
          ),
        );
      }
    } catch (error) {
      print("Map order fetch error: ${error.toString()}");
    } finally {
      if (shouldShowLoader) {
        appStore.setLoading(false);
      }
      _isFetchingMapOrders = false;
      setState(() {});
    }
  }

  void _onMarkerTapped({required LatLng position, required String markerKey}) {
    setState(() {
      selectedInfoWindow = infoWindowItems.firstWhere(
        (infoWindow) => infoWindow.markerKey == markerKey,
        orElse: () => MapOrderInfoWindow(
          markerKey: markerKey,
          orderId: null,
          startTime: null,
          endTime: null,
          status: null,
          jobTitle: 'Delivery job',
          isAvailable: true,
          address: null,
          orderCount: 1,
          totalDistanceKm: 0,
          orderIds: const [],
        ),
      );
      _isInfoWindowVisible = true;
    });
  }

  void _onMapTapped(LatLng position) {
    setState(() {
      _isInfoWindowVisible = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final bool canShowMap = markers.isNotEmpty || driverPosition != null;
    final LatLng initialPosition = markers.isNotEmpty
        ? markers.first.position
        : LatLng(driverPosition?.latitude ?? 0, driverPosition?.longitude ?? 0);

    return Scaffold(
      appBar: commonAppBarWidget(
        'Map View',
        actions: [
          Container(
            padding: .symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                const Icon(Icons.tune, size: 16, color: Colors.white),
                6.width,
                PopupMenuButton<double>(
                  color: Colors.white,
                  onSelected: (value) async {
                    maxRangeKm = value;
                    await getLatLngOfOrdersApi(showLoader: true);
                    setState(() {});
                  },
                  offset: const Offset(0, 36),
                  itemBuilder: (context) => rangeOptions
                      .map(
                        (item) => PopupMenuItem<double>(
                          value: item,
                          child: Text('${item.toInt()} km'),
                        ),
                      )
                      .toList(),
                  child: Text(
                    '${maxRangeKm.toInt()} km',
                    style: primaryTextStyle(color: Colors.white, size: 12),
                  ),
                ),
              ],
            ),
          ),
          10.width,
        ],
      ),
      body: Stack(
        children: [
          Column(
            mainAxisAlignment: .center,
            children: [
              canShowMap
                  ? GoogleMap(
                      markers: markers.map((e) => e).toSet(),
                      polylines: _polylines,
                      mapType: MapType.normal,
                      cameraTargetBounds: CameraTargetBounds.unbounded,
                      initialCameraPosition: CameraPosition(
                        target: initialPosition,
                        zoom: 12.0,
                      ),
                      onMapCreated: onMapCreated,
                      onTap: _onMapTapped,
                      tiltGesturesEnabled: true,
                      scrollGesturesEnabled: true,
                      zoomGesturesEnabled: true,
                    ).expand()
                  : !appStore.isLoading
                  ? Center(
                      child: Text(
                        'No available orders within ${maxRangeKm.toInt()} km',
                        style: secondaryTextStyle(),
                      ),
                    )
                  : SizedBox(),
            ],
          ),
          if (appStore.isLoading && !canShowMap) Center(child: loaderWidget()),
          if (_isInfoWindowVisible && selectedInfoWindow != null)
            Positioned(
              left: 14,
              right: 14,
              top: 96,
              child: _customInfoWindow(),
            ),
          Positioned(
            top: 10,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Center(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: DriverPalette.surface,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                      onPressed: _openTripRouteFilterDialog,
                      icon: const Icon(Icons.alt_route, size: 16),
                      label: Text(
                        _hasTripRouteFilter
                            ? 'Route: ${_tripRouteOriginLabel.validate()} → ${_tripRouteDestinationLabel.validate()}'
                            : 'Set trip route',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: boldTextStyle(color: Colors.white, size: 11),
                      ),
                    ).withWidth(260),
                    if (_hasTripRouteFilter) ...[
                      6.width,
                      IconButton(
                        onPressed: () async {
                          _clearTripRouteFilter();
                          await getLatLngOfOrdersApi(showLoader: true);
                        },
                        style: IconButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: Colors.red,
                        ),
                        icon: const Icon(Icons.close, size: 16),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            left: 14,
            right: 14,
            bottom: 78,
            child: DriverCard(
              margin: EdgeInsets.zero,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Row(
                children: [
                  DriverMetricPill(
                    icon: Icons.pin_drop_outlined,
                    label: 'Markers',
                    value: '${markers.length}',
                  ),
                  8.width,
                  DriverMetricPill(
                    icon: Icons.location_searching_outlined,
                    label: 'Range',
                    value: '${maxRangeKm.toInt()} km',
                  ),
                  Spacer(),
                  IconButton(
                    style: IconButton.styleFrom(
                      backgroundColor: DriverPalette.primary.withValues(
                        alpha: 0.08,
                      ),
                    ),
                    onPressed: () async {
                      await getLatLngOfOrdersApi(showLoader: true);
                    },
                    icon: const Icon(
                      Icons.refresh,
                      color: DriverPalette.primary,
                    ),
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            left: 14,
            bottom: 14,
            child: SizedBox(
              width: 148,
              height: 48,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: DriverPalette.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24),
                  ),
                ),
                onPressed: () {
                  Navigator.of(context).pop(true);
                },
                icon: const Icon(Icons.list_alt_outlined, size: 18),
                label: Text(
                  'Available Jobs',
                  style: boldTextStyle(color: Colors.white, size: 13),
                ),
              ),
            ),
          ),
          Positioned(
            right: 14,
            bottom: 14,
            child: SizedBox(
              width: 168,
              height: 48,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0F172A),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24),
                  ),
                ),
                onPressed: _isOpeningOngoingJob
                    ? null
                    : _openOngoingDeliveryJob,
                icon: _isOpeningOngoingJob
                    ? const SizedBox(
                        height: 16,
                        width: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Colors.white,
                          ),
                        ),
                      )
                    : const Icon(Icons.local_shipping_outlined, size: 18),
                label: Text(
                  'Ongoing Job',
                  style: boldTextStyle(color: Colors.white, size: 12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _autoRefreshTimer?.cancel();
    super.dispose();
  }

  Widget _customInfoWindow() {
    final MapOrderInfoWindow info = selectedInfoWindow!;
    final bool hasMultipleJobs = info.orderCount > 1;
    final String jobTitle = info.jobTitle.validate().isNotEmpty
        ? info.jobTitle.validate()
        : hasMultipleJobs
        ? '${info.orderCount} active jobs'
        : 'Job #${info.orderId ?? ''}';
    final String location = info.address.validate().isNotEmpty
        ? info.address.validate()
        : 'Location unavailable';
    final String statusLabel = info.isAvailable
        ? hasMultipleJobs
              ? '${info.orderCount} jobs'
              : 'Available job'
        : orderStatus(info.status.validate());
    final Color statusChipColor = info.isAvailable
        ? const Color(0xFF10B981)
        : driverStatusColor(info.status.validate());
    return DriverCard(
      margin: EdgeInsets.zero,
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: .start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  jobTitle,
                  style: boldTextStyle(size: 14),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Container(
                decoration: BoxDecoration(
                  color: statusChipColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(999),
                ),
                padding: .symmetric(horizontal: 8, vertical: 6),
                child: Text(
                  statusLabel,
                  style: primaryTextStyle(
                    size: 11,
                    color: statusChipColor,
                    weight: FontWeight.w700,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ),
            ],
          ),
          SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(
                Icons.location_on_outlined,
                size: 17,
                color: Color(0xFF64748B),
              ),
              6.width,
              Expanded(
                child: Text(
                  location,
                  style: secondaryTextStyle(
                    size: 12,
                    color: const Color(0xFF334155),
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          SizedBox(height: 10),
          Text(
            hasMultipleJobs
                ? '${info.orderCount} active jobs at this pickup point'
                : '#${info.orderId}',
            style: secondaryTextStyle(size: 11),
          ),
          SizedBox(height: 6),
          Text(
            hasMultipleJobs
                ? 'Total distance: ${_distanceLabel(info.totalDistanceKm)}'
                : 'Trip distance: ${_distanceLabel(info.totalDistanceKm)}',
            style: secondaryTextStyle(size: 11),
          ),
          if (info.isAvailable) ...[
            SizedBox(height: 10),
            if (hasMultipleJobs)
              OutlinedButton.icon(
                onPressed: () {
                  Navigator.of(context).pop(true);
                },
                icon: const Icon(Icons.list_alt_outlined, size: 16),
                label: const Text('Open available jobs'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: DriverPalette.primary,
                  side: const BorderSide(color: DriverPalette.primary),
                  backgroundColor: DriverPalette.softBackground,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              )
            else
              DriverPrimaryButton(
                label: _isAcceptingAvailableJob ? 'Accepting...' : 'Accept job',
                leading: Icons.check_circle_outline,
                isLoading: _isAcceptingAvailableJob,
                onTap: _isAcceptingAvailableJob
                    ? null
                    : () => _acceptAvailableJob(info),
              ),
          ],
        ],
      ),
    );
  }
}

class MapOrderInfoWindow {
  final String markerKey;
  final int? orderId;
  final String? startTime;
  final String? endTime;
  final String? status;
  final String? jobTitle;
  final bool isAvailable;
  final int orderCount;
  final String? address;
  final double totalDistanceKm;
  final List<int> orderIds;
  MapOrderInfoWindow({
    required this.markerKey,
    required this.orderId,
    required this.startTime,
    required this.endTime,
    required this.status,
    required this.jobTitle,
    required this.isAvailable,
    required this.orderCount,
    required this.address,
    required this.totalDistanceKm,
    required this.orderIds,
  });
}
