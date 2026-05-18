import 'dart:convert';
import 'dart:core';
import 'package:country_code_picker/country_code_picker.dart';
import 'package:date_time_picker/date_time_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:intl/intl.dart';
import 'package:nadaruns_delivery/extensions/colors.dart';
import '../../extensions/extension_util/context_extensions.dart';
import '../../extensions/extension_util/int_extensions.dart';
import '../../extensions/extension_util/num_extensions.dart';
import '../../extensions/extension_util/string_extensions.dart';
import '../../extensions/extension_util/widget_extensions.dart';
import '../../main/models/CouponListResponseModel.dart';
import '../../main/models/PlaceAddressModel.dart';
import '../../main/screens/CouponListScreen.dart';
import '../../main/utils/DataProviders.dart';
import '../../user/screens/insurance_details_screen.dart';
import '../../user/screens/packaging_symbols_info.dart';
import 'package:percent_indicator/circular_percent_indicator.dart';
import '../../extensions/app_button.dart';
import '../../extensions/app_text_field.dart';
import '../../extensions/common.dart';
import '../../extensions/confirmation_dialog.dart';
import '../../extensions/decorations.dart';
import '../../extensions/shared_pref.dart';
import '../../extensions/system_utils.dart';
import '../../extensions/text_styles.dart';
import '../../extensions/widgets.dart';
import '../../main.dart';
import '../../main/components/CommonScaffoldComponent.dart';
import '../../main/components/OrderAmountSummaryWidget.dart';
import '../../main/components/PickAddressBottomSheet.dart';
import '../../main/models/CountryListModel.dart';
import '../../main/models/CreateOrderDetailModel.dart';
import '../../main/models/ExtraChargeRequestModel.dart';
import '../../main/models/OrderListModel.dart';
import '../../main/models/PaymentModel.dart';
import '../../main/models/TotalAmountResponse.dart';
import '../../main/models/VehicleModel.dart';
import '../../main/network/RestApis.dart';
import '../../main/utils/Common.dart';
import '../../main/utils/Constants.dart';
import '../../main/utils/Images.dart';
import '../../main/utils/Widgets.dart';
import '../../main/utils/dynamic_theme.dart';
import '../../user/components/CreateOrderConfirmationDialog.dart';
import '../../user/screens/DashboardScreen.dart';
import 'GoogleMapScreen.dart';
import 'PaymentScreen.dart';

class CreateOrderScreen extends StatefulWidget {
  final OrderData? orderData;

  CreateOrderScreen({this.orderData});

  @override
  CreateOrderScreenState createState() => CreateOrderScreenState();
}

class CreateOrderScreenState extends State<CreateOrderScreen> {
  GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  CityDetail? cityData;
  List<StaticDetails> parcelTypeList = [];

  TextEditingController parcelTypeCont = TextEditingController();
  TextEditingController weightController = TextEditingController(text: '1');
  TextEditingController totalParcelController = TextEditingController(
    text: '1',
  );

  TextEditingController pickAddressCont = TextEditingController();
  TextEditingController pickPersonNameCont = TextEditingController();
  TextEditingController pickPhoneCont = TextEditingController();
  TextEditingController pickDesCont = TextEditingController();
  TextEditingController pickInstructionCont = TextEditingController();
  TextEditingController pickDateController = TextEditingController();
  TextEditingController pickFromTimeController = TextEditingController();
  TextEditingController pickToTimeController = TextEditingController();

  TextEditingController deliverAddressCont = TextEditingController();
  TextEditingController deliverPhoneCont = TextEditingController();
  TextEditingController deliverPersonNameCont = TextEditingController();
  TextEditingController deliverDesCont = TextEditingController();
  TextEditingController deliverInstructionCont = TextEditingController();
  TextEditingController deliverDateController = TextEditingController();
  TextEditingController deliverFromTimeController = TextEditingController();
  TextEditingController deliverToTimeController = TextEditingController();
  TextEditingController insuranceAmountController = TextEditingController();

  FocusNode pickPhoneFocus = FocusNode();
  FocusNode pickPersonNameFocus = FocusNode();
  FocusNode pickDesFocus = FocusNode();
  FocusNode pickInstructionFocus = FocusNode();
  FocusNode deliveryPesonNameFocus = FocusNode();
  FocusNode deliverPhoneFocus = FocusNode();
  FocusNode deliveryInstructionFocus = FocusNode();
  FocusNode deliverDesFocus = FocusNode();

  String deliverCountryCode = defaultPhoneCode;
  String pickupCountryCode = defaultPhoneCode;

  DateTime? pickFromDateTime,
      pickToDateTime,
      deliverFromDateTime,
      deliverToDateTime;
  DateTime? pickDate, deliverDate;
  TimeOfDay? pickFromTime, pickToTime, deliverFromTime, deliverToTime;

  String? pickLat, pickLong, deliverLat, deliverLong;

  int selectedTabIndex = 0;

  bool isDeliverNow = true;
  int isSelected = 1;

  bool? isCash = false;

  String paymentCollectFrom = PAYMENT_ON_PICKUP;
  TotalAmountResponse? totalAmountResponse;

  DateTime? currentBackPressTime;
  num totalDistance = 0;
  List<UseraddressDetail> addressList = [];
  UseraddressDetail? pickAddressData;
  UseraddressDetail? deliveryAddressData;
  num weightCharge = 0;
  num distanceCharge = 0;
  num totalExtraCharge = 0;
  num insuranceAmount = 0.0;
  num vehicleCharge = 0.0;

  List<PaymentModel> mPaymentList = getPaymentItems();

  List<ExtraChargeRequestModel> extraChargeList = [];

  int? selectedVehicle;
  List<VehicleDetail> vehicleList = [];
  VehicleData? vehicleData;
  List<Marker> markers = [];
  GoogleMapController? googleMapController;
  Set<Polyline> _polylines = {};
  List<LatLng> polylineCoordinates = [];
  final List<Map<String, String>> selectedPackingSymbols = [];
  final List<Map<String, String>> packingSymbolsItems = getPackagingSymbols();
  int insuranceSelectedOption = 1;
  List<String> appBarTitleList = [
    language.createOrder,
    language.pickupInformation,
    language.deliveryInformation,
    language.reviewRoute,
    language.details,
  ];
  CouponListResponseModel? couponListResponseModel;
  CouponModel? selectedCoupon;
  bool isAppliedCoupon = false;
  bool biddingSelectedOption = false;
  var getAddressData;
  final List<TextEditingController> _stepProgressControllers = [];

  void _onStepProgressChanged() {
    if (mounted) setState(() {});
  }

  void _attachStepProgressListeners() {
    _stepProgressControllers.addAll([
      parcelTypeCont,
      weightController,
      totalParcelController,
      pickAddressCont,
      pickPhoneCont,
      pickPersonNameCont,
      pickDateController,
      pickFromTimeController,
      pickToTimeController,
      deliverAddressCont,
      deliverPhoneCont,
      deliverPersonNameCont,
      deliverDateController,
      deliverFromTimeController,
      deliverToTimeController,
      insuranceAmountController,
    ]);
    for (final controller in _stepProgressControllers) {
      controller.addListener(_onStepProgressChanged);
    }
  }

  void _detachStepProgressListeners() {
    for (final controller in _stepProgressControllers) {
      controller.removeListener(_onStepProgressChanged);
    }
    _stepProgressControllers.clear();
  }

  @override
  void initState() {
    super.initState();
    _attachStepProgressListeners();
    afterBuildCreated(() {
      init();
    });
  }

  @override
  void dispose() {
    _detachStepProgressListeners();
    super.dispose();
  }

  getStaticDetailsForOrder() async {
    await getCreateOrderDetails(getIntAsync(CITY_ID))
        .then((value) async {
          appStore.setLoading(false);
          await setValue(CITY_DATA, value.cityDetail!.toJson());
          cityData = value.cityDetail;
          value.useraddressDetail!.forEach((element) {
            addressList.add(element);
          });
          if (addressList.isNotEmpty) {
            pickAddressData = addressList.first;
            deliveryAddressData = addressList.first;
          }
          List<UseraddressDetail> list = [];
          addressList.forEach((e) {
            list.add(e);
          });
          setValue(
            RECENT_ADDRESS_LIST,
            list.map((element) => jsonEncode(element)).toList(),
          );
          vehicleList.clear();
          vehicleList = value.vehicleDetail!;
          if (value.vehicleDetail!.isNotEmpty)
            selectedVehicle = value.vehicleDetail![0].id;
          parcelTypeList.clear();
          parcelTypeList.addAll(value.staticDetails!);
          appStore.setCurrencyCode(
            value.appSettingDetail!.currencyCode ?? CURRENCY_CODE,
          );
          appStore.setCurrencySymbol(
            value.appSettingDetail!.currency ?? CURRENCY_SYMBOL,
          );
          appStore.setCurrencyPosition(
            value.appSettingDetail!.currencyPosition ?? CURRENCY_POSITION_LEFT,
          );
          appStore.setIsInsuranceAllowed(
            value.appSettingDetail!.isInsuranceAllow.toString(),
          );
          appStore.setInsurancePercentage(
            value.appSettingDetail!.insurancePercentage.toString(),
          );
          appStore.setInsuranceDescription(
            value.appSettingDetail!.insuranceDescription.toString(),
          );
          appStore.setIsBiddingStatus(
            value.appSettingDetail!.isBiddingEnabled.toString(),
          );
          appStore.isVehicleOrder =
              value.appSettingDetail!.isVehicleInOrder ?? 0;
          appStore.setIsSmsOrder(value.appSettingDetail!.isSmsOrder ?? 0);
          print("------------isSmsOrder${appStore.isSmsOrder}");
          setState(() {});
        })
        .catchError((error, trace) {
          appStore.setLoading(false);
          debugPrint("User facing Error ${error} Trace ${trace}");
          toast(error.toString());
        });
  }

  getCouponList() async {
    try {
      await getCouponListApi(1).then((value) async {
        couponListResponseModel = value;
        if (value.data != null && value.data!.isNotEmpty) {
          selectedCoupon = value.data!.first;
          log("SELECTED COUPON LEN::::::: ${selectedCoupon}");
        } else {
          selectedCoupon = null;
          log("VALUE OF SELECTEDCOUPON IS::::::::::: ${selectedCoupon}");
        }
      });
    } catch (e, s) {
      log("COUPON ERROR ${e} STACK TRACE ${s}");
    }
  }

