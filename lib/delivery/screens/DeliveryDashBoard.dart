import 'dart:async';
import 'dart:math' as math;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:crisp_chat/crisp_chat.dart';
import 'package:date_time_picker/date_time_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:flutter_ringtone_player/flutter_ringtone_player.dart';
import 'package:flutter_vector_icons/flutter_vector_icons.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:intl/intl.dart';
import 'package:nadaruns_delivery/delivery/fragment/DHomeFragment.dart';
import 'package:nadaruns_delivery/main/services/VersionServices.dart';
import '../components/DriverDesignSystem.dart';
import '../../delivery/screens/OrdersMapScreen.dart';
import '../../extensions/app_text_field.dart';
import '../../extensions/extension_util/int_extensions.dart';
import '../../extensions/extension_util/string_extensions.dart';
import '../../extensions/extension_util/widget_extensions.dart';
import '../../extensions/widgets.dart';
import '../../main/utils/Colors.dart';
import '../../main/utils/Widgets.dart';
import '../../main/utils/dynamic_theme.dart';

import '../../delivery/fragment/DProfileFragment.dart';
import '../../extensions/LiveStream.dart';
import '../../extensions/animatedList/animated_configurations.dart';
import '../../extensions/animatedList/animated_list_view.dart';
import '../../extensions/colors.dart';
import '../../extensions/common.dart';
import '../../extensions/confirmation_dialog.dart';
import '../../extensions/decorations.dart';
import '../../extensions/shared_pref.dart';
import '../../extensions/system_utils.dart';
import '../../extensions/text_styles.dart';
import '../../main.dart';
import '../../main/components/CommonScaffoldComponent.dart';
import '../../main/models/CityListModel.dart';
import '../../main/models/OrderListModel.dart';
import '../../main/network/RestApis.dart';
import '../../main/screens/NotificationScreen.dart';
import '../../main/screens/UserCitySelectScreen.dart';
import '../../main/utils/Common.dart';
import '../../main/utils/Constants.dart';
import 'ReceivedScreenOrderScreen.dart';

class DeliveryDashBoard extends StatefulWidget {
  final int selectedIndex;
  final bool openMapOnStart;
  DeliveryDashBoard({this.selectedIndex = 0, this.openMapOnStart = true});

  @override
  DeliveryDashBoardState createState() => DeliveryDashBoardState();
}