  Future<void> init() async {
    try {
      pickupCountryCode =
          CountryModel.fromJson(getJSONAsync(COUNTRY_DATA)).code.isEmptyOrNull
          ? defaultPhoneCode
          : CountryModel.fromJson(getJSONAsync(COUNTRY_DATA)).code.validate();
      deliverCountryCode =
          CountryModel.fromJson(getJSONAsync(COUNTRY_DATA)).code.isEmptyOrNull
          ? defaultPhoneCode
          : CountryModel.fromJson(getJSONAsync(COUNTRY_DATA)).code.validate();
      await getStaticDetailsForOrder();
      getAddressData = await getAddressList(page: 1);
      await getCouponList();
      if (widget.orderData != null) {
        if (widget.orderData!.totalWeight != 0)
          weightController.text = widget.orderData!.totalWeight!.toString();
        if (widget.orderData!.totalParcel != null)
          totalParcelController.text = widget.orderData!.totalParcel!
              .toString();
        parcelTypeCont.text = widget.orderData!.parcelType.validate();

        pickAddressCont.text = widget.orderData!.pickupPoint!.address
            .validate();
        pickPersonNameCont.text = widget.orderData!.pickupPoint!.name
            .validate();
        deliverPersonNameCont.text = widget.orderData!.deliveryPoint!.name
            .validate();
        deliverInstructionCont.text = widget
            .orderData!
            .deliveryPoint!
            .instruction
            .validate();
        pickInstructionCont.text = widget.orderData!.pickupPoint!.instruction
            .validate();
        pickLat = widget.orderData!.pickupPoint!.latitude.validate();
        pickLong = widget.orderData!.pickupPoint!.longitude.validate();
        if (widget.orderData!.pickupPoint!.contactNumber
                .validate()
                .split(" ")
                .length ==
            1) {
          pickPhoneCont.text = widget.orderData!.pickupPoint!.contactNumber
              .validate()
              .split(" ")
              .last;
        } else {
          pickupCountryCode = widget.orderData!.pickupPoint!.contactNumber
              .validate()
              .split(" ")
              .first;
          pickPhoneCont.text = widget.orderData!.pickupPoint!.contactNumber
              .validate()
              .split(" ")
              .last;
        }
        pickDesCont.text = widget.orderData!.pickupPoint!.description
            .validate();

        deliverAddressCont.text = widget.orderData!.deliveryPoint!.address
            .validate();
        deliverLat = widget.orderData!.deliveryPoint!.latitude.validate();
        deliverLong = widget.orderData!.deliveryPoint!.longitude.validate();
        if (widget.orderData!.deliveryPoint!.contactNumber
                .validate()
                .split(" ")
                .length ==
            1) {
          deliverPhoneCont.text = widget.orderData!.deliveryPoint!.contactNumber
              .validate()
              .split(" ")
              .last;
        } else {
          deliverCountryCode = widget.orderData!.deliveryPoint!.contactNumber
              .validate()
              .split(" ")
              .first;
          deliverPhoneCont.text = widget.orderData!.deliveryPoint!.contactNumber
              .validate()
              .split(" ")
              .last;
        }
        deliverDesCont.text = widget.orderData!.deliveryPoint!.description
            .validate();

        paymentCollectFrom = widget.orderData!.paymentCollectFrom.validate(
          value: PAYMENT_ON_PICKUP,
        );
      }
    } catch (e, s) {
      debugPrint("CreateOrderScreen Error ${e}, Trace ${s}");
    }
  }

  getDistance() async {
    String? originLat = pickLat;
    String? originLong = pickLong;
    String? destinationLat = deliverLat;
    String? destinationLong = deliverLong;
    String origins = "${originLat},${originLong}";
    String destinations = "${destinationLat},${destinationLong}";
    try {
      await getDistanceBetweenLatLng(origins, destinations).then((value) async {
        String distanceText = value.rows[0].elements[0].distance.text
            .toString();
        double distanceInKms =
            double.tryParse(distanceText.split(' ').first) ?? 0;
        if (appStore.distanceUnit == DISTANCE_UNIT_MILE) {
          totalDistance = (MILES_PER_KM * distanceInKms);
        } else {
          totalDistance = distanceInKms;
        }
      });
    } catch (e, s) {
      totalDistance = 0;
      debugPrint("getDistance Error ${e}, Trace ${s}");
      toast('Could not load route distance. Continuing with estimate.');
    }
    setState(() {});
    await getTotalForOrder();
  }

  getTotalForOrder() async {
    print("getTotalForOrder called");
    appStore.setLoading(true);
    try {
      VehicleDetail? selectedVehicleData;
      if (appStore.isVehicleOrder != 0 && vehicleList.isNotEmpty) {
        try {
          selectedVehicleData = vehicleList.firstWhere(
            (element) => element.id == selectedVehicle,
          );
        } catch (_) {
          selectedVehicleData = vehicleList.first;
          selectedVehicle = selectedVehicleData.id;
        }
      }

      Map request = {
        "city_id": getIntAsync(CITY_ID).toString(),
        if (selectedVehicleData != null) "vehicle_id": selectedVehicleData.id,
        "is_insurance":
            insuranceSelectedOption == 0 && appStore.isInsuranceAllowed == "1",
        // "is_insurance": 0,
        "total_weight": weightController.text.toDouble(),
        "total_distance": totalDistance,
        "insurance_amount": insuranceAmountController.text.isEmpty
            ? 0
            : insuranceAmountController.text,
      };

      await getTotalAmountForOrder(request).then((value) {
        print("getTotalForOrder response");
        print("------------request${request.toString()}");
        totalAmountResponse = value;
        print("---------------${totalAmountResponse!.baseTotal}");
        if (value.vehicleAmount != null) {
          vehicleCharge = value.vehicleAmount!;
        }
        setState(() {});
      });
    } catch (e, s) {
      debugPrint("getTotalForOrder Error ${e}, Trace ${s}");
      toast('Unable to load order total right now. Please try again.');
    } finally {
      appStore.setLoading(false);
    }
  }

  double calculateTotalAmount() {
    double totalAmount = totalAmountResponse!.totalAmount?.toDouble() ?? 0.00;
    double result = 0.00;

    if (selectedCoupon?.valueType == "fixed") {
      double couponAmount = selectedCoupon?.discountAmount?.toDouble() ?? 0;
      double finalTotal = (totalAmount - couponAmount).clamp(
        0.00,
        double.infinity,
      );
      result = isAppliedCoupon ? finalTotal : totalAmount;
    } else if (selectedCoupon?.valueType == "percentage") {
      double percentage = selectedCoupon?.discountAmount?.toDouble() ?? 0;
      double discountAmount = (totalAmount * percentage) / 100;
      double finalAmount = (totalAmount - discountAmount).clamp(
        0.00,
        double.infinity,
      );

      result = isAppliedCoupon ? finalAmount : totalAmount;
    } else if (selectedCoupon == null && isAppliedCoupon == false) {
      result = totalAmount.toDouble();
    }

    return (result * 100).round() / 100;
  }

  createOrderApiCall(String orderStatus) async {
    if (orderStatus != ORDER_DRAFT) {
      await ensureAddressCoordinates();
      if (!hasValidCoordinates(pickLat, pickLong) ||
          !hasValidCoordinates(deliverLat, deliverLong)) {
        toast('Please pick both pickup and delivery locations from the map.');
        return;
      }
    }
    List<Map<String, String>> packaging_symbols = [];
    selectedPackingSymbols.map((item) {
      packaging_symbols.add({'key': item["key"]!, 'title': item['title']!});
    }).toList();
    extraChargeList.clear();
    if (totalAmountResponse!.extraCharges != null) {
      totalAmountResponse!.extraCharges!.forEach((element) {
        extraChargeList.add(
          ExtraChargeRequestModel(
            key: element.title!.toLowerCase().replaceAll(' ', "_"),
            value: element.charges,
            valueType: element.chargesType,
          ),
        );
      });
    }

    appStore.setLoading(true);
    Map req = {
      "id": widget.orderData != null ? widget.orderData!.id : "",
      "client_id": getIntAsync(USER_ID).toString(),
      "date": DateTime.now().toString(),
      "country_id": getIntAsync(COUNTRY_ID).toString(),
      "city_id": getIntAsync(CITY_ID).toString(),
      //   if (appStore.isVehicleOrder != 0) "vehicle_id": selectedVehicle.toString(),
      if (!selectedVehicle.toString().isEmptyOrNull &&
          selectedVehicle != 0 &&
          appStore.isVehicleOrder != 0)
        "vehicle_id": selectedVehicle.toString(),
      if (vehicleCharge != 0.0) "vehicle_charge": vehicleCharge,
      if (appStore.isSmsOrder == 1) "sms_type": TYPE_TWILIO,
      "pickup_point": {
        "start_time": (!isDeliverNow && pickFromDateTime != null)
            ? pickFromDateTime.toString()
            : DateTime.now().toString(),
        "end_time": (!isDeliverNow && pickToDateTime != null)
            ? pickToDateTime!.toString()
            : null,
        "address": pickAddressCont.text,
        "latitude": pickLat,
        "longitude": pickLong,
        "name": pickPersonNameCont.text.toString(),
        "description": pickDesCont.text,
        "instruction": pickInstructionCont.text,
        "contact_number": '$pickupCountryCode${pickPhoneCont.text.trim()}',
      },
      "delivery_point": {
        "start_time": (!isDeliverNow && deliverFromDateTime != null)
            ? deliverFromDateTime.toString()
            : null,
        "end_time": (!isDeliverNow && deliverToDateTime != null)
            ? deliverToDateTime.toString()
            : null,
        "address": deliverAddressCont.text,
        "latitude": deliverLat,
        "longitude": deliverLong,
        "description": deliverDesCont.text,
        "name": deliverPersonNameCont.text.toString(),
        "instruction": deliverInstructionCont.text,
        "contact_number": '$deliverCountryCode${deliverPhoneCont.text.trim()}',
      },
      "packaging_symbols": packaging_symbols,
      "extra_charges": extraChargeList,
      "parcel_type": parcelTypeCont.text,
      "total_weight": weightController.text.toDouble(),
      "total_distance": totalDistance
          .toStringAsFixed(digitAfterDecimal)
          .validate(),
      "payment_collect_from": paymentCollectFrom,
      "status": orderStatus,
      "payment_type": isSelected == 2 ? PAYMENT_TYPE_ONLINE : "",
      "payment_status": "",
      "fixed_charges": totalAmountResponse!.fixedAmount!.toDouble(),
      "parent_order_id": "",
      "bid_type": biddingSelectedOption ? 1 : 0,
      "total_amount": calculateTotalAmount(),
      "weight_charge": totalAmountResponse!.weightAmount!.toDouble(),
      "distance_charge": totalAmountResponse!.distanceAmount!.toDouble(),
      "total_parcel": totalParcelController.text.toInt(),
      "insurance_charge": insuranceAmount,
      if (selectedCoupon?.couponCode != null && isAppliedCoupon == true)
        "discount_amount":
            (totalAmountResponse!.totalAmount! - calculateTotalAmount()),

      "coupon_code": selectedCoupon?.couponCode ?? null,
    };

    log("req----" + req.toString());
    final pattern = RegExp('.{1,800}'); // 800 is the size of each chunk
    pattern
        .allMatches(req.toString())
        .forEach((match) => print(match.group(0)));
    await createOrder(req)
        .then((value) async {
          appStore.setLoading(false);
          toast(value.message);
          finish(context);
          if (isSelected == 2) {
            PaymentScreen(
              orderId: value.orderId.validate(),
              totalAmount: (totalAmountResponse!.totalAmount!),
              isOnline: true,
            ).launch(context);
          } else if (isSelected == 3) {
            log(
              "-----available balance ${appStore.availableBal.toString()}-----------${totalAmountResponse!.totalAmount}----------${insuranceAmount}----------${(totalAmountResponse!.totalAmount! + insuranceAmount)}",
            );
            if (appStore.availableBal > (totalAmountResponse!.totalAmount!)) {
              savePaymentApiCall(
                paymentType: PAYMENT_TYPE_WALLET,
                paymentStatus: PAYMENT_PAID,
                totalAmount: (calculateTotalAmount()).toString(),
                orderID: value.orderId.toString(),
              );
            }
          } else {
            DashboardScreen().launch(context, isNewTask: true);
          }
        })
        .catchError((error) {
          appStore.setLoading(false);
          toast(error.toString());
        });
  }

  /// Save Payment
  Future<void> savePaymentApiCall({
    String? paymentType,
    String? totalAmount,
    String? orderID,
    String? txnId,
    String? paymentStatus = PAYMENT_PENDING,
    Map? transactionDetail,
  }) async {
    Map req = {
      "id": "",
      "order_id": orderID,
      "client_id": getIntAsync(USER_ID).toString(),
      "datetime": DateFormat('yyyy-MM-dd hh:mm:ss').format(DateTime.now()),
      "total_amount": totalAmount,
      "payment_type": paymentType,
      "txn_id": txnId,
      "payment_status": paymentStatus,
      "transaction_detail": transactionDetail ?? {},
    };

    appStore.setLoading(true);

    savePayment(req)
        .then((value) {
          appStore.setLoading(false);
          toast(value.message.toString());
          DashboardScreen().launch(context, isNewTask: true);
        })
        .catchError((error) {
          appStore.setLoading(false);
          print(error.toString());
        });
  }

  @override
  void setState(fn) {
    if (mounted) super.setState(fn);
  }

  bool hasValidCoordinates(String? latitude, String? longitude) {
    if (latitude.isEmptyOrNull || longitude.isEmptyOrNull) return false;
    return double.tryParse(latitude.validate()) != null &&
        double.tryParse(longitude.validate()) != null;
  }

  bool get shouldShowRouteReview =>
      hasValidCoordinates(pickLat, pickLong) &&
      hasValidCoordinates(deliverLat, deliverLong);

  void clearRoutePreviewData() {
    markers.clear();
    _polylines.clear();
    polylineCoordinates.clear();
  }

  Future<bool> resolveCoordinatesFromAddress({
    required String address,
    required bool isPickup,
  }) async {
    String value = address.trim();
    if (value.isEmpty) return false;

    try {
      List<Location> locations = await locationFromAddress(value);
      if (locations.isEmpty) return false;

      Location point = locations.first;
      if (isPickup) {
        pickLat = point.latitude.toString();
        pickLong = point.longitude.toString();
      } else {
        deliverLat = point.latitude.toString();
        deliverLong = point.longitude.toString();
      }
      return true;
    } catch (e) {
      log('Address geocoding failed: $e');
      return false;
    }
  }

  Future<void> ensureAddressCoordinates() async {
    if (!hasValidCoordinates(pickLat, pickLong) &&
        pickAddressCont.text.trim().isNotEmpty) {
      await resolveCoordinatesFromAddress(
        address: pickAddressCont.text,
        isPickup: true,
      );
    }

    if (!hasValidCoordinates(deliverLat, deliverLong) &&
        deliverAddressCont.text.trim().isNotEmpty) {
      await resolveCoordinatesFromAddress(
        address: deliverAddressCont.text,
        isPickup: false,
      );
    }
  }

  bool get hasSavedAddresses {
    try {
      return getAddressData != null &&
          getAddressData.data != null &&
          getAddressData.data.isNotEmpty;
    } catch (e) {
      return false;
    }
  }

  void refreshRecentAddressData() {
    addressList = (getStringListAsync(RECENT_ADDRESS_LIST) ?? [])
        .map((e) => UseraddressDetail.fromJson(jsonDecode(e)))
        .toList();
    if (addressList.isNotEmpty) {
      pickAddressData = addressList.first;
      deliveryAddressData = addressList.first;
    }
  }

  String extractLocalPhoneNumber(String? rawNumber) {
    String value = rawNumber.validate().trim();
    if (value.isEmpty) return '';

    List<String> parts = value
        .split(RegExp(r'\s+'))
        .where((e) => e.isNotEmpty)
        .toList();
    if (parts.length > 1) return parts.last;

    if (value.startsWith('+')) {
      String cleaned = value.replaceFirst(RegExp(r'^\+\d{1,4}'), '').trim();
      return cleaned.isNotEmpty ? cleaned : value;
    }
    return value;
  }