class DeliveryDashBoardState extends State<DeliveryDashBoard>
    with WidgetsBindingObserver {
  List<String> statusList = [
    ORDER_PENDING,
    ORDER_ASSIGNED,
    ORDER_ACCEPTED,
    ORDER_ARRIVED,
    ORDER_PICKED_UP,
    ORDER_DEPARTED,
    ORDER_DELIVERED,
  ];
  final String _deliveryOnlineStorageKey = 'DELIVERYMAN_ONLINE';
  ScrollController scrollController = ScrollController();
  PageController pageController = PageController();
  int currentPage = 1;
  int totalPage = 1;
  int selectedStatusIndex = 0;
  List<OrderData> orderData = [];
  GlobalKey<FormState> rescheduleFormKey = GlobalKey<FormState>();
  TextEditingController reasonTitleTextEditingController =
      TextEditingController();
  TextEditingController dateTextEditingController = TextEditingController();
  TextEditingController pickDateController = TextEditingController();
  DateTime? pickDate;
  bool _initialMapOpened = false;
  bool _isProgrammaticStatusTransition = false;
  bool _isFetchingOrders = false;
  Timer? _ordersAutoRefreshTimer;
  bool _isOpeningOngoingOrder = false;
  bool _isResolvingActiveOrder = false;
  int? _activeOrderId;
  String? _activeOrderStatus;
  Position? _lastKnownDriverPosition;
  LatLng? _tripRouteOrigin;
  LatLng? _tripRouteDestination;
  String? _tripRouteOriginLabel;
  String? _tripRouteDestinationLabel;
  bool isDriverOnline = true;
  late CrispConfig configData;
  String? crispChatIcon;
  static const List<String> _inProgressStatusPriority = [
    ORDER_DEPARTED,
    ORDER_PICKED_UP,
    ORDER_ARRIVED,
    ORDER_ACCEPTED,
  ];
  static const List<String> _queueStatusPriority = [
    ORDER_ASSIGNED,
    ORDER_PENDING,
  ];
  bool get _canOpenCrispChat =>
      appStore.isCrispChatEnabled &&
      appStore.crispChatWebsiteId.trim().isNotEmpty;

  void _buildCrispConfig(String websiteId) {
    User user = User(
      email: appStore.userEmail,
      nickName: "${getStringAsync(NAME)}",
      avatar: appStore.userProfile,
    );
    FlutterCrispChat.resetCrispChatSession();
    configData = CrispConfig(
      user: user,
      tokenId: getIntAsync(USER_ID).toString(),
      enableNotifications: true,
      websiteID: websiteId,
    );
  }

  String _tripDistanceMetric(OrderData data) {
    final double? distance = safeToDouble(data.totalDistance);
    if (distance == null || distance <= 0) return '--';
    return '${distance.toStringAsFixed(distance >= 10 ? 0 : 1)} km';
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    print("Selected Index ======== ${widget.selectedIndex}");
    init();
  }

  Future<void> _handleOrderActionTap(OrderData data) async {
    final String activeStatus = data.status.validate();
    if (!_isSequentiallyManagedStatus(activeStatus)) return;
    FlutterRingtonePlayer().stop();

    if (activeStatus == ORDER_PENDING || activeStatus == ORDER_ASSIGNED) {
      appStore.setLoading(true);
      await onTapData(
        orderData: data,
        orderStatus: activeStatus,
      ).whenComplete(() => appStore.setLoading(false));
      return;
    }

    if (activeStatus == ORDER_CREATED) {
      appStore.setLoading(true);
      await onTapData(
        orderData: data,
        orderStatus: activeStatus,
      ).whenComplete(() => appStore.setLoading(false));
      return;
    }

    if (activeStatus == ORDER_ACCEPTED || activeStatus == ORDER_ARRIVED) {
      await onTapData(orderData: data, orderStatus: activeStatus);
      return;
    }

    if (activeStatus == ORDER_PICKED_UP) {
      appStore.setLoading(true);
      await onTapData(
        orderData: data,
        orderStatus: activeStatus,
      ).whenComplete(() => appStore.setLoading(false));
      return;
    }

    if (activeStatus == ORDER_DEPARTED) {
      await _showDepartedActionDialog(data);
      return;
    }

    showConfirmDialogCustom(
      context,
      primaryColor: ColorUtils.colorPrimary,
      dialogType: DialogType.CONFIRMATION,
      title: orderTitle(activeStatus),
      positiveText: language.yes,
      negativeText: language.no,
      onAccept: (c) async {
        appStore.setLoading(true);
        await onTapData(orderData: data, orderStatus: activeStatus);
        appStore.setLoading(false);
      },
    );
  }

  Future<void> _showDepartedActionDialog(OrderData data) async {
    int mode = 0;
    return showInDialog(
      barrierDismissible: true,
      getContext,
      builder: (p0) {
        return StatefulBuilder(
          builder: (context, setLocalState) {
            return Form(
              key: rescheduleFormKey,
              child: SingleChildScrollView(
                child: !appStore.isLoading
                    ? Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              commonButton(language.reschedule, size: 12, () {
                                setLocalState(() {
                                  mode = 1;
                                });
                              }).expand(),
                              8.width,
                              commonButton(
                                language.confirmDelivery,
                                size: 12,
                                () async {
                                  if (context.mounted) Navigator.pop(context);
                                  await onTapData(
                                    orderData: data,
                                    orderStatus: ORDER_DEPARTED,
                                  );
                                },
                              ).expand(),
                            ],
                          ).visible(mode == 0),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                language.rescheduleTitle,
                                style: boldTextStyle(),
                              ),
                              10.height,
                              Divider(color: dividerColor, height: 1),
                              8.height,
                              Text(language.reason, style: boldTextStyle()),
                              12.height,
                              AppTextField(
                                isValidationRequired: true,
                                controller: reasonTitleTextEditingController,
                                textFieldType: TextFieldType.NAME,
                                errorThisFieldRequired:
                                    language.fieldRequiredMsg,
                                decoration: commonInputDecoration(
                                  hintText: language.reason,
                                ),
                              ),
                              8.height,
                              Text(language.date, style: boldTextStyle()),
                              12.height,
                              DateTimePicker(
                                controller: pickDateController,
                                type: DateTimePickerType.date,
                                initialDate: DateTime.now(),
                                firstDate: DateTime.now(),
                                lastDate: DateTime.now().add(
                                  Duration(days: 30),
                                ),
                                onChanged: (value) =>
                                    pickDate = DateTime.parse(value),
                                validator: (value) {
                                  if (value!.isEmpty)
                                    return language.fieldRequiredMsg;
                                  return null;
                                },
                                decoration: commonInputDecoration(
                                  suffixIcon: Icons.calendar_today,
                                  hintText: language.date,
                                ),
                              ),
                              16.height,
                              Row(
                                children: [
                                  commonButton(
                                    language.cancel,
                                    size: 14,
                                    () => finish(getContext, 0),
                                  ).expand(),
                                  6.width,
                                  commonButton(
                                    language.reschedule,
                                    size: 14,
                                    () async {
                                      if (rescheduleFormKey.currentState!
                                          .validate()) {
                                        Map request = {
                                          "order_id": data.id,
                                          "reason":
                                              reasonTitleTextEditingController
                                                  .text
                                                  .toString(),
                                          "date": DateFormat(
                                            'yyyy-MM-dd',
                                          ).format(pickDate!),
                                        };
                                        appStore.setLoading(true);
                                        await rescheduleOrder(request).then((
                                          value,
                                        ) {
                                          toast(value.message);
                                          getOrderListApiCall();
                                          appStore.setLoading(false);
                                          finish(context);
                                        });
                                      }
                                    },
                                  ).expand(),
                                ],
                              ),
                            ],
                          ).visible(mode == 1),
                        ],
                      )
                    : Observer(
                        builder: (context) =>
                            loaderWidget().visible(appStore.isLoading),
                      ).center(),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> configureCrispChat() async {
    FlutterCrispChat.setSessionString(
      key: getIntAsync(USER_ID).toString(),
      value: getIntAsync(USER_ID).toString(),
    );
  }

  Future<void> openCrispSupportChat() async {
    if (!_canOpenCrispChat) {
      toast("Messaging is currently unavailable.");
      return;
    }
    try {
      await configCrispChatData();
      await configureCrispChat();
      await FlutterCrispChat.openCrispChat(config: configData);
    } catch (e, stack) {
      if (kDebugMode) {
        print("error in crispchat${e.toString()}-----------$stack");
      }
      toast("Unable to open messaging right now. Please try again.");
    }
  }

  Future<void> _moveToStatusAndRefresh(
    String targetStatus, {
    Duration delay = const Duration(milliseconds: 700),
  }) async {
    final int targetIndex = statusList.indexWhere(
      (item) => item == targetStatus,
    );
    if (targetIndex == -1) return;

    _isProgrammaticStatusTransition = true;
    selectedStatusIndex = targetIndex;
    currentPage = 1;
    orderData.clear();

    if (pageController.hasClients) {
      pageController.jumpToPage(targetIndex);
    }
    setState(() {});

    if (delay > Duration.zero) {
      await Future.delayed(delay);
    }
    await _refreshOrdersWithActiveLock(showLoader: true, syncLock: false);
  }

  Future<void> configCrispChatData() async {
    if (_canOpenCrispChat) {
      _buildCrispConfig(appStore.crispChatWebsiteId.trim());
    }
  }

  void init() async {
    appStore.setLoading(true);
    await getDashboardDetails();
    await configCrispChatData();
    LiveStream().on('UpdateLanguage', (p0) {
      setState(() {});
    });
    LiveStream().on('UpdateTheme', (p0) {
      setState(() {});
    });
    selectedStatusIndex = widget.selectedIndex;
    isDriverOnline = getBoolAsync(
      _deliveryOnlineStorageKey,
      defaultValue: true,
    );
    try {
      final value = await getAppSetting();
      print(
        "-------------------------------${value.otpVerifyOnPickupDelivery}",
      );
      appStore.setOtpVerifyOnPickupDelivery(
        value.otpVerifyOnPickupDelivery == 1,
      );
      appStore.setCurrencyCode(value.currencyCode ?? CURRENCY_CODE);
      appStore.setCurrencySymbol(value.currency ?? CURRENCY_SYMBOL);
      appStore.setCurrencyPosition(
        value.currencyPosition ?? CURRENCY_POSITION_LEFT,
      );
      appStore.isVehicleOrder = value.isVehicleInOrder ?? 0;
      appStore.setSiteEmail(value.siteEmail ?? "");
      appStore.setCopyRight(value.siteCopyright ?? "");
      //   appStore.setOrderTrackingIdPrefix(value.orderTrackingIdPrefix ?? "");
      appStore.setIsInsuranceAllowed(value.isInsuranceAllowed ?? "0");
      appStore.setInsurancePercentage(value.insurancePercentage ?? "0");
      appStore.setInsuranceDescription(value.insuranceDescription ?? "");
      appStore.setMaxAmountPerMonth(value.maxEarningsPerMonth ?? '');
      appStore.setClaimDuration(value.claimDuration ?? "");
      // setValue(IS_VERIFIED_DELIVERY_MAN, (value.isVerifiedDeliveryMan.validate() == 1));
    } catch (error) {
      log(error.toString());
    }
    if (isDriverOnline && await checkPermission()) {
      await checkLocationPermission(context);
    }
    scrollController.addListener(() {
      if (scrollController.position.pixels ==
          scrollController.position.maxScrollExtent) {
        if (currentPage < totalPage) {
          currentPage++;
          setState(() {});
          getOrderListApiCall();
        }
      }
    });
    if (selectedStatusIndex > 2) {
      pageController.jumpToPage(selectedStatusIndex);
    }
    orderData.clear();
    await _refreshOrdersWithActiveLock(
      showLoader: true,
      syncLock: true,
      autoFocus: true,
    );
    _startOrdersAutoRefreshTimer();
    if (widget.openMapOnStart) {
      afterBuildCreated(() {
        openInitialMapIfNeeded();
      });
    }
  }

  Future<void> onOnlineStatusChanged(bool value) async {
    setState(() {
      isDriverOnline = value;
    });
    await setValue(_deliveryOnlineStorageKey, value);
    if (value && await checkPermission()) {
      await checkLocationPermission(context);
    } else {
      positionStream?.cancel();
    }
    try {
      await updateUserStatus({
        "id": getIntAsync(USER_ID),
        "is_online": value ? 1 : 0,
      });
    } catch (e) {
      log(e.toString());
    }
  }

  Future<void> _openMapView() async {
    final bool? result = await OrdersMapScreen(
      initialRangeKm: 50,
      showOnlyAvailable: true,
    ).launch(context, pageRouteAnimation: PageRouteAnimation.Fade);
    if (!mounted) return;
    if (result == true) {
      await _refreshOrdersWithActiveLock(
        showLoader: true,
        syncLock: true,
        autoFocus: true,
      );
    }
  }

  bool _isSequentiallyManagedStatus(String status) {
    return status == ORDER_CREATED ||
        status == ORDER_PENDING ||
        status == ORDER_ASSIGNED ||
        status == ORDER_ACCEPTED ||
        status == ORDER_ARRIVED ||
        status == ORDER_PICKED_UP ||
        status == ORDER_DEPARTED;
  }

  void _setActiveOrderLock({required OrderData order, required String status}) {
    _activeOrderId = order.id;
    _activeOrderStatus = status;
  }

  bool get _hasTripRouteFilter =>
      _tripRouteOrigin != null && _tripRouteDestination != null;

  bool get _isAvailableJobsTabSelected {
    if (selectedStatusIndex < 0 || selectedStatusIndex >= statusList.length) {
      return false;
    }
    final String status = statusList[selectedStatusIndex];
    return status == ORDER_PENDING || status == ORDER_ASSIGNED;
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
        : CityModel.fromJson(getJSONAsync(CITY_DATA)).name.validate();
    final TextEditingController originController = TextEditingController(
      text: defaultOrigin,
    );
    final TextEditingController destinationController = TextEditingController(
      text: _tripRouteDestinationLabel.validate(),
    );

    final Map<String, String>?
    routeInput = await showDialog<Map<String, String>>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Trip itinerary'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AppTextField(
                controller: originController,
                textFieldType: TextFieldType.OTHER,
                decoration: commonInputDecoration(hintText: 'From city/place'),
              ),
              10.height,
              AppTextField(
                controller: destinationController,
                textFieldType: TextFieldType.OTHER,
                decoration: commonInputDecoration(hintText: 'To city/place'),
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
      await getOrderListApiCall(showLoader: true);
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

  bool _matchesTripRouteForOrder(OrderData order) {
    if (!_hasTripRouteFilter) return true;

    final double? pickupLat = safeToDouble(order.pickupPoint?.latitude);
    final double? pickupLng = safeToDouble(order.pickupPoint?.longitude);
    final double? deliveryLat = safeToDouble(order.deliveryPoint?.latitude);
    final double? deliveryLng = safeToDouble(order.deliveryPoint?.longitude);
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

  List<OrderData> _visibleOrdersForCurrentTab() {
    final List<OrderData> baseOrders = orderData
        .where((item) => item.status != ORDER_DRAFT)
        .toList();
    if (!_isAvailableJobsTabSelected || !_hasTripRouteFilter) {
      return baseOrders;
    }
    return baseOrders.where(_matchesTripRouteForOrder).toList();
  }

  Widget _buildTripRouteFilterBar() {
    if (!_isAvailableJobsTabSelected) return const SizedBox();

    final bool hasFilter = _hasTripRouteFilter;
    final String routeSummary = hasFilter
        ? '${_tripRouteOriginLabel.validate()} → ${_tripRouteDestinationLabel.validate()}'
        : 'Match available jobs to your route';

    return Container(
      margin: const EdgeInsets.fromLTRB(14, 8, 14, 0),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.96),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: DriverPalette.cardBorder),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              routeSummary,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: primaryTextStyle(size: 12, weight: FontWeight.w600),
            ),
          ),
          8.width,
          OutlinedButton.icon(
            onPressed: _openTripRouteFilterDialog,
            style: OutlinedButton.styleFrom(
              foregroundColor: DriverPalette.primary,
              side: const BorderSide(color: DriverPalette.primary),
              backgroundColor: DriverPalette.softBackground,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            icon: const Icon(Icons.alt_route, size: 16),
            label: Text(hasFilter ? 'Edit route' : 'Set route'),
          ),
          if (hasFilter) ...[
            6.width,
            IconButton(
              onPressed: _clearTripRouteFilter,
              style: IconButton.styleFrom(
                backgroundColor: const Color(0xFFFEE2E2),
                foregroundColor: Colors.red,
              ),
              icon: const Icon(Icons.close, size: 16),
            ),
          ],
        ],
      ),
    );
  }

  DateTime? _tryParseDateTime(String? rawValue) {
    final String value = rawValue.validate().trim();
    if (value.isEmpty) return null;

    try {
      return DateTime.parse(value);
    } catch (_) {}

    final String normalizedValue = value.contains(' ')
        ? value.replaceFirst(' ', 'T')
        : value;
    if (normalizedValue != value) {
      try {
        return DateTime.parse(normalizedValue);
      } catch (_) {}
    }

    return null;
  }

  bool _isBeforeScheduledStart(String? startTime) {
    final DateTime? parsedStartTime = _tryParseDateTime(startTime);
    if (parsedStartTime == null) return false;
    return DateTime.now().isBefore(parsedStartTime);
  }

  bool _isPickupBlockedBySchedule(OrderData orderData) {
    return _isBeforeScheduledStart(orderData.pickupPoint?.startTime);
  }

  bool _isDeliveryBlockedBySchedule(OrderData orderData) {
    return _isBeforeScheduledStart(orderData.deliveryPoint?.startTime);
  }

  Future<bool> _openReceivedOrderScreen(
    OrderData orderData, {
    required bool isShowPayment,
  }) async {
    final dynamic result = await ReceivedScreenOrderScreen(
      orderData: orderData,
      isShowPayment: isShowPayment,
    ).launch(context, pageRouteAnimation: PageRouteAnimation.Fade);
    return result == true;
  }

  double? safeToDouble(dynamic value) {
    if (value == null) return null;
    return double.tryParse(value.toString());
  }

  double _distanceScoreForOrder(OrderData order, {String? forStatus}) {
    final String status = forStatus ?? order.status.validate();
    final bool useDeliveryPoint =
        status == ORDER_PICKED_UP || status == ORDER_DEPARTED;
    final double? targetLat = useDeliveryPoint
        ? safeToDouble(order.deliveryPoint?.latitude)
        : safeToDouble(order.pickupPoint?.latitude);
    final double? targetLng = useDeliveryPoint
        ? safeToDouble(order.deliveryPoint?.longitude)
        : safeToDouble(order.pickupPoint?.longitude);

    if (_lastKnownDriverPosition != null &&
        targetLat != null &&
        targetLng != null) {
      return Geolocator.distanceBetween(
        _lastKnownDriverPosition!.latitude,
        _lastKnownDriverPosition!.longitude,
        targetLat,
        targetLng,
      );
    }

    final double? fallbackDistanceKm = safeToDouble(order.totalDistance);
    if (fallbackDistanceKm != null) {
      return fallbackDistanceKm * 1000;
    }
    return double.infinity;
  }

  void _sortOrdersByDistance(List<OrderData> orders, {String? forStatus}) {
    orders.sort((a, b) {
      final int distanceCompare = _distanceScoreForOrder(
        a,
        forStatus: forStatus,
      ).compareTo(_distanceScoreForOrder(b, forStatus: forStatus));
      if (distanceCompare != 0) return distanceCompare;
      return (a.id ?? 0).compareTo(b.id ?? 0);
    });
  }

  Future<List<OrderData>> _fetchOrdersByStatus(String orderStatus) async {
    try {
      final value = await getDeliveryBoyOrderList(
        page: 1,
        deliveryBoyID: getIntAsync(USER_ID),
        cityId: getIntAsync(CITY_ID),
        countryId: getIntAsync(COUNTRY_ID),
        orderStatus: orderStatus,
      );
      final List<OrderData> orders = value.data ?? [];
      _sortOrdersByDistance(orders, forStatus: orderStatus);
      return orders;
    } catch (_) {
      return [];
    }
  }

  Future<OrderData?> _fetchFirstOrderByStatus(String orderStatus) async {
    final List<OrderData> orders = await _fetchOrdersByStatus(orderStatus);
    if (orders.isEmpty) return null;
    return orders.first;
  }

  Future<void> _focusStatusIfRequired(
    String targetStatus, {
    bool autoFocus = false,
  }) async {
    if (!autoFocus) return;
    final int targetIndex = statusList.indexWhere(
      (status) => status == targetStatus,
    );
    if (targetIndex == -1 || targetIndex == selectedStatusIndex) return;

    _isProgrammaticStatusTransition = true;
    selectedStatusIndex = targetIndex;
    currentPage = 1;
    orderData.clear();
    if (pageController.hasClients) {
      pageController.jumpToPage(targetIndex);
    }
    setState(() {});
  }

  Future<void> _syncActiveOrderLock({bool autoFocus = false}) async {
    if (_isResolvingActiveOrder) return;
    _isResolvingActiveOrder = true;
    try {
      for (final status in _inProgressStatusPriority) {
        final OrderData? order = await _fetchFirstOrderByStatus(status);
        if (order == null) continue;
        _setActiveOrderLock(order: order, status: status);
        await _focusStatusIfRequired(status, autoFocus: autoFocus);
        return;
      }

      final List<OrderData> queuedOrders = [];
      for (final status in _queueStatusPriority) {
        queuedOrders.addAll(await _fetchOrdersByStatus(status));
      }

      if (queuedOrders.isNotEmpty) {
        _sortOrdersByDistance(queuedOrders);
        final OrderData nextOrder = queuedOrders.first;
        final String nextStatus = nextOrder.status.validate();
        _setActiveOrderLock(order: nextOrder, status: nextStatus);
        await _focusStatusIfRequired(nextStatus, autoFocus: autoFocus);
        return;
      }

      _activeOrderId = null;
      _activeOrderStatus = null;
    } finally {
      _isResolvingActiveOrder = false;
    }
  }

  Future<void> _refreshOrdersWithActiveLock({
    bool showLoader = false,
    bool syncLock = false,
    bool autoFocus = false,
    bool resetPage = true,
  }) async {
    if (syncLock) {
      await _syncActiveOrderLock(autoFocus: autoFocus);
    }
    if (resetPage) {
      currentPage = 1;
    }
    await getOrderListApiCall(showLoader: showLoader);
  }

  Future<OrderData?> _fetchOngoingDeliveryOrder() async {
    await _syncActiveOrderLock(autoFocus: false);
    if (_activeOrderStatus == null || _activeOrderId == null) {
      return null;
    }

    final List<OrderData> activeOrders = await _fetchOrdersByStatus(
      _activeOrderStatus!,
    );
    for (final order in activeOrders) {
      if (order.id == _activeOrderId) {
        return order;
      }
    }
    if (activeOrders.isNotEmpty) {
      final OrderData fallback = activeOrders.first;
      _setActiveOrderLock(order: fallback, status: _activeOrderStatus!);
      return fallback;
    }
    return null;
  }

  bool _shouldShowPaymentForOngoingOrder(OrderData order) {
    if ((order.paymentId ?? 0) != 0) return false;
    final status = order.status.validate();
    if (status == ORDER_PICKED_UP || status == ORDER_DEPARTED) {
      return order.paymentCollectFrom == PAYMENT_ON_DELIVERY;
    }
    if (status == ORDER_ACCEPTED || status == ORDER_ARRIVED) {
      return order.paymentCollectFrom == PAYMENT_ON_PICKUP;
    }
    if (status == ORDER_CREATED ||
        status == ORDER_PENDING ||
        status == ORDER_ASSIGNED) {
      return order.paymentCollectFrom == PAYMENT_ON_PICKUP;
    }
    return false;
  }

  Future<void> _openOngoingDeliveryJob() async {
    if (_isOpeningOngoingOrder) return;
    setState(() {
      _isOpeningOngoingOrder = true;
    });

    final order = await _fetchOngoingDeliveryOrder();
    if (!mounted) return;

    if (order == null) {
      toast('No ongoing delivery job found');
      setState(() {
        _isOpeningOngoingOrder = false;
      });
      return;
    }

    await ReceivedScreenOrderScreen(
      orderData: order,
      isShowPayment: _shouldShowPaymentForOngoingOrder(order),
    ).launch(context, pageRouteAnimation: PageRouteAnimation.Fade);

    await getOrderListApiCall();
    if (!mounted) return;
    setState(() {
      _isOpeningOngoingOrder = false;
    });
  }

  void openInitialMapIfNeeded() {
    if (_initialMapOpened) return;
    _initialMapOpened = true;
    _openMapView();
  }

  void _startOrdersAutoRefreshTimer() {
    _ordersAutoRefreshTimer?.cancel();
    _ordersAutoRefreshTimer = Timer.periodic(const Duration(seconds: 4), (
      timer,
    ) {
      if (!mounted) return;
      _refreshOrdersWithActiveLock(resetPage: true);
    });
  }

  LatLng? getNavigationTarget(OrderData data) {
    final double? pickupLat = safeToDouble(data.pickupPoint?.latitude);
    final double? pickupLng = safeToDouble(data.pickupPoint?.longitude);
    final double? deliveryLat = safeToDouble(data.deliveryPoint?.latitude);
    final double? deliveryLng = safeToDouble(data.deliveryPoint?.longitude);

    final pickupLocation = (pickupLat != null && pickupLng != null)
        ? LatLng(pickupLat, pickupLng)
        : null;
    final deliveryLocation = (deliveryLat != null && deliveryLng != null)
        ? LatLng(deliveryLat, deliveryLng)
        : null;

    final status = data.status.validate();
    if (status == ORDER_ACCEPTED ||
        status == ORDER_ARRIVED ||
        status == ORDER_ASSIGNED ||
        status == ORDER_PENDING ||
        status == ORDER_CREATED) {
      return pickupLocation ?? deliveryLocation;
    }
    if (status == ORDER_PICKED_UP || status == ORDER_DEPARTED) {
      return deliveryLocation ?? pickupLocation;
    }
    return pickupLocation ?? deliveryLocation;
  }

  Future<void> onTapNavigation(OrderData data) async {
    final LatLng? target = getNavigationTarget(data);
    if (target == null) {
      toast(language.mapLoadingError);
      return;
    }

    try {
      if (await checkPermission()) {
        final position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
        );
        await openMap(
          position.latitude,
          position.longitude,
          target.latitude,
          target.longitude,
        );
      } else {
        await openMapToLocation(target.latitude, target.longitude);
      }
    } catch (e) {
      try {
        await openMapToLocation(target.latitude, target.longitude);
      } catch (_) {
        toast(language.mapLoadingError);
      }
    }
  }

  getDashboardDetails() async {
    await getDashboardDetail().then((value) {
      if (value.deliverManVersion != null) {
        VersionService().getVersionData(context, value.deliverManVersion);
      }
      if (value.crispData != null) {
        final bool isChatEnabled = value.crispData!.isCrispChatEnabled ?? false;
        final String websiteId = value.crispData!.crispChatWebsiteId.validate();
        final bool canEnableChat = isChatEnabled && websiteId.isNotEmpty;
        appStore.setIsCrispChatEnabled(canEnableChat);
        appStore.setCrispChatWebsiteId(websiteId);
        if (canEnableChat) {
          _buildCrispConfig(websiteId);
        }
      }
      if (value.appSetting != null) {
        appStore.setIsSmsOrder(value.appSetting!.isSmsOrder ?? 0);
      }
    });
  }

  Future<void> checkLocationPermission(BuildContext context) async {
    initLocationStream();
  }

  void initLocationStream() async {
    positionStream?.cancel();
    if (!isDriverOnline) return;

    LocationSettings locationSettings = LocationSettings(
      accuracy: LocationAccuracy.best,
      distanceFilter: 100,
    );
    positionStream =
        Geolocator.getPositionStream(locationSettings: locationSettings).listen(
          (Position event) async {
            List<Placemark> placeMarks = await placemarkFromCoordinates(
              event.latitude,
              event.longitude,
            );
            try {
              if (placeMarks.isNotEmpty)
                updateUserStatus({
                  "id": getIntAsync(USER_ID),
                  "latitude": event.latitude.toString(),
                  "longitude": event.longitude.toString(),
                }).then((value) {
                  log("value...." + value.toString());
                });
            } catch (e) {}
          },
        );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        onResumed();
        break;
      default:
    }
  }

  void onResumed() async {
    if (isDriverOnline) {
      await checkLocationPermission(context);
    }
    await _refreshOrdersWithActiveLock(resetPage: true);
    // await getDashboardDetails();
    if (getStringAsync(USER_TYPE) == DELIVERY_MAN) {
      isSosVisible.value = true;
    } else {
      isSosVisible.value = false;
    }
    setState(() {});
  }

  void _mergeOrdersWithoutDuplicates(
    List<OrderData> fetched, {
    required bool resetExisting,
  }) {
    final List<OrderData> merged = resetExisting
        ? <OrderData>[]
        : List<OrderData>.from(orderData);
    final Map<int, int> existingIndexes = <int, int>{};

    for (int index = 0; index < merged.length; index++) {
      final int? id = merged[index].id;
      if (id != null) {
        existingIndexes[id] = index;
      }
    }

    for (final order in fetched) {
      final int? id = order.id;
      if (id != null && existingIndexes.containsKey(id)) {
        merged[existingIndexes[id]!] = order;
      } else {
        if (id != null) {
          existingIndexes[id] = merged.length;
        }
        merged.add(order);
      }
    }

    orderData
      ..clear()
      ..addAll(merged);
  }

  Future<void> getOrderListApiCall({bool showLoader = false}) async {
    if (_isFetchingOrders) return;
    _isFetchingOrders = true;
    if (!isDriverOnline && selectedStatusIndex == 0) {
      orderData.clear();
      _isFetchingOrders = false;
      setState(() {});
      return;
    }
    final bool shouldShowLoader = showLoader || orderData.isEmpty;
    if (shouldShowLoader) {
      appStore.setLoading(true);
    }
    await getDeliveryBoyOrderList(
          page: currentPage,
          deliveryBoyID: getIntAsync(USER_ID),
          cityId: getIntAsync(CITY_ID),
          countryId: getIntAsync(COUNTRY_ID),
          orderStatus: statusList[selectedStatusIndex],
        )
        .then((value) {
          appStore.setAllUnreadCount(value.allUnreadCount.validate());
          currentPage = value.pagination!.currentPage!;
          totalPage = value.pagination!.totalPages!;
          final bool isFirstPage = currentPage == 1;
          final String activeStatus = statusList[selectedStatusIndex];
          final List<OrderData> fetched = value.data ?? [];
          if (activeStatus == ORDER_DELIVERED) {
            if (fetched.isNotEmpty) {
              fetched.sort((a, b) => (b.id ?? 0).compareTo(a.id ?? 0));
              orderData
                ..clear()
                ..add(fetched.first);
            } else {
              orderData.clear();
            }
            currentPage = 1;
            totalPage = 1;
          } else {
            _mergeOrdersWithoutDuplicates(fetched, resetExisting: isFirstPage);
          }
          setState(() {});
        })
        .catchError((error) {
          log(error.toString());
        })
        .whenComplete(() {
          if (shouldShowLoader) {
            appStore.setLoading(false);
          }
          _isFetchingOrders = false;
        });
  }

  Future<void> cancelOrder(OrderData order) async {
    appStore.setLoading(true);
    List<dynamic> cancelledDeliverManIds = order.cancelledDeliverManIds ?? [];
    cancelledDeliverManIds.add(getIntAsync(USER_ID));
    Map req = {
      "id": order.id,
      "cancelled_delivery_man_ids": cancelledDeliverManIds,
    };
    await cancelAutoAssignOrder(req)
        .then((value) {
          appStore.setLoading(false);
          toast(value.message);
          getOrderListApiCall();
        })
        .catchError((error) {
          appStore.setLoading(false);
          toast(error.toString());
        });
  }

  @override
  void setState(fn) {
    if (mounted) super.setState(fn);
  }

  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    positionStream?.cancel();
    _ordersAutoRefreshTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CommonScaffoldComponent(
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(70),
        child: commonAppBarWidget(
          '${language.hey} ${getStringAsync(NAME)} 👋',
          showBack: false,
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: DriverOnlineToggle(
                isOnline: isDriverOnline,
                onChanged: onOnlineStatusChanged,
              ),
            ),
            Container(
              margin: .symmetric(vertical: 12, horizontal: 4),
              padding: .symmetric(horizontal: 8, vertical: 4),
              decoration: boxDecorationWithRoundedCorners(
                borderRadius: radius(defaultRadius),
                backgroundColor: Colors.white24,
              ),
              child:
                  Row(
                    children: [
                      Icon(
                        Ionicons.ios_location_outline,
                        color: Colors.white,
                        size: 16,
                      ),
                      6.width,
                      Text(
                        CityModel.fromJson(
                          getJSONAsync(CITY_DATA),
                        ).name.validate(),
                        style: primaryTextStyle(color: white, size: 12),
                      ),
                    ],
                  ).onTap(
                    () {
                      UserCitySelectScreen(
                        isBack: true,
                        onUpdate: () {
                          currentPage = 1;
                          getOrderListApiCall(showLoader: true);
                          setState(() {});
                        },
                      ).launch(context);
                    },
                    highlightColor: Colors.transparent,
                    hoverColor: Colors.transparent,
                    splashColor: Colors.transparent,
                  ),
            ),
            Stack(
              clipBehavior: Clip.none,
              children: [
                Align(
                  alignment: AlignmentDirectional.center,
                  child: Icon(
                    Ionicons.md_notifications_outline,
                    color: Colors.white,
                  ),
                ),
                Observer(
                  builder: (context) {
                    return Positioned(
                      right: 0,
                      top: 2,
                      child: Container(
                        height: 20,
                        width: 20,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: Colors.orange,
                          shape: BoxShape.circle,
                        ),
                        child: Text(
                          '${appStore.allUnreadCount < 99 ? appStore.allUnreadCount : '99+'}',
                          style: primaryTextStyle(
                            size: appStore.allUnreadCount < 99 ? 12 : 8,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ).visible(appStore.allUnreadCount != 0);
                  },
                ),
              ],
            ).withWidth(30).onTap(() {
              NotificationScreen().launch(context);
            }),
            IconButton(
              onPressed: () async {
                DHomeFragment().launch(
                  context,
                  pageRouteAnimation: PageRouteAnimation.Fade,
                  isNewTask: true,
                );
              },
              icon: Icon(Ionicons.stats_chart_outline, color: Colors.white),
            ),
            IconButton(
              padding: .only(right: 8),
              onPressed: () async {
                DProfileFragment().launch(
                  context,
                  pageRouteAnimation: PageRouteAnimation.Fade,
                );
              },
              icon: Icon(Ionicons.settings_outline, color: Colors.white),
            ),
          ],
        ),
      ),
      body: Stack(
        children: [
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFFF8FAFC), Color(0xFFEFF6FF)],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
            child: Column(
              children: [
                _buildStatusFlowStrip(),
                _buildTripRouteFilterBar(),
                Expanded(
                  child: Stack(
                    children: [
                      PageView(
                        controller: pageController,
                        physics: const NeverScrollableScrollPhysics(),
                        onPageChanged: (value) {
                          selectedStatusIndex = value;
                          currentPage = 1;
                          orderData.clear();
                          if (_isProgrammaticStatusTransition) {
                            _isProgrammaticStatusTransition = false;
                            setState(() {});
                            return;
                          }
                          getOrderListApiCall(showLoader: true);
                          setState(() {});
                        },
                        children: statusList.map((e) {
                          final List<OrderData> visibleOrders =
                              _visibleOrdersForCurrentTab();
                          return Stack(
                            children: [
                              AnimatedListView(
                                itemCount: visibleOrders.length,
                                shrinkWrap: true,
                                physics: BouncingScrollPhysics(),
                                listAnimationType: ListAnimationType.Slide,
                                padding: .only(
                                  left: 16,
                                  right: 16,
                                  top: 14,
                                  bottom: 70,
                                ),
                                flipConfiguration: FlipConfiguration(
                                  duration: Duration(milliseconds: 500),
                                  curve: Curves.fastOutSlowIn,
                                ),
                                fadeInConfiguration: FadeInConfiguration(
                                  duration: Duration(milliseconds: 500),
                                  curve: Curves.fastOutSlowIn,
                                ),
                                onNextPage: () {
                                  if (currentPage < totalPage) {
                                    currentPage++;
                                    setState(() {});
                                    getOrderListApiCall();
                                  }
                                },
                                onSwipeRefresh: () async {
                                  currentPage = 1;
                                  try {
                                    final value = await getAppSetting();
                                    appStore.setOtpVerifyOnPickupDelivery(
                                      value.otpVerifyOnPickupDelivery == 1,
                                    );
                                    appStore.setCurrencyCode(
                                      value.currencyCode ?? CURRENCY_CODE,
                                    );
                                    appStore.setCurrencySymbol(
                                      value.currency ?? CURRENCY_SYMBOL,
                                    );
                                    appStore.setCurrencyPosition(
                                      value.currencyPosition ??
                                          CURRENCY_POSITION_LEFT,
                                    );
                                    appStore.isVehicleOrder =
                                        value.isVehicleInOrder ?? 0;
                                    appStore.setSiteEmail(
                                      value.siteEmail ?? "",
                                    );
                                    appStore.setCopyRight(
                                      value.siteCopyright ?? "",
                                    );
                                    appStore.setIsInsuranceAllowed(
                                      value.isInsuranceAllowed ?? "0",
                                    );
                                    appStore.setInsurancePercentage(
                                      value.insurancePercentage ?? "0",
                                    );
                                    appStore.setInsuranceDescription(
                                      value.insuranceDescription ?? "",
                                    );
                                    appStore.setMaxAmountPerMonth(
                                      value.maxEarningsPerMonth ?? '',
                                    );
                                    appStore.setClaimDuration(
                                      value.claimDuration ?? '',
                                    );
                                  } catch (error) {
                                    log(error.toString());
                                  }
                                  getOrderListApiCall(showLoader: true);
                                  return Future.value(true);
                                },
                                itemBuilder: (context, i) {
                                  OrderData item = visibleOrders[i];
                                  return orderCard(item);
                                },
                              ).visible(visibleOrders.isNotEmpty),
                              loaderWidget().visible(appStore.isLoading),
                              emptyWidget().visible(
                                visibleOrders.isEmpty && !appStore.isLoading,
                              ),
                            ],
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            left: 14,
            bottom: 14,
            child: SizedBox(
              height: 48,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: DriverPalette.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(26),
                  ),
                ),
                onPressed: _openMapView,
                icon: const Icon(Icons.map_outlined, size: 18),
                label: Text(
                  'Map View',
                  style: boldTextStyle(color: Colors.white, size: 14),
                ),
              ),
            ),
          ),
          Positioned(
            right: 14,
            bottom: _canOpenCrispChat ? 86 : 14,
            child: SizedBox(
              height: 48,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0F766E),
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: const Color(0xFF94A3B8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(26),
                  ),
                ),
                onPressed: _isOpeningOngoingOrder
                    ? null
                    : _openOngoingDeliveryJob,
                icon: _isOpeningOngoingOrder
                    ? const SizedBox(
                        width: 16,
                        height: 16,
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
                  style: boldTextStyle(color: Colors.white, size: 14),
                ),
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: (_canOpenCrispChat)
          ? FloatingActionButton(
              onPressed: () async {
                await openCrispSupportChat();
              },
              backgroundColor: ColorUtils.colorPrimary,
              child: CachedNetworkImage(
                imageUrl: crispChatIcon ?? "",
                errorWidget: (context, url, error) =>
                    const Icon(Icons.chat_bubble_outline),
              ),
            ).paddingAll(10)
          : null,
      floatingActionButtonLocation: FloatingActionButtonLocation.endDocked,
    );
  }

  static const List<String> _stageProgressLabels = [
    'Pending',
    'Assigned',
    'Accepted',
    'Arrived',
    'Picked Up',
    'Departed',
    'Delivered',
  ];

  int _progressIndexForStatus(String status) {
    switch (status) {
      case ORDER_CREATED:
      case ORDER_PENDING:
        return 0;
      case ORDER_ASSIGNED:
        return 1;
      case ORDER_ACCEPTED:
        return 2;
      case ORDER_ARRIVED:
        return 3;
      case ORDER_PICKED_UP:
        return 4;
      case ORDER_DEPARTED:
        return 5;
      case ORDER_DELIVERED:
      case ORDER_SHIPPED:
        return 6;
      default:
        return 0;
    }
  }

  String _stageHeadline(String status) {
    switch (status) {
      case ORDER_CREATED:
      case ORDER_PENDING:
        return 'New delivery request';
      case ORDER_ASSIGNED:
        return 'Pickup assigned';
      case ORDER_ACCEPTED:
        return 'Proceed to pickup';
      case ORDER_ARRIVED:
        return 'Arrived at pickup point';
      case ORDER_PICKED_UP:
        return 'Parcel picked up';
      case ORDER_DEPARTED:
        return 'On the way to drop-off';
      case ORDER_DELIVERED:
        return 'Delivery completed';
      case ORDER_CANCELLED:
        return 'Delivery cancelled';
      case ORDER_SHIPPED:
        return 'Marked as shipped';
      default:
        return 'Delivery update';
    }
  }

  String _distanceLabel(OrderData data) {
    final double? distance = safeToDouble(data.totalDistance);
    if (distance == null || distance <= 0) return 'Distance unavailable';
    return '${distance.toStringAsFixed(distance >= 10 ? 0 : 1)} km away';
  }

  String _stageSubtitle(String status, OrderData data) {
    switch (status) {
      case ORDER_CREATED:
      case ORDER_PENDING:
        return _distanceLabel(data);
      case ORDER_ASSIGNED:
        return 'Ready to accept this request';
      case ORDER_ACCEPTED:
        return 'Customer is waiting at pickup';
      case ORDER_ARRIVED:
        return 'Confirm pickup to move ahead';
      case ORDER_PICKED_UP:
        return 'Depart when parcel handover is complete';
      case ORDER_DEPARTED:
        return 'Complete handover at destination';
      case ORDER_DELIVERED:
        return 'Trip closed successfully';
      case ORDER_CANCELLED:
        return 'This request is no longer active';
      case ORDER_SHIPPED:
        return 'Handed over for shipment';
      default:
        return _distanceLabel(data);
    }
  }

  String _serviceLabel(OrderData data) {
    final String parcelType = data.parcelType.validate();
    if (parcelType.isNotEmpty) return parcelType;
    final String cityName = data.cityName.validate();
    if (cityName.isNotEmpty) return cityName;
    return 'NadaRuns';
  }

  String _ratingLabel(OrderData data) {
    final int? rating = data.ratingDetail?.rating;
    if (rating == null || rating == 0) return '4.8';
    return rating.toStringAsFixed(1);
  }

  bool _showDropoffPulse(String status) {
    return status == ORDER_PICKED_UP ||
        status == ORDER_DEPARTED ||
        status == ORDER_DELIVERED;
  }

  String _statusFlowLabel(String status) {
    switch (status) {
      case ORDER_CREATED:
      case ORDER_PENDING:
        return 'Request';
      case ORDER_ASSIGNED:
        return 'Assigned';
      case ORDER_ACCEPTED:
        return 'Accepted';
      case ORDER_ARRIVED:
        return 'Arrived';
      case ORDER_PICKED_UP:
        return 'Picked';
      case ORDER_DEPARTED:
        return 'En route';
      case ORDER_DELIVERED:
        return 'Done';
      default:
        return orderStatus(status);
    }
  }

  IconData _mainActionIcon(String status) {
    switch (status) {
      case ORDER_CREATED:
      case ORDER_PENDING:
      case ORDER_ASSIGNED:
        return Icons.check_circle_outline;
      case ORDER_ACCEPTED:
      case ORDER_ARRIVED:
        return Icons.inventory_2_outlined;
      case ORDER_PICKED_UP:
        return Icons.route_outlined;
      case ORDER_DEPARTED:
        return Icons.verified_outlined;
      default:
        return Icons.play_arrow_rounded;
    }
  }

  bool _shouldShowMainActionForStatus(String status) {
    return _isSequentiallyManagedStatus(status) &&
        status != ORDER_DELIVERED &&
        status != ORDER_CANCELLED &&
        status != ORDER_SHIPPED;
  }

  Future<void> _switchStatusTab(int index) async {
    if (index < 0 || index >= statusList.length) return;
    if (index == selectedStatusIndex) return;
    _isProgrammaticStatusTransition = true;
    selectedStatusIndex = index;
    currentPage = 1;
    orderData.clear();
    if (pageController.hasClients) {
      pageController.jumpToPage(index);
    }
    setState(() {});
    await getOrderListApiCall(showLoader: true);
  }

  Widget _buildStatusFlowStrip() {
    return Container(
      margin: const EdgeInsets.fromLTRB(14, 8, 14, 0),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.96),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: DriverPalette.cardBorder),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        child: Row(
          children: List.generate(statusList.length, (index) {
            final String status = statusList[index];
            final bool isSelected = index == selectedStatusIndex;
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: InkWell(
                borderRadius: BorderRadius.circular(999),
                onTap: () => _switchStatusTab(index),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 9,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: isSelected ? DriverPalette.surface : Colors.white,
                    borderRadius: BorderRadius.circular(9999),
                    border: Border.all(
                      color: isSelected
                          ? DriverPalette.surface
                          : DriverPalette.cardBorder,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 16,
                        height: 16,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: isSelected
                              ? Colors.white.withValues(alpha: 0.2)
                              : DriverPalette.primary.withValues(alpha: 0.12),
                          shape: BoxShape.circle,
                        ),
                        child: Text(
                          '${index + 1}',
                          style: TextStyle(
                            color: isSelected
                                ? Colors.white
                                : DriverPalette.primary,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(width: 5),
                      Text(
                        _statusFlowLabel(status),
                        style: TextStyle(
                          color: isSelected
                              ? Colors.white
                              : const Color(0xFF475569),
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
        ),
      ),
    );
  }

  String _orderRef(OrderData data) {
    return data.id != null ? '#${data.id}' : '#--';
  }

  Widget _locationDetailTile({
    required String label,
    required String address,
    required bool isPickup,
    bool showConnector = false,
    VoidCallback? onCall,
  }) {
    final Color pinColor = isPickup
        ? const Color(0xFF16A34A)
        : DriverPalette.primary;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 18,
          child: Column(
            children: [
              Container(
                margin: const EdgeInsets.only(top: 7),
                width: 9,
                height: 9,
                decoration: BoxDecoration(
                  color: pinColor,
                  shape: BoxShape.circle,
                ),
              ),
              if (showConnector)
                Container(
                  margin: const EdgeInsets.symmetric(vertical: 4),
                  width: 2,
                  height: 24,
                  color: DriverPalette.cardBorder,
                ),
            ],
          ),
        ),
        const SizedBox(width: 7),
        Expanded(
          child: Container(
            margin: const EdgeInsets.only(bottom: 4),
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(10, 8, 9, 8),
            decoration: BoxDecoration(
              color: DriverPalette.softBackground,
              borderRadius: BorderRadius.circular(11),
              border: Border.all(color: DriverPalette.cardBorder),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        style: secondaryTextStyle(
                          size: 11,
                          weight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        address,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: boldTextStyle(size: 13),
                      ),
                    ],
                  ),
                ),
                if (onCall != null)
                  InkWell(
                    borderRadius: BorderRadius.circular(999),
                    onTap: onCall,
                    child: Container(
                      padding: const EdgeInsets.all(5),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(color: DriverPalette.cardBorder),
                      ),
                      child: const Icon(Icons.call_outlined, size: 14),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget orderCard(OrderData data) {
    final String itemStatus = data.status.validate();
    final bool canNavigate =
        itemStatus != ORDER_DELIVERED &&
        itemStatus != ORDER_CANCELLED &&
        itemStatus != ORDER_SHIPPED;
    final bool canCancel = itemStatus == ORDER_ASSIGNED;
    final bool showMainAction = _shouldShowMainActionForStatus(itemStatus);
    final Color stageColor = driverStatusColor(itemStatus);
    final String primaryActionText = buttonText(itemStatus);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: DriverStageShell(
        onTap: null,
        header: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF05070D), Color(0xFF131726)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 9,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      _serviceLabel(data),
                      style: primaryTextStyle(
                        color: Colors.white,
                        size: 11,
                        weight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 9,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      'Flow ${_progressIndexForStatus(itemStatus) + 1}/${_stageProgressLabels.length}',
                      style: primaryTextStyle(
                        color: Colors.white,
                        size: 10,
                        weight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const Spacer(),
                  DriverStatusChip(
                    label: orderStatus(itemStatus),
                    color: stageColor,
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                _stageHeadline(itemStatus),
                style: boldTextStyle(color: Colors.white, size: 20),
              ),
              const SizedBox(height: 2),
              Text(
                _stageSubtitle(itemStatus, data),
                style: primaryTextStyle(color: Colors.white70, size: 13),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(
                    Icons.local_shipping_outlined,
                    size: 12,
                    color: Colors.white70,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Order ${_orderRef(data)}',
                    style: primaryTextStyle(color: Colors.white70, size: 11),
                  ),
                  const Spacer(),
                  const Icon(
                    Icons.place_outlined,
                    size: 12,
                    color: Colors.white70,
                  ),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(
                      _distanceLabel(data),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.end,
                      style: primaryTextStyle(color: Colors.white70, size: 11),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        mapPreview: Stack(
          children: [
            DriverRoutePreview(
              routeColor: stageColor,
              showDropoffPulse: _showDropoffPulse(itemStatus),
            ),
            Positioned(
              top: 8,
              left: 10,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.92),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: DriverPalette.cardBorder),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    Icon(
                      Icons.route_outlined,
                      size: 12,
                      color: Color(0xFF334155),
                    ),
                    SizedBox(width: 4),
                    Text(
                      'Live route',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF334155),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Positioned(
              right: 10,
              bottom: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: DriverPalette.surface.withValues(alpha: 0.82),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  _statusFlowLabel(itemStatus),
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 10,
                  ),
                ),
              ),
            ),
          ],
        ),
        details: Container(
          color: Colors.white,
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      data.clientName.validate().isNotEmpty
                          ? data.clientName.validate()
                          : 'Customer',
                      style: boldTextStyle(size: 21),
                    ),
                  ),
                  const Icon(Icons.star, size: 16, color: Color(0xFF111827)),
                  const SizedBox(width: 4),
                  Text(_ratingLabel(data), style: boldTextStyle(size: 15)),
                ],
              ),
              const SizedBox(height: 10),
              DriverStepProgress(
                currentIndex: _progressIndexForStatus(itemStatus),
                labels: _stageProgressLabels,
                icons: const [
                  Icons.search_outlined,
                  Icons.assignment_ind_outlined,
                  Icons.check_circle_outline,
                  Icons.place_outlined,
                  Icons.inventory_2_outlined,
                  Icons.local_shipping_outlined,
                  Icons.task_alt_outlined,
                ],
                statusColors: const [
                  Color(0xFFF59E0B),
                  Color(0xFF8B5CF6),
                  Color(0xFF2563EB),
                  Color(0xFF0EA5E9),
                  Color(0xFF06B6D4),
                  Color(0xFF4F46E5),
                  Color(0xFF10B981),
                ],
              ),
              const SizedBox(height: 10),
              _locationDetailTile(
                label: 'Pickup',
                address: data.pickupPoint?.address.validate() ?? '-',
                isPickup: true,
                showConnector: true,
                onCall: data.pickupPoint?.contactNumber != null
                    ? () => commonLaunchUrl(
                        'tel:${data.pickupPoint!.contactNumber}',
                      )
                    : null,
              ),
              _locationDetailTile(
                label: 'Drop-off',
                address: data.deliveryPoint?.address.validate() ?? '-',
                isPickup: false,
                onCall: data.deliveryPoint?.contactNumber != null
                    ? () => commonLaunchUrl(
                        'tel:${data.deliveryPoint!.contactNumber}',
                      )
                    : null,
              ),
              const SizedBox(height: 5),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  DriverMetricPill(
                    icon: Icons.inventory_2_outlined,
                    label: 'Parcel',
                    value: data.parcelType.validate().isNotEmpty
                        ? data.parcelType.validate()
                        : 'Standard',
                  ),
                  DriverMetricPill(
                    icon: Icons.payments_outlined,
                    label: 'Amount',
                    value: printAmount(data.totalAmount ?? 0),
                  ),
                  DriverMetricPill(
                    icon: Icons.route_outlined,
                    label: 'Distance',
                    value: _tripDistanceMetric(data),
                  ),
                ],
              ),
              if (data.reScheduleDateTime != null) ...[
                const SizedBox(height: 8),
                Text(
                  '${language.note} ${language.rescheduleMsg} ${DateFormat('yyyy-MM-dd').format(DateTime.parse(data.reScheduleDateTime!))}',
                  style: secondaryTextStyle(color: Colors.red, size: 12),
                ),
              ],
              const SizedBox(height: 10),
              if (showMainAction && primaryActionText.isNotEmpty)
                DriverPrimaryButton(
                  label: primaryActionText,
                  leading: _mainActionIcon(itemStatus),
                  onTap: () => _handleOrderActionTap(data),
                )
              else
                Container(
                  width: double.infinity,
                  alignment: Alignment.center,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE2E8F0),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    orderStatus(itemStatus),
                    style: boldTextStyle(size: 13),
                  ),
                ),
              if (canNavigate || canCancel) ...[
                const SizedBox(height: 7),
                Row(
                  children: [
                    if (canNavigate)
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => onTapNavigation(data),
                          icon: const Icon(Icons.navigation_outlined, size: 18),
                          label: const Text('Navigate'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: DriverPalette.primary,
                            side: const BorderSide(
                              color: DriverPalette.primary,
                            ),
                            backgroundColor: DriverPalette.softBackground,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(11),
                            ),
                          ),
                        ),
                      ),
                    if (canNavigate && canCancel) const SizedBox(width: 8),
                    if (canCancel)
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () async {
                            showConfirmDialogCustom(
                              context,
                              primaryColor: Colors.red,
                              dialogType: DialogType.CONFIRMATION,
                              title: language.orderCancelConfirmation,
                              positiveText: language.yes,
                              negativeText: language.no,
                              onAccept: (c) async {
                                await cancelOrder(data);
                              },
                            );
                          },
                          icon: const Icon(Icons.close, size: 18),
                          label: Text(language.cancel),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.red,
                            side: const BorderSide(color: Colors.red),
                            backgroundColor: const Color(0xFFFFF1F2),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(11),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ],
              if (itemStatus == ORDER_ACCEPTED) ...[
                const SizedBox(height: 4),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () async {
                      appStore.setLoading(true);
                      bool movedToArrived = false;
                      try {
                        await updateOrder(
                          orderStatus: ORDER_ARRIVED,
                          orderId: data.id,
                        );
                        toast(language.orderArrived);
                        movedToArrived = true;
                      } catch (e) {
                        toast(e.toString());
                      }
                      appStore.setLoading(false);
                      if (movedToArrived) {
                        await _moveToStatusAndRefresh(ORDER_ARRIVED);
                      }
                    },
                    child: Text(
                      language.notifyUser,
                      style: primaryTextStyle(color: DriverPalette.primary),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Future<void> onTapData({
    required String orderStatus,
    required OrderData orderData,
  }) async {
    FlutterRingtonePlayer().stop();
    try {
      if (orderStatus == ORDER_CREATED || orderStatus == ORDER_PENDING) {
        Map req = {'order_id': orderData.id, 'status': ORDER_ASSIGNED};
        final value = await updateOrderStatusForAssignedTab(req);
        if (value.success == false) {
          toast(value.message);
          appStore.setLoading(false);
          setState(() {});
        } else {
          print("---------res${value.message}");
          await _moveToStatusAndRefresh(ORDER_ASSIGNED);
        }
      } else if (orderStatus == ORDER_ASSIGNED) {
        await updateOrder(orderStatus: ORDER_ACCEPTED, orderId: orderData.id);
        await _moveToStatusAndRefresh(ORDER_ACCEPTED);
      } else if (orderStatus == ORDER_ACCEPTED) {
        if (_isPickupBlockedBySchedule(orderData)) {
          toast(language.earlyPickupMsg);
          return;
        }

        final bool isCheck = await _openReceivedOrderScreen(
          orderData,
          isShowPayment:
              (orderData.paymentId == null || orderData.paymentId == 0) &&
              orderData.paymentCollectFrom == PAYMENT_ON_PICKUP,
        );
        if (isCheck) {
          await _moveToStatusAndRefresh(ORDER_PICKED_UP);
        }
      } else if (orderStatus == ORDER_ARRIVED) {
        final bool isCheck = await _openReceivedOrderScreen(
          orderData,
          isShowPayment:
              (orderData.paymentId == null || orderData.paymentId == 0) &&
              orderData.paymentCollectFrom == PAYMENT_ON_PICKUP,
        );
        if (isCheck) {
          await _moveToStatusAndRefresh(ORDER_PICKED_UP);
        }
      } else if (orderStatus == ORDER_PICKED_UP) {
        await updateOrder(orderStatus: ORDER_DEPARTED, orderId: orderData.id);
        toast(language.orderDepartedSuccessfully);
        await _moveToStatusAndRefresh(ORDER_DEPARTED);
      } else if (orderStatus == ORDER_DEPARTED) {
        if (_isDeliveryBlockedBySchedule(orderData)) {
          toast(language.earlyDeliveryMsg);
          return;
        }

        final bool isCheck = await _openReceivedOrderScreen(
          orderData,
          isShowPayment:
              (orderData.paymentId == null || orderData.paymentId == 0) &&
              orderData.paymentCollectFrom == PAYMENT_ON_DELIVERY,
        );
        if (isCheck) {
          await _moveToStatusAndRefresh(ORDER_DELIVERED);
        }
      }
    } catch (e) {
      toast(e.toString());
    }
  }

  buttonText(String orderStatus) {
    if (orderStatus == ORDER_CREATED ||
        orderStatus == ORDER_PENDING ||
        orderStatus == ORDER_ASSIGNED) {
      return language.accept;
    } else if (orderStatus == ORDER_ACCEPTED) {
      return language.pickUp;
    } else if (orderStatus == ORDER_ARRIVED) {
      return language.pickUp;
    } else if (orderStatus == ORDER_PICKED_UP) {
      return language.departed;
    } else if (orderStatus == ORDER_DEPARTED) {
      return language.confirmDelivery;
    }
    return '';
  }
}