  Future<void> openPickupAddressPicker() async {
    bool isLocationEnabledNow = await checkAndRequestLocationServices(context);
    if (!isLocationEnabledNow) return;

    if (!hasSavedAddresses) {
      await showMapScreen(isPick: true, isSaveAddress: false);
      return;
    }

    await showModalBottomSheet(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(defaultRadius),
        ),
      ),
      context: context,
      builder: (context) {
        return PickAddressBottomSheet(
          onAddNewAddress: () async {
            pop();
            await showMapScreen(isPick: true, isSaveAddress: false);
          },
          onPick: (address) {
            pickAddressCont.text = address.address ?? "";
            pickLat = address.latitude.toString();
            pickLong = address.longitude.toString();
            pickPhoneCont.text = extractLocalPhoneNumber(address.contactNumber);
            setState(() {});
          },
          isPickup: true,
        );
      },
    );

    refreshRecentAddressData();
    setState(() {});
  }

  Future<void> openDeliveryAddressPicker() async {
    bool isLocationEnabledNow = await checkAndRequestLocationServices(context);
    if (!isLocationEnabledNow) return;

    if (!hasSavedAddresses) {
      await showMapScreen(isSaveAddress: true, isPick: false);
      return;
    }

    await showModalBottomSheet(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(defaultRadius),
        ),
      ),
      context: context,
      builder: (context) {
        return PickAddressBottomSheet(
          onAddNewAddress: () async {
            pop();
            await showMapScreen(isPick: false, isSaveAddress: false);
          },
          onPick: (address) {
            deliverAddressCont.text = address.address ?? "";
            deliverLat = address.latitude.toString();
            deliverLong = address.longitude.toString();
            deliverPhoneCont.text = extractLocalPhoneNumber(
              address.contactNumber,
            );
            setState(() {});
          },
          isPickup: false,
        );
      },
    );

    refreshRecentAddressData();
    setState(() {});
  }

  Future<bool> checkAndRequestLocationServices(BuildContext context) async {
    // 1️⃣ Check if location services are enabled
    final isLocationEnabled = await Geolocator.isLocationServiceEnabled();

    if (!isLocationEnabled) {
      final openSettings = await showConfirmDialogCustom(
        context,
        primaryColor: ColorUtils.colorPrimary,
        title: "Location Services Disabled",
        note: "Please enable location services to select your address.",
        positiveText: language.ok,
        negativeText: language.cancel,
        onCancel: (_) => Navigator.pop(context, false),
        onAccept: (_) => Navigator.pop(context, true),
      );

      if (openSettings == true) {
        await Geolocator.openLocationSettings();
        return false;
      }
      return false;
    }

    // 2️⃣ Check permission status
    LocationPermission permission = await Geolocator.checkPermission();

    // 🔁 Request again if just denied
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    // 🚫 Permanently denied → App settings
    if (permission == LocationPermission.deniedForever) {
      final openSettings = await showConfirmDialogCustom(
        context,
        primaryColor: ColorUtils.colorPrimary,
        title: "Location Permission Required",
        note: "Enable location permission from app settings to continue.",
        positiveText: language.ok,
        negativeText: language.cancel,
        onCancel: (_) => Navigator.pop(context, false),
        onAccept: (_) => Navigator.pop(context, true),
      );

      if (openSettings == true) {
        await Geolocator.openAppSettings();
      }
      return false;
    }

    // ✅ Permission granted
    return permission == LocationPermission.always ||
        permission == LocationPermission.whileInUse;
  }

  void setMapFitToCenter(Set<Polyline> p) {
    double minLat = p.first.points.first.latitude;
    double minLong = p.first.points.first.longitude;
    double maxLat = p.first.points.first.latitude;
    double maxLong = p.first.points.first.longitude;

    p.forEach((poly) {
      poly.points.forEach((point) {
        if (point.latitude < minLat) minLat = point.latitude;
        if (point.latitude > maxLat) maxLat = point.latitude;
        if (point.longitude < minLong) minLong = point.longitude;
        if (point.longitude > maxLong) maxLong = point.longitude;
      });
    });
    googleMapController?.animateCamera(
      CameraUpdate.newLatLngBounds(
        LatLngBounds(
          southwest: LatLng(minLat, minLong),
          northeast: LatLng(maxLat, maxLong),
        ),
        20,
      ),
    );
  }

  setPolylines() async {
    print("setPolyline");
    String? originLat = pickLat;
    String? originLong = pickLong;
    String? destinationLat = deliverLat;
    String? destinationLong = deliverLong;
    String origins = "${originLat},${originLong}";
    String destinations = "${destinationLat},${destinationLong}";
    await getPolylineData(origins, destinations).then((value) async {
      if (value.status != null && value.status!) {
        if (value.polyline != null) {
          final points = decodePolyline(value.polyline!);
          if (points.isNotEmpty) {
            polylineCoordinates = points;
          } else {
            debugPrint('---No Data--');
          }
        } else {
          debugPrint('---Polyline Null---');
        }
      } else {
        debugPrint('---Status False or Null---');
      }
    });
    setState(() {
      Polyline polyline = Polyline(
        polylineId: PolylineId("poly"),
        color: Color.fromARGB(255, 40, 122, 198),
        width: 5,
        points: polylineCoordinates,
      );
      _polylines.add(polyline);
    });
  }

  Widget createOrderWidget1() {
    return Observer(
      builder: (context) {
        return Column(
          crossAxisAlignment: .start,
          children: [
            Container(
              width: context.width(),
              padding: .all(12),
              decoration: boxDecorationWithRoundedCorners(
                backgroundColor: ColorUtils.colorPrimary.withValues(
                  alpha: 0.08,
                ),
                borderRadius: BorderRadius.circular(defaultRadius),
                border: Border.all(
                  color: ColorUtils.colorPrimary.withValues(alpha: 0.25),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.tips_and_updates_outlined,
                    color: ColorUtils.colorPrimary,
                    size: 20,
                  ),
                  8.width,
                  Text(
                    'Add schedule, parcel details and labels to help drivers prepare faster.',
                    style: secondaryTextStyle(size: 12),
                  ).expand(),
                ],
              ),
            ),
            16.height,
            Row(
              crossAxisAlignment: .center,
              mainAxisAlignment: .spaceBetween,
              children: [
                scheduleOptionWidget(
                  context,
                  isDeliverNow,
                  ic_clock,
                  language.deliveryNow,
                ).onTap(() {
                  isDeliverNow = true;
                  setState(() {});
                }).expand(),
                8.width,
                scheduleOptionWidget(
                  context,
                  !isDeliverNow,
                  ic_schedule,
                  language.schedule,
                ).onTap(() {
                  isDeliverNow = false;
                  setState(() {});
                }).expand(),
              ],
            ),
            16.height,
            Row(
              crossAxisAlignment: .center,
              mainAxisAlignment: .spaceBetween,
              children: [
                enableBidOptionWidget(
                  context,
                  biddingSelectedOption,
                  Icons.handshake_outlined,
                  language.bids,
                ).onTap(() {
                  biddingSelectedOption = !biddingSelectedOption;
                  setState(() {});
                }).expand(),
                const Spacer(),
              ],
            ).visible(appStore.isBiddingEnabled == "1"),
            16.height,
            Column(
              crossAxisAlignment: .start,
              children: [
                Text(language.pickTime, style: boldTextStyle()),
                16.height,
                Container(
                  padding: .all(16),
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: ColorUtils.borderColor,
                      width: appStore.isDarkMode ? 0.2 : 1,
                    ),
                    borderRadius: BorderRadius.circular(defaultRadius),
                  ),
                  child: Column(
                    children: [
                      DateTimePicker(
                        controller: pickDateController,
                        type: DateTimePickerType.date,
                        initialDate: DateTime.now(),
                        firstDate: DateTime.now(),
                        lastDate: DateTime.now().add(Duration(days: 30)),
                        onChanged: (value) {
                          pickDate = DateTime.parse(value);
                          deliverDate = null;
                          deliverDateController.clear();
                          setState(() {});
                        },
                        validator: (value) {
                          if (value!.isEmpty) return language.fieldRequiredMsg;
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
                          DateTimePicker(
                            controller: pickFromTimeController,
                            type: DateTimePickerType.time,
                            onChanged: (value) {
                              pickFromTime = TimeOfDay.fromDateTime(
                                DateFormat('hh:mm').parse(value),
                              );
                              setState(() {});
                            },
                            validator: (value) {
                              if (value.validate().isEmpty)
                                return language.fieldRequiredMsg;

                              // Check if today’s date is selected
                              DateTime now = DateTime.now();
                              DateTime selectedDateTime = DateFormat(
                                'hh:mm',
                              ).parse(value!);
                              DateTime selectedDateWithTime = DateTime(
                                now.year,
                                now.month,
                                now.day,
                                selectedDateTime.hour,
                                selectedDateTime.minute,
                              );
                              if (pickDate!.year == now.year &&
                                  pickDate!.month == now.month &&
                                  pickDate!.day == now.day) {
                                // Add 1 hour to the current time if the selected date is today
                                if (selectedDateWithTime.isBefore(
                                  now.add(Duration(hours: 1)),
                                )) {
                                  return language.scheduleOrderTimeMsg;
                                }
                              } else {
                                double fromTimeInHour =
                                    pickFromTime!.hour +
                                    pickFromTime!.minute / 60;
                                double toTimeInHour =
                                    pickToTime!.hour + pickToTime!.minute / 60;
                                double difference =
                                    toTimeInHour - fromTimeInHour;
                                if (difference <= 0) {
                                  return language.endTimeValidationMsg;
                                }
                              }

                              return null;
                            },
                            decoration: commonInputDecoration(
                              suffixIcon: Icons.access_time,
                              hintText: language.from,
                            ),
                          ).expand(),
                          16.width,
                          DateTimePicker(
                            controller: pickToTimeController,
                            type: DateTimePickerType.time,
                            onChanged: (value) {
                              pickToTime = TimeOfDay.fromDateTime(
                                DateFormat('hh:mm').parse(value),
                              );
                              setState(() {});
                            },
                            validator: (value) {
                              if (value.validate().isEmpty)
                                return language.fieldRequiredMsg;
                              double fromTimeInHour =
                                  pickFromTime!.hour +
                                  pickFromTime!.minute / 60;
                              double toTimeInHour =
                                  pickToTime!.hour + pickToTime!.minute / 60;
                              double difference = toTimeInHour - fromTimeInHour;
                              // Check if today’s date is selected
                              DateTime now = DateTime.now();
                              DateTime selectedDateTime = DateFormat(
                                'hh:mm',
                              ).parse(value!);
                              DateTime selectedDateWithTime = DateTime(
                                now.year,
                                now.month,
                                now.day,
                                selectedDateTime.hour,
                                selectedDateTime.minute,
                              );
                              if (pickDate!.year == now.year &&
                                  pickDate!.month == now.month &&
                                  pickDate!.day == now.day) {
                                // Add 1 hour to the current time if the selected date is today
                                if (selectedDateWithTime.isBefore(
                                  now.add(Duration(hours: 1)),
                                )) {
                                  return language.scheduleOrderTimeMsg;
                                }
                              }
                              if (difference <= 0) {
                                return language.endTimeValidationMsg;
                              }
                              return null;
                            },
                            decoration: commonInputDecoration(
                              suffixIcon: Icons.access_time,
                              hintText: language.to,
                            ),
                          ).expand(),
                        ],
                      ),
                    ],
                  ),
                ),
                16.height,
                Text(language.deliverTime, style: boldTextStyle()),
                16.height,
                Container(
                  padding: .all(16),
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: ColorUtils.borderColor,
                      width: appStore.isDarkMode ? 0.2 : 1,
                    ),
                    borderRadius: BorderRadius.circular(defaultRadius),
                  ),
                  child: Column(
                    children: [
                      DateTimePicker(
                        controller: deliverDateController,
                        type: DateTimePickerType.date,
                        initialDate: pickDate ?? DateTime.now(),
                        firstDate: pickDate ?? DateTime.now(),
                        lastDate: DateTime.now().add(Duration(days: 30)),
                        onChanged: (value) {
                          deliverDate = DateTime.parse(value);
                          setState(() {});
                        },
                        validator: (value) {
                          if (value!.isEmpty) return language.fieldRequiredMsg;

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
                          DateTimePicker(
                            controller: deliverFromTimeController,
                            type: DateTimePickerType.time,
                            onChanged: (value) {
                              deliverFromTime = TimeOfDay.fromDateTime(
                                DateFormat('hh:mm').parse(value),
                              );
                              setState(() {});
                            },
                            validator: (value) {
                              if (value.validate().isEmpty)
                                return language.fieldRequiredMsg;
                              double fromTimeInHour =
                                  deliverFromTime!.hour +
                                  deliverFromTime!.minute / 60;
                              double toTimeInHour =
                                  deliverToTime!.hour +
                                  deliverToTime!.minute / 60;
                              double difference = toTimeInHour - fromTimeInHour;
                              // Check if today’s date is selected
                              DateTime now = DateTime.now();
                              DateTime selectedDateTime = DateFormat(
                                'hh:mm',
                              ).parse(value!);
                              DateTime selectedDateWithTime = DateTime(
                                now.year,
                                now.month,
                                now.day,
                                selectedDateTime.hour,
                                selectedDateTime.minute,
                              );
                              if (pickDate!.year == now.year &&
                                  pickDate!.month == now.month &&
                                  pickDate!.day == now.day) {
                                // Add 1 hour to the current time if the selected date is today
                                if (selectedDateWithTime.isBefore(
                                  now.add(Duration(hours: 1)),
                                )) {
                                  return language.scheduleOrderTimeMsg;
                                }
                              }
                              if (difference <= 0) {
                                return language.endTimeValidationMsg;
                              }
                              return null;
                            },
                            decoration: commonInputDecoration(
                              suffixIcon: Icons.access_time,
                              hintText: language.from,
                            ),
                          ).expand(),
                          16.width,
                          DateTimePicker(
                            controller: deliverToTimeController,
                            type: DateTimePickerType.time,
                            onChanged: (value) {
                              deliverToTime = TimeOfDay.fromDateTime(
                                DateFormat('hh:mm').parse(value),
                              );
                              setState(() {});
                            },
                            validator: (value) {
                              if (value!.isEmpty)
                                return language.fieldRequiredMsg;
                              if (value.validate().isEmpty)
                                return language.fieldRequiredMsg;
                              double fromTimeInHour =
                                  deliverFromTime!.hour +
                                  deliverFromTime!.minute / 60;
                              double toTimeInHour =
                                  deliverToTime!.hour +
                                  deliverToTime!.minute / 60;
                              double difference = toTimeInHour - fromTimeInHour;
                              // Check if today’s date is selected
                              DateTime now = DateTime.now();
                              DateTime selectedDateTime = DateFormat(
                                'hh:mm',
                              ).parse(value);
                              DateTime selectedDateWithTime = DateTime(
                                now.year,
                                now.month,
                                now.day,
                                selectedDateTime.hour,
                                selectedDateTime.minute,
                              );
                              if (deliverDate!.year == now.year &&
                                  deliverDate!.month == now.month &&
                                  deliverDate!.day == now.day) {
                                // Add 1 hour to the current time if the selected date is today
                                if (selectedDateWithTime.isBefore(
                                  now.add(Duration(hours: 1)),
                                )) {
                                  return language.scheduleOrderTimeMsg;
                                }
                              }
                              if (difference <= 0) {
                                return language.endTimeValidationMsg;
                              }
                              return null;
                            },
                            decoration: commonInputDecoration(
                              suffixIcon: Icons.access_time,
                              hintText: language.to,
                            ),
                          ).expand(),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ).visible(!isDeliverNow),
            16.height,

            // Text(language.weight, style: boldTextStyle()),
            // 8.height,
            Row(
              children: [
                Text(language.weight, style: primaryTextStyle()).expand(),
                3.width,
                //   Text(" (${appStore.distanceUnit})", style: secondaryTextStyle()).expand(),
                Container(
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: ColorUtils.borderColor,
                      width: appStore.isDarkMode ? 0.2 : 1,
                    ),
                    borderRadius: BorderRadius.circular(defaultRadius),
                  ),
                  child: IntrinsicHeight(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.remove,
                          color: appStore.isDarkMode
                              ? Colors.white
                              : Colors.grey,
                        ).paddingAll(12).onTap(() {
                          if (weightController.text.toDouble() > 1) {
                            weightController.text =
                                (weightController.text.toDouble() - 1)
                                    .toString();
                          }
                        }),
                        VerticalDivider(
                          thickness: 1,
                          color: context.dividerColor,
                        ),
                        Container(
                          width: 50,
                          child: AppTextField(
                            controller: weightController,
                            textAlign: TextAlign.center,
                            maxLength: 5,
                            textFieldType: TextFieldType.PHONE,
                            decoration: InputDecoration(
                              counterText: '',
                              focusedBorder: UnderlineInputBorder(
                                borderSide: BorderSide(
                                  color: ColorUtils.colorPrimary,
                                ),
                              ),
                              border: InputBorder.none,
                            ),
                          ),
                        ),
                        VerticalDivider(
                          thickness: 1,
                          color: context.dividerColor,
                        ),
                        Icon(
                          Icons.add,
                          color: appStore.isDarkMode
                              ? Colors.white
                              : Colors.grey,
                        ).paddingAll(12).onTap(() {
                          weightController.text =
                              (weightController.text.toDouble() + 1).toString();
                        }),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            16.height,
            // Text(language.numberOfParcels, style: boldTextStyle()),
            // 8.height,
            Row(
              children: [
                Text(
                  language.numberOfParcels,
                  style: primaryTextStyle(),
                ).expand(),
                Container(
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: ColorUtils.borderColor,
                      width: appStore.isDarkMode ? 0.2 : 1,
                    ),
                    borderRadius: BorderRadius.circular(defaultRadius),
                  ),
                  child: IntrinsicHeight(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.remove,
                          color: appStore.isDarkMode
                              ? Colors.white
                              : Colors.grey,
                        ).paddingAll(12).onTap(() {
                          if (totalParcelController.text.toInt() > 1) {
                            totalParcelController.text =
                                (totalParcelController.text.toInt() - 1)
                                    .toString();
                          }
                        }),
                        VerticalDivider(
                          thickness: 1,
                          color: context.dividerColor,
                        ),
                        Container(
                          width: 50,
                          child: AppTextField(
                            controller: totalParcelController,
                            textAlign: TextAlign.center,
                            maxLength: 2,
                            textFieldType: TextFieldType.PHONE,
                            decoration: InputDecoration(
                              counterText: '',
                              focusedBorder: UnderlineInputBorder(
                                borderSide: BorderSide(
                                  color: ColorUtils.colorPrimary,
                                ),
                              ),
                              border: InputBorder.none,
                            ),
                          ),
                        ),
                        VerticalDivider(
                          thickness: 1,
                          color: context.dividerColor,
                        ),
                        Icon(
                          Icons.add,
                          color: appStore.isDarkMode
                              ? Colors.white
                              : Colors.grey,
                        ).paddingAll(12).onTap(() {
                          totalParcelController.text =
                              (totalParcelController.text.toInt() + 1)
                                  .toString();
                        }),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            16.height,
            Text(language.parcelType, style: primaryTextStyle()),
            8.height,
            AppTextField(
              controller: parcelTypeCont,
              textFieldType: TextFieldType.OTHER,
              decoration: commonInputDecoration(),
              validator: (value) {
                if (value!.isEmpty) return language.fieldRequiredMsg;
                return null;
              },
            ),
            8.height,
            Wrap(
              spacing: 8,
              runSpacing: 0,
              children: parcelTypeList.map((item) {
                return Chip(
                  backgroundColor: context.scaffoldBackgroundColor,
                  label: Text(item.label!, style: secondaryTextStyle()),
                  elevation: 0,
                  labelStyle: primaryTextStyle(color: Colors.grey),
                  padding: .zero,
                  labelPadding: .symmetric(horizontal: 10, vertical: 0),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(defaultRadius),
                    side: BorderSide(
                      color: ColorUtils.borderColor,
                      width: appStore.isDarkMode ? 0.2 : 1,
                    ),
                  ),
                ).onTap(() {
                  parcelTypeCont.text = item.label!;
                  setState(() {});
                });
              }).toList(),
            ),
            16.height,
            Row(
              mainAxisAlignment: .spaceBetween,
              children: [
                Text(language.labels, style: primaryTextStyle()),
                Icon(
                  Icons.info,
                  color: appStore.isDarkMode
                      ? Colors.white.withValues(alpha: 0.7)
                      : ColorUtils.colorPrimary,
                ).onTap(() {
                  PackagingSymbolsInfo().launch(context);
                }),
              ],
            ),
            16.height,
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: packingSymbolsItems.map((item) {
                bool isSelected = selectedPackingSymbols.contains(item);
                return Container(
                  width: 70,
                  decoration: boxDecorationWithRoundedCorners(),
                  child: Stack(
                    children: [
                      Image.asset(
                        item['image']!,
                        width: 24,
                        height: 24,
                        color: appStore.isDarkMode
                            ? Colors.white.withValues(alpha: 0.7)
                            : ColorUtils.colorPrimary,
                      ).center().paddingAll(10),
                      if (isSelected)
                        Positioned(
                          top: 0,
                          right: 0,
                          child: Icon(
                            Icons.check_circle,
                            color: Colors.green,
                            size: 16,
                          ),
                        ),
                    ],
                  ),
                ).onTap(() {
                  setState(() {
                    if (isSelected) {
                      selectedPackingSymbols.remove(item);
                    } else {
                      selectedPackingSymbols.add(item);
                    }
                  });

                  setState(() {});
                });
              }).toList(),
            ),
          ],
        );
      },
    );
  }

  Widget createOrderWidget2() {
    return Column(
      crossAxisAlignment: .start,
      children: [
        Column(
          crossAxisAlignment: .start,
          children: [
            Text(language.location, style: primaryTextStyle()),
            8.height,
            AppTextField(
              controller: pickAddressCont,
              readOnly: false,
              textInputAction: TextInputAction.next,
              nextFocus: pickPhoneFocus,
              textFieldType: TextFieldType.MULTILINE,
              decoration: commonInputDecoration(),
              suffix: Icon(Icons.map_outlined, color: ColorUtils.colorPrimary)
                  .paddingAll(12)
                  .onTap(() async {
                    await openPickupAddressPicker();
                  }),
              validator: (value) {
                if (value!.isEmpty) return language.fieldRequiredMsg;
                return null;
              },
              onChanged: (value) {
                pickLat = null;
                pickLong = null;
              },
            ),
            6.height,
            Container(
              width: context.width(),
              padding: .symmetric(horizontal: 10, vertical: 8),
              decoration: boxDecorationWithRoundedCorners(
                backgroundColor: ColorUtils.colorPrimary.withValues(
                  alpha: 0.06,
                ),
                borderRadius: BorderRadius.circular(defaultRadius),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.map_outlined,
                    size: 16,
                    color: ColorUtils.colorPrimary,
                  ),
                  8.width,
                  Text(
                    'Type address manually or tap map icon to pick from map.',
                    style: secondaryTextStyle(size: 12),
                  ).expand(),
                ],
              ),
            ),
            16.height,
            Text(language.contactNumber, style: primaryTextStyle()),
            8.height,
            AppTextField(
              controller: pickPhoneCont,
              focus: pickPhoneFocus,
              nextFocus: pickDesFocus,
              textFieldType: TextFieldType.PHONE,
              decoration: commonInputDecoration(
                suffixIcon: Icons.phone,
                prefixIcon: IntrinsicHeight(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CountryCodePicker(
                        initialSelection: pickupCountryCode,
                        showCountryOnly: false,
                        dialogSize: Size(
                          context.width() - 60,
                          context.height() * 0.6,
                        ),
                        showFlag: true,
                        showFlagDialog: true,
                        showOnlyCountryWhenClosed: false,
                        alignLeft: false,
                        textStyle: primaryTextStyle(),
                        dialogBackgroundColor: Theme.of(context).cardColor,
                        barrierColor: Colors.black12,
                        dialogTextStyle: primaryTextStyle(),
                        searchDecoration: InputDecoration(
                          iconColor: Theme.of(context).dividerColor,
                          enabledBorder: UnderlineInputBorder(
                            borderSide: BorderSide(
                              color: Theme.of(context).dividerColor,
                            ),
                          ),
                          focusedBorder: UnderlineInputBorder(
                            borderSide: BorderSide(
                              color: ColorUtils.colorPrimary,
                            ),
                          ),
                        ),
                        searchStyle: primaryTextStyle(),
                        onInit: (c) {
                          pickupCountryCode = c!.dialCode!;
                        },
                        onChanged: (c) {
                          pickupCountryCode = c.dialCode!;
                        },
                      ),
                      VerticalDivider(
                        color: Colors.grey.withValues(alpha: 0.5),
                      ),
                    ],
                  ),
                ),
              ),
              textInputAction: TextInputAction.go,
              validator: (value) {
                if (value!.trim().isEmpty) return language.fieldRequiredMsg;
                return null;
              },
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            ),
          ],
        ),
        16.height,
        Text(language.pickupPersonName, style: primaryTextStyle()),
        8.height,
        AppTextField(
          controller: pickPersonNameCont,
          textInputAction: TextInputAction.done,
          focus: pickPersonNameFocus,
          textFieldType: TextFieldType.NAME,
          decoration: commonInputDecoration(),
          validator: (value) {
            if (value!.trim().isEmpty) return language.fieldRequiredMsg;
            return null;
          },
        ),
        16.height,
        Text(language.pickupDescription, style: primaryTextStyle()),
        8.height,
        TextField(
          controller: pickDesCont,
          focusNode: pickDesFocus,
          decoration: commonInputDecoration(suffixIcon: Icons.notes),
          textInputAction: TextInputAction.done,
          maxLines: 3,
          minLines: 3,
        ),
        16.height,
        Text(language.pickupInstructions, style: primaryTextStyle()),
        8.height,
        TextField(
          controller: pickInstructionCont,
          focusNode: pickInstructionFocus,
          decoration: commonInputDecoration(suffixIcon: Icons.notes),
          textInputAction: TextInputAction.done,
          maxLines: 2,
          minLines: 2,
        ),
      ],
    );
  }

  Widget createOrderWidget3() {
    return Column(
      crossAxisAlignment: .start,
      children: [
        Column(
          crossAxisAlignment: .start,
          children: [
            Text(language.deliveryLocation, style: primaryTextStyle()),
            8.height,
            AppTextField(
              controller: deliverAddressCont,
              readOnly: false,
              textInputAction: TextInputAction.next,
              nextFocus: deliverPhoneFocus,
              textFieldType: TextFieldType.MULTILINE,
              decoration: commonInputDecoration(),
              suffix: Icon(Icons.map_outlined, color: ColorUtils.colorPrimary)
                  .paddingAll(12)
                  .onTap(() async {
                    await openDeliveryAddressPicker();
                  }),
              validator: (value) {
                if (value!.isEmpty) return language.fieldRequiredMsg;
                return null;
              },
              onChanged: (value) {
                deliverLat = null;
                deliverLong = null;
              },
            ),
            6.height,
            Container(
              width: context.width(),
              padding: .symmetric(horizontal: 10, vertical: 8),
              decoration: boxDecorationWithRoundedCorners(
                backgroundColor: ColorUtils.colorPrimary.withValues(
                  alpha: 0.06,
                ),
                borderRadius: BorderRadius.circular(defaultRadius),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.map_outlined,
                    size: 16,
                    color: ColorUtils.colorPrimary,
                  ),
                  8.width,
                  Text(
                    'Type address manually or tap map icon to pick from map.',
                    style: secondaryTextStyle(size: 12),
                  ).expand(),
                ],
              ),
            ),
            16.height,
            Text(language.deliveryContactNumber, style: primaryTextStyle()),
            8.height,
            AppTextField(
              controller: deliverPhoneCont,
              textInputAction: TextInputAction.go,
              focus: deliverPhoneFocus,
              nextFocus: deliverDesFocus,
              textFieldType: TextFieldType.PHONE,
              decoration: commonInputDecoration(
                suffixIcon: Icons.phone,
                prefixIcon: IntrinsicHeight(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CountryCodePicker(
                        initialSelection: deliverCountryCode,
                        showCountryOnly: false,
                        dialogSize: Size(
                          context.width() - 60,
                          context.height() * 0.6,
                        ),
                        showFlag: true,
                        showFlagDialog: true,
                        showOnlyCountryWhenClosed: false,
                        alignLeft: false,
                        textStyle: primaryTextStyle(),
                        dialogBackgroundColor: Theme.of(context).cardColor,
                        barrierColor: Colors.black12,
                        dialogTextStyle: primaryTextStyle(),
                        searchDecoration: InputDecoration(
                          iconColor: Theme.of(context).dividerColor,
                          enabledBorder: UnderlineInputBorder(
                            borderSide: BorderSide(
                              color: Theme.of(context).dividerColor,
                            ),
                          ),
                          focusedBorder: UnderlineInputBorder(
                            borderSide: BorderSide(
                              color: ColorUtils.colorPrimary,
                            ),
                          ),
                        ),
                        searchStyle: primaryTextStyle(),
                        onInit: (c) {
                          deliverCountryCode = c!.dialCode!;
                        },
                        onChanged: (c) {
                          deliverCountryCode = c.dialCode!;
                        },
                      ),
                      VerticalDivider(
                        color: Colors.grey.withValues(alpha: 0.5),
                      ),
                    ],
                  ),
                ),
              ),
              validator: (value) {
                if (value!.trim().isEmpty) return language.fieldRequiredMsg;
                //if (value!.length < 8 || value.length > 15) return "please enter valid mobile number";
                if (value.trim().length < minContactLength ||
                    value.trim().length > maxContactLength)
                  return language.phoneNumberInvalid;
                return null;
              },
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            ),
          ],
        ),
        16.height,
        Text(language.deliveryPersonName, style: primaryTextStyle()),
        8.height,
        AppTextField(
          controller: deliverPersonNameCont,
          textInputAction: TextInputAction.go,
          focus: deliveryPesonNameFocus,
          textFieldType: TextFieldType.NAME,
          decoration: commonInputDecoration(),
          validator: (value) {
            if (value!.trim().isEmpty) return language.fieldRequiredMsg;
            return null;
          },
        ),
        16.height,
        Text(language.deliveryDescription, style: primaryTextStyle()),
        8.height,
        TextField(
          controller: deliverDesCont,
          focusNode: deliverDesFocus,
          decoration: commonInputDecoration(suffixIcon: Icons.notes),
          textInputAction: TextInputAction.done,
          maxLines: 3,
          minLines: 3,
        ),
        16.height,
        Text(language.deliveryInstructions, style: primaryTextStyle()),
        8.height,
        TextField(
          controller: deliverInstructionCont,
          focusNode: deliveryInstructionFocus,
          decoration: commonInputDecoration(suffixIcon: Icons.notes),
          textInputAction: TextInputAction.done,
          maxLines: 2,
          minLines: 2,
        ),
      ],
    );
  }

  void onMapCreated(GoogleMapController controller) async {
    setState(() {
      googleMapController = controller;
      setPolylines().then((_) => setMapFitToCenter(_polylines));
    });
  }

  Widget createOrderWidget4() {
    return Column(
      crossAxisAlignment: .start,
      children: [
        Text('Route preview', style: boldTextStyle()),
        6.height,
        Text(
          'Confirm pickup and delivery pins before placing your job.',
          style: secondaryTextStyle(size: 12),
        ),
        12.height,
        markers.isNotEmpty
            ? Container(
                decoration: boxDecorationWithRoundedCorners(
                  borderRadius: BorderRadius.circular(defaultRadius),
                  border: Border.all(
                    color: ColorUtils.colorPrimary.withValues(alpha: 0.2),
                  ),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(defaultRadius),
                  child: SizedBox(
                    width: context.width(),
                    height: context.height() * 0.62,
                    child: GoogleMap(
                      markers: markers.map((e) => e).toSet(),
                      polylines: _polylines,
                      mapType: MapType.normal,
                      cameraTargetBounds: CameraTargetBounds.unbounded,
                      initialCameraPosition: CameraPosition(
                        bearing: 192.8334901395799,
                        target: LatLng(pickLat.toDouble(), pickLong.toDouble()),
                        zoom: 12,
                      ),
                      onMapCreated: onMapCreated,
                      tiltGesturesEnabled: true,
                      scrollGesturesEnabled: true,
                      zoomGesturesEnabled: true,
                      gestureRecognizers: {
                        Factory<OneSequenceGestureRecognizer>(
                          () => EagerGestureRecognizer(),
                        ),
                      },
                    ),
                  ),
                ),
              )
            : loaderWidget(),
      ],
    );
  }

  Widget createOrderWidget5() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: .start,
        children: [
          Text(language.packageInformation, style: boldTextStyle()),
          8.height,
          Container(
            padding: .all(16),
            decoration: boxDecorationWithRoundedCorners(
              borderRadius: BorderRadius.circular(defaultRadius),
              border: Border.all(
                color: ColorUtils.colorPrimary.withValues(alpha: 0.2),
              ),
              backgroundColor: Colors.transparent,
            ),
            child: Column(
              crossAxisAlignment: .start,
              children: [
                rowWidget(
                  title: language.parcelType,
                  value: parcelTypeCont.text,
                ),
                8.height,
                rowWidget(
                  title: language.weight,
                  value:
                      '${weightController.text} ${CountryModel.fromJson(getJSONAsync(COUNTRY_DATA)).weightType}',
                ),
                8.height,
                rowWidget(
                  title: language.numberOfParcels,
                  value: '${totalParcelController.text}',
                ),
              ],
            ),
          ),
          16.height,
          addressComponent(
            title: language.pickupLocation,
            address: pickAddressCont.text,
            phoneNumber: '$pickupCountryCode ${pickPhoneCont.text.trim()}',
            personName: pickPersonNameCont.text,
            information: pickDesCont.text,
            instruction: pickInstructionCont.text,
          ),
          16.height,
          addressComponent(
            title: language.deliveryLocation,
            address: deliverAddressCont.text,
            phoneNumber: '$deliverCountryCode ${deliverPhoneCont.text.trim()}',
            personName: deliverPersonNameCont.text,
            information: deliverDesCont.text,
            instruction: deliverInstructionCont.text,
          ),
          Visibility(
            visible: appStore.isVehicleOrder != 0,
            child: Column(
              crossAxisAlignment: .start,
              children: [
                16.height,
                Text(language.selectVehicle, style: boldTextStyle()),
                8.height,
                DropdownButtonFormField<int>(
                  isExpanded: true,
                  initialValue: selectedVehicle,
                  decoration: commonInputDecoration(),
                  dropdownColor: Theme.of(context).cardColor,
                  style: primaryTextStyle(),
                  isDense: false,
                  items: vehicleList.map<DropdownMenuItem<int>>((item) {
                    String str =
                        "${language.name} : ${item.title}, ${language.price} :${appStore.currencySymbol} "
                        "${item.price}, "
                        "${language.capacity} : ${item.capacity.validate()},${language.perKmCharge} :${appStore.currencySymbol} ${item.perKmCharge.validate()}";
                    print("---------------------${item.vehicleImage}");
                    return DropdownMenuItem(
                      value: item.id,
                      child: Container(
                        child: Row(
                          mainAxisAlignment: .start,
                          children: [
                            commonCachedNetworkImage(
                              item.vehicleImage.validate(),
                              height: 40,
                              width: 40,
                            ),
                            SizedBox(width: 16),
                            Column(
                              crossAxisAlignment: .start,
                              // Align to start
                              children: [
                                Container(
                                  width: context.width() * 0.6,
                                  child: Text(
                                    str,
                                    style: primaryTextStyle(),
                                    maxLines: 4,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                  onChanged: (value) {
                    selectedVehicle = value;
                    setState(() {});
                    getTotalForOrder();
                  },
                  validator: (value) {
                    if (selectedVehicle == null)
                      return language.fieldRequiredMsg;
                    return null;
                  },
                ),
              ],
            ),
          ),
          16.height,
          //insurance start
          Row(
            mainAxisAlignment: .spaceBetween,
            children: [
              Text(language.insurance, style: boldTextStyle()),
              Icon(Icons.info, color: ColorUtils.themeColor)
                  .onTap(() {
                    InsuranceDetailsScreen(
                      appStore.insuranceDescription,
                    ).launch(context);
                  })
                  .visible(!appStore.insuranceDescription.isEmptyOrNull),
            ],
          ).visible(appStore.isInsuranceAllowed == "1"),
          16.height.visible(appStore.isInsuranceAllowed == "1"),
          InsuranceOptionsWidget(
            0,
            language.addCourierInsurance,
          ).visible(appStore.isInsuranceAllowed == "1"),
          16.height.visible(appStore.isInsuranceAllowed == "1"),
          InsuranceOptionsWidget(
            1,
            language.noThanksRisk,
          ).visible(appStore.isInsuranceAllowed == "1"),
          16.height.visible(insuranceSelectedOption == 0),
          if (appStore.isInsuranceAllowed == "1") ...[
            12.height,
            Text(
              language.approxParcelValue,
              style: primaryTextStyle(),
            ).visible(insuranceSelectedOption == 0),
            9.height,
            AppTextField(
              controller: insuranceAmountController,
              textFieldType: TextFieldType.NUMBER,
              decoration: commonInputDecoration(isFill: false),
              onChanged: (val) async {
                if (!val.isEmptyOrNull) {
                  insuranceAmount =
                      (double.parse(val) *
                          appStore.insurancePercentage.toDouble()) /
                      100;
                  await getTotalForOrder();
                  setState(() {});
                } else {
                  insuranceAmount = 0;
                  await getTotalForOrder();
                  setState(() {});
                }
              },
              onFieldSubmitted: (val) async {
                if (!val.isEmptyOrNull) {
                  insuranceAmount =
                      (double.parse(val) *
                          appStore.insurancePercentage.toDouble()) /
                      100;
                  await getTotalForOrder();
                  setState(() {});
                } else {
                  insuranceAmount = 0;
                  await getTotalForOrder();
                  setState(() {});
                }
              },
              validator: (value) {
                if (value!.isEmpty) return language.fieldRequiredMsg;
                return null;
              },
            ).visible(insuranceSelectedOption == 0),
            //16.height,
          ],
          // insurance end
          //Coupon start
          Column(
            crossAxisAlignment: .start,
            children: [
              Text("${language.offersAndBenefits}", style: boldTextStyle()),
              8.height,
              Container(
                decoration: boxDecorationWithRoundedCorners(
                  borderRadius: BorderRadius.circular(defaultRadius),
                  border: Border.all(
                    color: ColorUtils.colorPrimary.withValues(alpha: 0.2),
                  ),
                  backgroundColor: isAppliedCoupon
                      ? Colors.grey.withValues(alpha: 0.5)
                      : Colors.transparent,
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: .spaceBetween,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: .start,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    Icons.local_offer,
                                    color: ColorUtils.colorPrimary,
                                  ),
                                  SizedBox(width: 4),
                                  Expanded(
                                    child: Text(
                                      selectedCoupon?.couponCode.toString() ??
                                          "",
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: boldTextStyle(
                                        color: ColorUtils.colorPrimary,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              SizedBox(height: 4),
                              Text(
                                selectedCoupon?.valueType == "fixed"
                                    ? "${language.save} ${appStore.currencySymbol}${selectedCoupon?.discountAmount} ${language.onThisOrder}"
                                    : "${language.save} ${selectedCoupon?.discountAmount}% ${language.onThisOrder}",
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: secondaryTextStyle(),
                              ),
                            ],
                          ),
                        ),
                        TextButton(
                          onPressed: () async {
                            appStore.setLoading(true);
                            await Future.delayed(Duration(seconds: 1));
                            isAppliedCoupon = !isAppliedCoupon;
                            appStore.setLoading(false);
                            setState(() {});
                          },
                          child: Text(
                            isAppliedCoupon ? language.cancel : language.apply,
                            style: boldTextStyle(
                              color: isAppliedCoupon
                                  ? darkRed
                                  : ColorUtils.colorPrimary,
                            ),
                          ),
                        ),
                      ],
                    ).paddingAll(16),
                    10.height.visible(selectedCoupon == null ? false : true),
                    Divider(
                      color: Colors.grey.withValues(alpha: 0.3),
                      height: 0.5,
                    ).visible(selectedCoupon == null ? false : true),
                    Row(
                          mainAxisAlignment: .center,
                          children: [
                            Text(
                              "${language.moreCoupons}",
                              style: primaryTextStyle(size: 16),
                            ),
                            Icon(Icons.navigate_next, size: 18),
                          ],
                        )
                        .paddingAll(8)
                        .visible(selectedCoupon == null ? false : true)
                        .onTap(
                          isAppliedCoupon
                              ? null
                              : () {
                                  CouponListScreen().launch(context).then((
                                    result,
                                  ) {
                                    if (result != null) {
                                      selectedCoupon = result;
                                      setState(() {});
                                    }

                                    setState(() {});
                                  });
                                },
                        ),
                  ],
                ),
              ),
            ],
          ).visible(selectedCoupon == null ? false : true),
          // Coupon end
          16.height,
          if (totalAmountResponse != null) ...[
            OrderAmountDataWidget(
              fixedAmount: totalAmountResponse!.fixedAmount!.toDouble(),
              distanceAmount: totalAmountResponse!.distanceAmount!.toDouble(),
              extraCharges: totalAmountResponse!.extraCharges!,
              vehicleAmount: totalAmountResponse!.vehicleAmount!.toDouble(),
              insuranceAmount: insuranceAmount.toDouble(),
              diffWeight: totalAmountResponse!.diffWeight!.toDouble(),
              diffDistance: totalAmountResponse!.diffDistance!.toDouble(),
              totalAmount: totalAmountResponse!.totalAmount!.toDouble(),
              weightAmount: totalAmountResponse!.weightAmount!.toDouble(),
              perWeightCharge: cityData!.perWeightCharges!.toDouble(),
              perKmCityDataCharge: cityData!.perDistanceCharges!.toDouble(),
              coupon: selectedCoupon ?? null,
              isAppliedCoupon: isAppliedCoupon,
              perkmVehiclePrice: vehicleList.isNotEmpty
                  ? vehicleList
                        .firstWhere((element) => element.id == selectedVehicle)
                        .perKmCharge!
                        .toDouble()
                  : 0.00,
              baseTotal: totalAmountResponse!.baseTotal!.toDouble(),
            ),
          ],

          16.height,
          Text(language.payment, style: boldTextStyle()),
          16.height,
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: mPaymentList.map((mData) {
              return Container(
                width: (context.width() - 48) / 3,
                padding: .all(8),
                alignment: Alignment.center,
                decoration: boxDecorationWithRoundedCorners(
                  border: Border.all(
                    color: isSelected == mData.index
                        ? ColorUtils.colorPrimary
                        : ColorUtils.borderColor,
                  ),
                  backgroundColor: Colors.transparent,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: .center,
                  mainAxisAlignment: .center,
                  children: [
                    ImageIcon(
                      AssetImage(mData.image.validate()),
                      size: 20,
                      color: isSelected == mData.index
                          ? ColorUtils.colorPrimary
                          : ColorUtils.dividerColor,
                    ),
                    8.width,
                    Text(
                      mData.title!,
                      style: primaryTextStyle(
                        color: isSelected == mData.index
                            ? ColorUtils.colorPrimary
                            : textSecondaryColorGlobal,
                      ),
                    ),
                  ],
                ),
              ).onTap(() {
                isSelected = mData.index!;
                setState(() {});
              });
            }).toList(),
          ),
          16.height,
          Row(
            mainAxisAlignment: .spaceBetween,
            children: [
              Text(language.paymentCollectFrom, style: boldTextStyle()),
              16.width,
              DropdownButtonFormField<String>(
                isExpanded: true,
                isDense: true,
                initialValue: paymentCollectFrom,
                decoration: commonInputDecoration(),
                items: [
                  DropdownMenuItem(
                    value: PAYMENT_ON_PICKUP,
                    child: Text(
                      language.pickupLocation,
                      style: primaryTextStyle(),
                      maxLines: 1,
                    ),
                  ),
                  DropdownMenuItem(
                    value: PAYMENT_ON_DELIVERY,
                    child: Text(
                      language.deliveryLocation,
                      style: primaryTextStyle(),
                      maxLines: 1,
                    ),
                  ),
                ],
                onChanged: (value) {
                  paymentCollectFrom = value!;
                  setState(() {});
                },
              ).expand(),
            ],
          ).visible(isSelected == 1),
        ],
      ),
    );
  }

  Future<void> showMapScreen({
    required bool isPick,
    required bool isSaveAddress,
  }) async {
    try {
      PlaceAddressModel res = await GoogleMapScreen(
        isSaveAddress: isSaveAddress,
        isPick: isPick,
      ).launch(context);
      if (mounted) {
        if (isPick) {
          pickAddressCont.text = res.placeAddress ?? "";
          pickLat = res.latitude.toString();
          pickLong = res.longitude.toString();
        } else {
          deliverAddressCont.text = res.placeAddress ?? "";
          deliverLat = res.latitude.toString();
          deliverLong = res.longitude.toString();
        }
        setState(() {});
      }
    } catch (e) {
      print("User Cancelled $e");
    }
  }

  Widget InsuranceOptionsWidget(int value, String text) {
    return Container(
      decoration: boxDecorationWithRoundedCorners(
        backgroundColor: insuranceSelectedOption == value
            ? ColorUtils.colorPrimary
            : Colors.grey.withValues(alpha: 0.1),
      ),
      child: Row(
        children: [
          Radio<int>(
            value: value,
            // ignore: deprecated_member_use
            groupValue: insuranceSelectedOption,
            // ignore: deprecated_member_use
            onChanged: (int? newValue) {
              _onOptionSelected(newValue);
            },
            fillColor: WidgetStateProperty.resolveWith<Color?>((
              Set<WidgetState> states,
            ) {
              if (states.contains(WidgetState.selected)) {
                return Colors.white;
              }
              return ColorUtils.colorPrimary;
            }),
            activeColor: Colors.white,
          ),
          SizedBox(width: 8),
          Column(
            crossAxisAlignment: .start,
            children: [
              Text(
                text,
                style: primaryTextStyle(
                  color: insuranceSelectedOption == value
                      ? Colors.white
                      : ColorUtils.themeColor,
                ),
              ),
              if (value == 0 && insuranceSelectedOption == 0)
                Text(
                  "${appStore.insurancePercentage} ${language.ofApproxParcelValue}",
                  style: secondaryTextStyle(
                    color: Colors.white.withValues(alpha: 0.5),
                    size: 13,
                  ),
                ),
            ],
          ).expand(),
          Text(
            insuranceSelectedOption == 0 ? printAmount(insuranceAmount) : "",
            style: primaryTextStyle(color: Colors.white),
          ).visible(value == 0).paddingOnly(right: 10),
        ],
      ),
    ).onTap(() => _onOptionSelected(value));
  }

  void _onOptionSelected(int? newValue) async {
    if (newValue == null || newValue == insuranceSelectedOption) return;

    setState(() {
      insuranceSelectedOption = newValue;
      if (insuranceSelectedOption != 0) {
        insuranceAmountController.clear();
        insuranceAmount = 0.0;
      }
    });

    await getTotalForOrder();
  }

  Widget rowWidget({required String title, required String value}) {
    return Row(
      mainAxisAlignment: .spaceBetween,
      children: [
        Text(title, style: secondaryTextStyle()),
        16.width,
        Text(
          value,
          style: boldTextStyle(size: 14),
          maxLines: 3,
          textAlign: TextAlign.end,
          overflow: TextOverflow.ellipsis,
        ).expand(),
      ],
    );
  }

  Widget addressComponent({
    required String title,
    required String address,
    required String phoneNumber,
    required String personName,
    required String instruction,
    required String information,
  }) {
    return Column(
      crossAxisAlignment: .start,
      children: [
        Row(
          mainAxisAlignment: .spaceBetween,
          children: [
            Text(title, style: boldTextStyle()),
            Text(language.viewMore, style: secondaryTextStyle(size: 12)).onTap(
              () {
                showDialog(
                  context: context,
                  builder: (BuildContext context) {
                    return AlertDialog(
                      //   contentPadding: .all(8),
                      title: Column(
                        children: [
                          Row(
                            mainAxisAlignment: .spaceBetween,
                            children: [
                              Text(language.details, style: boldTextStyle()),
                              Icon(Icons.close, size: 20).onTap(() {
                                pop();
                              }),
                            ],
                          ),
                          10.height,
                          Divider(
                            height: 1,
                            thickness: 1,
                            color: Colors.grey.withValues(alpha: 0.5),
                          ),
                        ],
                      ),
                      content: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            mainAxisAlignment: .spaceBetween,
                            children: [
                              Text(
                                "${language.contactPersonName} :",
                                style: secondaryTextStyle(),
                              ),
                              Text(personName, style: boldTextStyle()),
                            ],
                          ),
                          4.height,
                          Row(
                            mainAxisAlignment: .spaceBetween,
                            children: [
                              Text(
                                "${language.information} :",
                                style: secondaryTextStyle(),
                              ),
                              Text(information, style: boldTextStyle()),
                            ],
                          ),
                          4.height,
                          Row(
                            mainAxisAlignment: .spaceBetween,
                            children: [
                              Text(
                                "${language.instruction}",
                                style: secondaryTextStyle(),
                              ),
                              Text(instruction, style: boldTextStyle()),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ],
        ),
        8.height,
        Container(
          width: context.width(),
          padding: .all(16),
          decoration: boxDecorationWithRoundedCorners(
            borderRadius: BorderRadius.circular(defaultRadius),
            border: Border.all(
              color: ColorUtils.colorPrimary.withValues(alpha: 0.2),
            ),
            backgroundColor: Colors.transparent,
          ),
          child: Column(
            crossAxisAlignment: .start,
            children: [
              Text(address, style: primaryTextStyle()),
              8.height.visible(address.isNotEmpty),
              Row(
                children: [
                  Icon(Icons.call, size: 14),
                  8.width,
                  Text(
                    phoneNumber,
                    style: secondaryTextStyle(),
                  ).visible(phoneNumber.isNotEmpty),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget progressIndicator() {
    return CircularPercentIndicator(
      radius: 20.0,
      lineWidth: 2.0,
      percent: ((selectedTabIndex + 1) / 5) > 1
          ? 1
          : (selectedTabIndex + 1) / 5,
      animation: true,
      center: Text(
        (selectedTabIndex + 1).toInt().toString() + " /5",
        style: boldTextStyle(size: 11, color: Colors.white),
      ),
      backgroundColor: Colors.white.withValues(alpha: 0.25),
      progressColor: Colors.white,
    );
  }

  bool _hasStepOneRequiredFields() {
    if (parcelTypeCont.text.trim().isEmpty) return false;
    if (weightController.text.toDouble() <= 0) return false;
    if (totalParcelController.text.toInt() <= 0) return false;
    if (isDeliverNow) return true;

    return pickDateController.text.trim().isNotEmpty &&
        pickFromTimeController.text.trim().isNotEmpty &&
        pickToTimeController.text.trim().isNotEmpty &&
        deliverDateController.text.trim().isNotEmpty &&
        deliverFromTimeController.text.trim().isNotEmpty &&
        deliverToTimeController.text.trim().isNotEmpty;
  }

  bool _hasPickupRequiredFields() {
    return pickAddressCont.text.trim().isNotEmpty &&
        pickPhoneCont.text.trim().isNotEmpty &&
        pickPersonNameCont.text.trim().isNotEmpty;
  }

  bool _hasDeliveryRequiredFields() {
    return deliverAddressCont.text.trim().isNotEmpty &&
        deliverPhoneCont.text.trim().isNotEmpty &&
        deliverPersonNameCont.text.trim().isNotEmpty;
  }

  bool get _isPrimaryActionEnabled {
    if (selectedTabIndex == 0) return _hasStepOneRequiredFields();
    if (selectedTabIndex == 1) return _hasPickupRequiredFields();
    if (selectedTabIndex == 2) return _hasDeliveryRequiredFields();
    if (selectedTabIndex == 4 &&
        insuranceSelectedOption == 0 &&
        insuranceAmountController.text.trim().isEmpty) {
      return false;
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final List<IconData> stepIcons = const [
      Icons.inventory_2_outlined,
      Icons.storefront_outlined,
      Icons.home_work_outlined,
      Icons.route_outlined,
      Icons.fact_check_outlined,
    ];
    final List<String> stepDescriptions = [
      'Set job timing and parcel basics.',
      'Add pickup address and sender contact.',
      'Add drop-off address and receiver contact.',
      'Review the pickup to destination route.',
      'Confirm pricing and place your job.',
    ];
    final double keyboardBottomInset = MediaQuery.of(context).viewInsets.bottom;
    // ignore: deprecated_member_use
    return WillPopScope(
      onWillPop: () async {
        if (selectedTabIndex == 0) {
          await showInDialog(
            context,
            contentPadding: .all(16),
            builder: (p0) {
              return CreateOrderConfirmationDialog(
                onCancel: () {
                  finish(context);
                  finish(context);
                },
                onSuccess: () async {
                  finish(context);
                  if (totalAmountResponse == null) {
                    await getTotalForOrder();
                    await createOrderApiCall(ORDER_DRAFT);
                  } else {
                    createOrderApiCall(ORDER_DRAFT);
                  }
                },
                message: language.saveDraftConfirmationMsg,
                primaryText: language.saveDraft,
              );
            },
          );
          return false;
        } else {
          if (selectedTabIndex == 4 && !shouldShowRouteReview) {
            selectedTabIndex = 2;
          } else {
            selectedTabIndex--;
          }
          setState(() {});
          return false;
        }
      },
      child: CommonScaffoldComponent(
        // appBarTitle: language.createOrder,
        appBar: commonAppBarWidget(
          appBarTitleList[selectedTabIndex],
          actions: [
            Row(children: [progressIndicator(), 10.width]),
          ],
        ),
        body: Stack(
          children: [
            SingleChildScrollView(
              padding: .only(left: 16, top: 20, right: 16, bottom: 16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: .start,
                  children: [
                    Container(
                      width: context.width(),
                      padding: .all(12),
                      decoration: boxDecorationWithRoundedCorners(
                        backgroundColor: ColorUtils.colorPrimary.withValues(
                          alpha: 0.08,
                        ),
                        borderRadius: BorderRadius.circular(defaultRadius),
                        border: Border.all(
                          color: ColorUtils.colorPrimary.withValues(alpha: 0.2),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: .start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: .all(8),
                                decoration: boxDecorationWithRoundedCorners(
                                  backgroundColor: ColorUtils.colorPrimary
                                      .withValues(alpha: 0.14),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Icon(
                                  stepIcons[selectedTabIndex],
                                  size: 16,
                                  color: ColorUtils.colorPrimary,
                                ),
                              ),
                              10.width,
                              Column(
                                crossAxisAlignment: .start,
                                children: [
                                  Text(
                                    'Step ${selectedTabIndex + 1} of ${appBarTitleList.length}',
                                    style: secondaryTextStyle(size: 11),
                                  ),
                                  2.height,
                                  Text(
                                    appBarTitleList[selectedTabIndex],
                                    style: boldTextStyle(size: 15),
                                  ),
                                ],
                              ).expand(),
                            ],
                          ),
                          8.height,
                          Text(
                            stepDescriptions[selectedTabIndex],
                            style: secondaryTextStyle(size: 12),
                          ),
                        ],
                      ),
                    ),
                    14.height,
                    if (selectedTabIndex == 0) createOrderWidget1(),
                    if (selectedTabIndex == 1) createOrderWidget2(),
                    if (selectedTabIndex == 2) createOrderWidget3(),
                    if (selectedTabIndex == 3) createOrderWidget4(),
                    if (selectedTabIndex == 4) createOrderWidget5(),
                  ],
                ),
              ),
            ),
            Observer(
              builder: (context) => loaderWidget().visible(appStore.isLoading),
            ),
          ],
        ),
        bottomNavigationBar: AnimatedPadding(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          padding: EdgeInsets.only(bottom: keyboardBottomInset),
          child: SafeArea(
            top: false,
            child: Container(
              padding: .all(16),
              child: Row(
                children: [
                  if (selectedTabIndex != 0)
                    outlineButton(language.previous, () {
                          FocusScope.of(context).requestFocus(new FocusNode());
                          if (selectedTabIndex == 4 && !shouldShowRouteReview) {
                            selectedTabIndex = 2;
                          } else {
                            selectedTabIndex--;
                          }
                          setState(() {});
                        }, color: ColorUtils.colorPrimary)
                        .paddingRight(isRTL ? 4 : 16)
                        .paddingLeft(isRTL ? 16 : 0)
                        .expand(),
                  AppButton(
                    text: selectedTabIndex != 4
                        ? language.next
                        : language.createOrder,
                    color: ColorUtils.colorPrimary,
                    textColor: Colors.white,
                    disabledColor: ColorUtils.colorPrimary.withValues(
                      alpha: 0.35,
                    ),
                    enabled: _isPrimaryActionEnabled,
                    onTap: () async {
                      if (!_isPrimaryActionEnabled) return;
                      FocusScope.of(context).requestFocus(new FocusNode());
                      log('------selected tab index${selectedTabIndex}');
                      if (selectedTabIndex != 4) {
                        if (_formKey.currentState!.validate()) {
                          Duration difference = Duration();
                          Duration differenceCurrentTime = Duration();
                          if (!isDeliverNow) {
                            pickFromDateTime = pickDate!.add(
                              Duration(
                                hours: pickFromTime!.hour,
                                minutes: pickFromTime!.minute,
                              ),
                            );
                            pickToDateTime = pickDate!.add(
                              Duration(
                                hours: pickToTime!.hour,
                                minutes: pickToTime!.minute,
                              ),
                            );
                            deliverFromDateTime = deliverDate!.add(
                              Duration(
                                hours: deliverFromTime!.hour,
                                minutes: deliverFromTime!.minute,
                              ),
                            );
                            deliverToDateTime = deliverDate!.add(
                              Duration(
                                hours: deliverToTime!.hour,
                                minutes: deliverToTime!.minute,
                              ),
                            );
                            difference = pickFromDateTime!.difference(
                              deliverFromDateTime!,
                            );
                            differenceCurrentTime = DateTime.now().difference(
                              pickFromDateTime!,
                            );
                          }
                          if (differenceCurrentTime.inMinutes > 0)
                            return toast(language.pickupCurrentValidationMsg);
                          if (difference.inMinutes > 0)
                            return toast(language.pickupDeliverValidationMsg);
                          if (selectedTabIndex == 2) {
                            await ensureAddressCoordinates();
                            if (shouldShowRouteReview) {
                              clearRoutePreviewData();
                              markers.add(
                                Marker(
                                  markerId: MarkerId("1"),
                                  position: LatLng(
                                    double.parse(pickLat!),
                                    double.parse(pickLong!),
                                  ),
                                  infoWindow: InfoWindow(
                                    title: language.sourceLocation,
                                  ),
                                  icon: await getOriginMarkerIcon(),
                                ),
                              );
                              markers.add(
                                Marker(
                                  markerId: MarkerId("2"),
                                  position: LatLng(
                                    double.parse(deliverLat!),
                                    double.parse(deliverLong!),
                                  ),
                                  infoWindow: InfoWindow(
                                    title: language.destinationLocation,
                                  ),
                                  icon: await getDestinationMarkerIcon(),
                                ),
                              );
                              selectedTabIndex = 3;
                              setState(() {});
                              await getDistance();
                            } else {
                              clearRoutePreviewData();
                              totalDistance = 0;
                              selectedTabIndex = 4;
                              setState(() {});
                              await getTotalForOrder();
                            }
                          } else {
                            selectedTabIndex++;
                            setState(() {});
                          }
                        }
                      } else {
                        if (insuranceSelectedOption == 0 &&
                            insuranceAmountController.text.isEmptyOrNull) {
                          toast(language.insuranceAmountValidation);
                          return;
                        }
                        if (isSelected == 3 &&
                            (appStore.availableBal <
                                (totalAmountResponse!.totalAmount! +
                                    insuranceAmount))) {
                          showInDialog(
                            getContext,
                            contentPadding: .all(16),
                            builder: (p0) {
                              return Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    language.balanceInsufficientCashPayment,
                                    style: primaryTextStyle(size: 16),
                                    textAlign: TextAlign.center,
                                  ),
                                  30.height,
                                  Row(
                                    children: [
                                      commonButton(language.cancel, () {
                                        finish(getContext, 0);
                                      }).expand(),
                                      6.width,
                                      commonButton(language.process, () {
                                        showConfirmDialogCustom(
                                          context,
                                          title: language
                                              .createOrderConfirmationMsg,
                                          note: language
                                              .pleaseAvoidSendingProhibitedItems,
                                          positiveText: language.yes,
                                          primaryColor: ColorUtils.colorPrimary,
                                          negativeText: language.no,
                                          onAccept: (v) {
                                            createOrderApiCall(ORDER_CREATED);
                                            finish(getContext);
                                          },
                                        );
                                      }).expand(),
                                      6.width,
                                      commonButton(language.draft, () {
                                        createOrderApiCall(ORDER_DRAFT);
                                        finish(getContext, 2);
                                      }).expand(),
                                    ],
                                  ),
                                ],
                              );
                            },
                          );
                        } else {
                          showConfirmDialogCustom(
                            context,
                            title: language.createOrderConfirmationMsg,
                            note: language.pleaseAvoidSendingProhibitedItems,
                            positiveText: language.yes,
                            primaryColor: ColorUtils.colorPrimary,
                            negativeText: language.no,
                            onAccept: (v) {
                              createOrderApiCall(ORDER_CREATED);
                            },
                          );
                        }
                      }
                    },
                  ).expand(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
