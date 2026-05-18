import 'dart:core';
import 'dart:convert';
import 'dart:math';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_ringtone_player/flutter_ringtone_player.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:intl/intl.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';
import '../../delivery/screens/DeliveryDashBoard.dart';
import '../../extensions/extension_util/int_extensions.dart';
import '../../extensions/extension_util/string_extensions.dart';
import '../../extensions/extension_util/widget_extensions.dart';
import '../../main/utils/dynamic_theme.dart';
import 'package:onesignal_flutter/onesignal_flutter.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../extensions/common.dart';
import '../../extensions/extension_util/device_extensions.dart';
import '../../extensions/shared_pref.dart';
import '../../extensions/system_utils.dart';
import '../../extensions/text_styles.dart';
import '../../extensions/widgets.dart';
import '../../main.dart';
import '../../main/utils/Colors.dart';
import '../../main/utils/Constants.dart';
import '../../user/screens/DashboardScreen.dart';
import '../../user/screens/OrderDetailScreen.dart';
import '../../user/screens/OrderTrackingScreen.dart';
import '../Chat/ChatScreen.dart';
import '../models/LoginResponse.dart';
import '../models/OrderListModel.dart';
import '../network/RestApis.dart';
import '../screens/LoginScreen.dart';
import '../services/AuthServices.dart';
import 'Images.dart';
import 'Widgets.dart';

InputDecoration commonInputDecoration({
  String? hintText,
  IconData? suffixIcon,
  Function()? suffixOnTap,
  Widget? dateTime,
  Widget? prefixIcon,
  bool? isFill = true,
}) {
  return InputDecoration(
    errorMaxLines: 3,
    contentPadding: .all(16),
    filled: true,
    prefixIcon: prefixIcon,
    isDense: true,
    hintText: hintText != null ? hintText : '',
    hintStyle: secondaryTextStyle(size: 16, color: Colors.grey),
    fillColor: ColorUtils.colorPrimary.withValues(alpha: 0.06),
    counterText: '',
    suffixIcon: dateTime != null
        ? dateTime
        : suffixIcon != null
        ? Icon(
            suffixIcon,
            color: ColorUtils.colorPrimary,
            size: 22,
          ).onTap(suffixOnTap)
        : null,
    enabledBorder: OutlineInputBorder(
      borderSide: BorderSide(
        style: BorderStyle.solid,
        color: ColorUtils.colorPrimary.withValues(alpha: 0.9),
      ),
      borderRadius: BorderRadius.circular(defaultRadius),
    ),
    focusedBorder: OutlineInputBorder(
      borderSide: BorderSide(color: ColorUtils.colorPrimary),
      borderRadius: BorderRadius.circular(defaultRadius),
    ),
    errorBorder: OutlineInputBorder(
      borderSide: BorderSide(color: Colors.red),
      borderRadius: BorderRadius.circular(defaultRadius),
    ),
    focusedErrorBorder: OutlineInputBorder(
      borderSide: BorderSide(color: Colors.red),
      borderRadius: BorderRadius.circular(defaultRadius),
    ),
  );
}

Widget commonCachedNetworkImage(
  String? url, {
  double? height,
  double? width,
  BoxFit? fit,
  Color? color,
  AlignmentGeometry? alignment,
  bool usePlaceholderIfUrlEmpty = true,
  double? radius,
}) {
  if (url.validate().isEmpty) {
    return placeHolderWidget(
      height: height,
      width: width,
      fit: fit,
      alignment: alignment,
      radius: radius,
    );
  } else if (url.validate().startsWith('http')) {
    return CachedNetworkImage(
      imageUrl: url!,
      height: height,
      width: width,
      color: color,
      fit: fit,
      alignment: alignment as Alignment? ?? Alignment.center,
      fadeInDuration: const Duration(milliseconds: 180),
      fadeOutDuration: const Duration(milliseconds: 120),
      placeholderFadeInDuration: const Duration(milliseconds: 120),
      errorWidget: (_, s, d) {
        return placeHolderWidget(
          height: height,
          width: width,
          fit: fit,
          alignment: alignment,
          radius: radius,
        );
      },
      placeholder: (_, s) {
        if (!usePlaceholderIfUrlEmpty) return SizedBox();
        return placeHolderWidget(
          height: height,
          width: width,
          fit: fit,
          alignment: alignment,
          radius: radius,
        );
      },
    );
  } else {
    return Image.asset(
      url!,
      height: height,
      width: width,
      fit: fit,
      alignment: alignment ?? Alignment.center,
    ).cornerRadiusWithClipRRect(radius ?? defaultRadius);
  }
}

Widget placeHolderWidget({
  double? height,
  double? width,
  BoxFit? fit,
  AlignmentGeometry? alignment,
  double? radius,
}) {
  return Container(
    height: height,
    width: width,
    alignment: alignment ?? Alignment.center,
    color: appStore.isDarkMode
        ? ColorUtils.cardDarkColor
        : Colors.grey.shade200,
  ).cornerRadiusWithClipRRect(radius ?? defaultRadius);
}

Color statusColor(String status) {
  Color color = ColorUtils.colorPrimary;
  switch (status) {
    case ORDER_ACCEPTED:
      return acceptColor;
    case ORDER_CREATED:
      return CreatedColorColor;
    case ORDER_DEPARTED:
      return acceptColor;
    case ORDER_ASSIGNED:
      return pendingApprovalColorColor;
    case ORDER_PICKED_UP:
      return in_progressColor;
    case ORDER_ARRIVED:
      return in_progressColor;
    case ORDER_CANCELLED:
      return cancelledColor;
    case ORDER_DELIVERED:
      return completedColor;
    case ORDER_DRAFT:
      return holdColor;
    case ORDER_DELAYED:
      return WaitingStatusColor;
  }
  return color;
}

Color paymentStatusColor(String status) {
  Color color = ColorUtils.colorPrimary;
  if (status == PAYMENT_PAID) {
    color = Colors.green;
  } else if (status == PAYMENT_FAILED) {
    color = Colors.red;
  } else if (status == PAYMENT_PENDING) {
    color = ColorUtils.colorPrimary;
  }
  return color;
}

String parcelTypeIcon(String? parcelType) {
  String icon = 'assets/icons/ic_product.png';
  switch (parcelType.validate().toLowerCase()) {
    case "documents":
      return 'assets/icons/ic_document.png';
    case "document":
      return 'assets/icons/ic_document.png';
    case "food":
      return 'assets/icons/ic_food.png';
    case "foods":
      return 'assets/icons/ic_food.png';
    case "cake":
      return 'assets/icons/ic_cake.png';
    case "flowers":
      return 'assets/icons/ic_flower.png';
    case "flower":
      return 'assets/icons/ic_flower.png';
  }
  return icon;
}

String printDate(String date) {
  return DateFormat('dd MMM yyyy').format(DateTime.parse(date).toLocal()) +
      " at " +
      DateFormat('hh:mm a').format(DateTime.parse(date).toLocal());
}

String printDateWithoutAt(String date) {
  return DateFormat('dd MMM yyyy').format(DateTime.parse(date).toLocal()) +
      " " +
      DateFormat('hh:mm a').format(DateTime.parse(date).toLocal());
}

Widget loaderWidget() {
  return Center(
    child: LoadingAnimationWidget.hexagonDots(
      color: ColorUtils.colorPrimary,
      size: 50,
    ),
  );
}

Widget emptyWidget() {
  return Center(
    child: Image.asset(
      ic_no_data,
      width: 80,
      height: 80,
      color: ColorUtils.colorPrimary,
    ),
  );
}

String orderStatus(String orderStatus) {
  if (orderStatus == ORDER_ASSIGNED) {
    return language.assigned;
  } else if (orderStatus == ORDER_DRAFT) {
    return language.draft;
  } else if (orderStatus == ORDER_CREATED) {
    return language.created;
  } else if (orderStatus == ORDER_ACCEPTED) {
    return language.accepted;
  } else if (orderStatus == ORDER_PICKED_UP) {
    return language.pickedUp;
  } else if (orderStatus == ORDER_ARRIVED) {
    return language.arrived;
  } else if (orderStatus == ORDER_DEPARTED) {
    return language.departed;
  } else if (orderStatus == ORDER_DELIVERED) {
    return language.delivered;
  } else if (orderStatus == ORDER_CANCELLED) {
    return language.cancelled;
  } else if (orderStatus == ORDER_SHIPPED) {
    return language.shipped;
  } else if (orderStatus == ORDER_PENDING) {
    return language.pending;
  } else if (orderStatus == "reject_bid") {
    return language.bidRejected;
  } else if (orderStatus == "bid_accept") {
    return language.bidAccepted;
  } else if (orderStatus == "bid_placed") {
    return language.bidPlaced;
  } else {
    return language.reschedule;
  }
}

List<LatLng> decodePolyline(String encoded) {
  List<LatLng> polyline = [];
  int index = 0;
  int len = encoded.length;
  int lat = 0;
  int lng = 0;

  while (index < len) {
    int b;
    int shift = 0;
    int result = 0;

    do {
      b = encoded.codeUnitAt(index++) - 63;
      result |= (b & 0x1f) << shift;
      shift += 5;
    } while (b >= 0x20);

    int dlat = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
    lat += dlat;

    shift = 0;
    result = 0;

    do {
      b = encoded.codeUnitAt(index++) - 63;
      result |= (b & 0x1f) << shift;
      shift += 5;
    } while (b >= 0x20);

    int dlng = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
    lng += dlng;

    polyline.add(LatLng(lat / 1E5, lng / 1E5));
  }

  return polyline;
}

String countName(String count) {
  if (count == TODAY_ORDER) {
    return language.todayOrder;
  } else if (count == REMAINING_ORDER) {
    return language.remainingOrder;
  } else if (count == COMPLETED_ORDER) {
    return language.completedOrder;
  } else if (count == INPROGRESS_ORDER) {
    return language.inProgressOrder;
  } else if (count == TOTAL_EARNING) {
    return language.commission;
  } else if (count == WALLET_BALANCE) {
    return language.walletBalance;
  } else if (count == PENDING_WITHDRAW_REQUEST) {
    return language.pendingWithdReq;
  } else if (count == COMPLETED_WITHDRAW_REQUEST) {
    return language.completedWithReq;
  }
  return "";
}

String transactionType(String type) {
  if (type == TRANSACTION_ORDER_FEE) {
    return language.orderFee;
  } else if (type == TRANSACTION_TOPUP) {
    return language.topup;
  } else if (type == TRANSACTION_ORDER_CANCEL_CHARGE) {
    return language.orderCancelCharge;
  } else if (type == TRANSACTION_ORDER_CANCEL_REFUND) {
    return language.orderCancelRefund;
  } else if (type == TRANSACTION_CORRECTION) {
    return language.correction;
  } else if (type == TRANSACTION_COMMISSION) {
    return language.commission;
  } else if (type == TRANSACTION_WITHDRAW) {
    return language.withdraw;
  }
  return type;
}

bool isTrackableOrderStage(String? status) {
  return status == ORDER_ASSIGNED ||
      status == ORDER_ACCEPTED ||
      status == ORDER_ARRIVED ||
      status == ORDER_PICKED_UP ||
      status == ORDER_DEPARTED;
}

bool _canOpenLiveTracking(OrderData? orderData) {
  if (orderData == null) return false;
  if (getStringAsync(USER_TYPE) != CLIENT) return false;
  return isTrackableOrderStage(orderData.status.validate()) &&
      orderData.deliveryManId.validate() > 0;
}

final Set<String> _orderNotificationTypes = <String>{
  ORDER_CREATED,
  ORDER_ACCEPTED,
  ORDER_CANCELLED,
  ORDER_DELAYED,
  ORDER_ASSIGNED,
  ORDER_ARRIVED,
  ORDER_PICKED_UP,
  ORDER_DELIVERED,
  ORDER_DEPARTED,
  ORDER_TRANSFER,
  ORDER_PAYMENT,
  ORDER_FAIL,
  'reschedule',
  'return',
  'bid_placed',
  'bid_accept',
  'reject_bid',
  'deliveryman_reject_bid',
  'courier_auto_assign_cancelled',
}.map((e) => e.toLowerCase()).toSet();

bool isOrderNotificationType(String? notificationType) {
  String normalizedType = notificationType?.trim().toLowerCase() ?? '';
  return normalizedType.isNotEmpty &&
      _orderNotificationTypes.contains(normalizedType);
}

int? getOrderIdFromNotificationPayload({
  required dynamic notificationId,
  String? notificationType,
}) {
  if (notificationId == null) return null;

  String rawId = notificationId.toString().trim();
  if (rawId.isEmpty) return null;

  bool hasLegacyOrderPrefix = rawId.toUpperCase().startsWith('ORDER_');
  bool isOrderType = isOrderNotificationType(notificationType);
  if (!isOrderType && !hasLegacyOrderPrefix) return null;

  if (hasLegacyOrderPrefix) {
    String orderIdPart = rawId.substring(rawId.indexOf('_') + 1);
    return int.tryParse(orderIdPart);
  }

  int? directOrderId = int.tryParse(rawId);
  if (directOrderId != null) return directOrderId;

  String numericOnly = rawId.replaceAll(RegExp(r'[^0-9]'), '');
  return numericOnly.isNotEmpty ? int.tryParse(numericOnly) : null;
}

void openDefaultNotificationDestination() {
  if (getStringAsync(USER_TYPE) == DELIVERY_MAN) {
    DeliveryDashBoard().launch(getContext);
  } else {
    DashboardScreen().launch(getContext);
  }
}

Future<void> openOrderFromNotification({
  required int orderId,
  String? notificationType,
}) async {
  bool shouldTryTracking = getStringAsync(USER_TYPE) == CLIENT;
  if (shouldTryTracking) {
    try {
      final details = await getOrderDetails(orderId);
      if (_canOpenLiveTracking(details.data)) {
        OrderTrackingScreen(orderData: details.data!).launch(getContext);
        return;
      }
    } catch (e) {
      log(e.toString());
    }
  }
  OrderDetailScreen(orderId: orderId).launch(getContext);
}

oneSignalSettings() async {
  if (isMobile) {
    PermissionStatus status = await Permission.notification.status;
    if (!status.isGranted) {
      await Permission.notification.request();
    }

    OneSignal.Debug.setLogLevel(OSLogLevel.verbose);
    OneSignal.Debug.setAlertLevel(OSLogLevel.none);
    OneSignal.consentRequired(false);
    OneSignal.initialize(mOneSignalAppId);
    OneSignal.Notifications.requestPermission(true);
    saveOneSignalPlayerId();
    OneSignal.Notifications.addPermissionObserver((state) {
      print("Has permission " + state.toString());
    });
    OneSignal.Notifications.addClickListener((notification) async {
      Map<String, dynamic> additionalData =
          notification.notification.additionalData ?? {};
      var notId = additionalData["id"];
      String notificationType = additionalData["type"]?.toString() ?? '';
      if (!appStore.isLoggedIn) {
        LoginScreen().launch(getContext);
      } else if (notId != null && notId.toString().contains('CHAT')) {
        UserData user = await getUserDetail(
          int.parse(notId.toString().replaceAll("CHAT_", "")),
        );
        ChatScreen(userData: user).launch(getContext);
      } else {
        int? orderId = getOrderIdFromNotificationPayload(
          notificationId: notId,
          notificationType: notificationType,
        );
        if (orderId != null) {
          await openOrderFromNotification(
            orderId: orderId,
            notificationType: notificationType,
          );
        } else {
          openDefaultNotificationDestination();
        }
      }
    });
    OneSignal.Notifications.addForegroundWillDisplayListener((event) {
      print(
        'NOTIFICATION WILL DISPLAY LISTENER CALLED WITH: ${event.notification.jsonRepresentation()}',
      );
      event.preventDefault();
      event.notification.display();
      String notificationType =
          event.notification.additionalData?["type"]?.toString() ?? '';
      if (notificationType.contains(ORDER_TRANSFER) ||
          notificationType.contains(ORDER_ASSIGNED)) {
        if (getStringAsync(USER_TYPE) == DELIVERY_MAN) {
          playSoundForDuration();
        }
      }
    });
  }
}

// Method to play the sound for 60 seconds
void playSoundForDuration() async {
  try {
    FlutterRingtonePlayer().play(
      fromAsset: "assets/ringtone/ringtone.mp3",
      looping: true,
    );
    await Future.delayed(Duration(seconds: 60));
    FlutterRingtonePlayer().stop();
  } catch (e) {
    print('Error playing sound: $e');
  }
}

Future<void> saveOneSignalPlayerId() async {
  OneSignal.User.pushSubscription.addObserver((state) async {
    print(OneSignal.User.pushSubscription.optedIn);
    print("Player Id" + OneSignal.User.pushSubscription.id.toString());
    print(OneSignal.User.pushSubscription.token);
    print(state.current.jsonRepresentation());

    if (OneSignal.User.pushSubscription.id.validate().isNotEmpty)
      await setValue(PLAYER_ID, OneSignal.User.pushSubscription.id.validate());
  });
}

String statusTypeIcon({String? type}) {
  String icon = ic_order;
  if (type == ORDER_ASSIGNED) {
    icon = ic_order_assigned;
  } else if (type == ORDER_ACCEPTED) {
    icon = ic_order_accept;
  } else if (type == ORDER_PICKED_UP) {
    icon = ic_order_pickedUp;
  } else if (type == ORDER_ARRIVED) {
    icon = ic_order_arrived;
  } else if (type == ORDER_DEPARTED) {
    icon = ic_order_departed;
  } else if (type == ORDER_DELIVERED) {
    icon = ic_order_delivered;
  } else if (type == ORDER_CANCELLED) {
    icon = ic_order_cancelled;
  } else if (type == ORDER_CREATED) {
    icon = ic_order_created;
  } else if (type == ORDER_DRAFT) {
    icon = ic_order_draft;
  } else if (type == ORDER_TRANSFER) {
    icon = ic_order_transfer;
  } else if (type == "reject_bid") {
    icon = ic_bid;
  } else if (type == "bid_accept") {
    icon = ic_bid;
  } else if (type == "bid_placed") {
    icon = ic_bid;
  }
  return icon;
}

String? orderTitle(String orderStatus) {
  if (orderStatus == ORDER_ASSIGNED) {
    return language.orderAssignConfirmation;
  } else if (orderStatus == ORDER_ACCEPTED) {
    return language.orderPickupConfirmation;
  } else if (orderStatus == ORDER_PICKED_UP) {
    return language.orderDepartedConfirmation;
  } else if (orderStatus == ORDER_ARRIVED) {
    return language.orderPickupConfirmation;
  } else if (orderStatus == ORDER_DEPARTED) {
    return language.orderCompleteConfirmation;
  } else if (orderStatus == ORDER_DELIVERED) {
    return '';
  } else if (orderStatus == ORDER_CANCELLED) {
    return language.orderCancelConfirmation;
  } else if (orderStatus == ORDER_CREATED) {
    return language.orderCreateConfirmation;
  } else if (orderStatus == ORDER_PENDING) {
    return "Are you sure you want to accept this Order";
  }
  return '';
}

String dateParse(String date) {
  return DateFormat.yMd().add_jm().format(DateTime.parse(date).toLocal());
}

bool get isRTL => rtlLanguage.contains(appStore.selectedLanguage);

num countExtraCharge({
  required num totalAmount,
  required String chargesType,
  required num charges,
}) {
  if (chargesType == CHARGE_TYPE_PERCENTAGE) {
    return (totalAmount * charges * 0.01)
        .toStringAsFixed(digitAfterDecimal)
        .toDouble();
  } else {
    return charges.toStringAsFixed(digitAfterDecimal).toDouble();
  }
}

String paymentStatus(String paymentStatus) {
  if (paymentStatus.toLowerCase() == PAYMENT_PENDING.toLowerCase()) {
    return language.pending;
  } else if (paymentStatus.toLowerCase() == PAYMENT_FAILED.toLowerCase()) {
    return language.failed;
  } else if (paymentStatus.toLowerCase() == PAYMENT_PAID.toLowerCase()) {
    return language.paid;
  }
  return language.pending;
}

String? paymentCollectForm(String paymentType) {
  if (paymentType.toLowerCase() == PAYMENT_ON_PICKUP.toLowerCase()) {
    return language.onPickup;
  } else if (paymentType.toLowerCase() == PAYMENT_ON_DELIVERY.toLowerCase()) {
    return language.onDelivery;
  }
  return language.onPickup;
}

String paymentType(String paymentType) {
  if (paymentType.toLowerCase() == PAYMENT_TYPE_STRIPE.toLowerCase()) {
    return language.stripe;
  } else if (paymentType.toLowerCase() == PAYMENT_TYPE_RAZORPAY.toLowerCase()) {
    return language.razorpay;
  } else if (paymentType.toLowerCase() == PAYMENT_TYPE_PAYSTACK.toLowerCase()) {
    return language.payStack;
  } else if (paymentType.toLowerCase() ==
      PAYMENT_TYPE_FLUTTERWAVE.toLowerCase()) {
    return language.flutterWave;
  } else if (paymentType.toLowerCase() ==
      PAYMENT_TYPE_MERCADOPAGO.toLowerCase()) {
    return language.mercadoPago;
  } else if (paymentType.toLowerCase() == PAYMENT_TYPE_PAYPAL.toLowerCase()) {
    return language.paypal;
  } else if (paymentType.toLowerCase() == PAYMENT_TYPE_PAYTABS.toLowerCase()) {
    return language.payTabs;
  } else if (paymentType.toLowerCase() == PAYMENT_TYPE_PAYTM.toLowerCase()) {
    return language.paytm;
  } else if (paymentType.toLowerCase() ==
      PAYMENT_TYPE_MYFATOORAH.toLowerCase()) {
    return language.myFatoorah;
  } else if (paymentType.toLowerCase() == PAYMENT_TYPE_CASH.toLowerCase()) {
    return language.cash;
  } else if (paymentType.toLowerCase() == PAYMENT_TYPE_WALLET.toLowerCase()) {
    return language.wallet;
  }
  return language.cash;
}

String printAmount(var amount) {
  return appStore.currencyPosition == CURRENCY_POSITION_LEFT
      ? '${appStore.currencySymbol} ${amount.toStringAsFixed(digitAfterDecimal)}'
      : '${amount.toStringAsFixed(digitAfterDecimal)} ${appStore.currencySymbol}';
}

Future<void> commonLaunchUrl(String url, {bool forceWebView = false}) async {
  log(url);
  await launchUrl(
    Uri.parse(url),
    mode: LaunchMode.externalApplication,
  ).then((value) {}).catchError((e) {
    toast('${language.invalidUrl}: $url');
  });
}

cashConfirmDialog() {
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
          commonButton(language.ok, () {
            finish(getContext);
          }),
        ],
      );
    },
  );
}

Future deleteAccount(BuildContext context) async {
  appStore.setLoading(true);
  await userService
      .removeDocument(getStringAsync(UID))
      .then((value) async {
        await deleteUserFirebase()
            .then((value) async {
              Map deleteAccountReq = {
                "id": getIntAsync(USER_ID),
                "type": "forcedelete",
              };
              await userAction(deleteAccountReq).then((value) async {
                await logout(context, isDeleteAccount: true).then((
                  value,
                ) async {
                  appStore.setLoading(false);
                  await removeKey(USER_EMAIL);
                  await removeKey(USER_PASSWORD);
                });
              });
            })
            .catchError((error) {
              appStore.setLoading(false);
              toast(error.toString());
            });
      })
      .catchError((error) {
        appStore.setLoading(false);
        toast(error.toString());
      });
}

String timeAgo(String date) {
  if (date.contains("week ago")) {
    return date.splitBefore("week ago").trim() + "w";
  }
  if (date.contains("year ago")) {
    return date.splitBefore("year ago").trim() + "y";
  }
  if (date.contains("month ago")) {
    return date.splitBefore("month ago").trim() + "m";
  }
  return date.toString();
}

String getMessageFromErrorCode(FirebaseException error) {
  switch (error.code) {
    case "ERROR_EMAIL_ALREADY_IN_USE":
    case "account-exists-with-different-credential":
    case "email-already-in-use":
      return "The email address is already in use by another account.";
    case "ERROR_WRONG_PASSWORD":
    case "wrong-password":
      return "Wrong email/password combination.";
    case "ERROR_USER_NOT_FOUND":
    case "user-not-found":
      return "No user found with this email.";
    case "ERROR_USER_DISABLED":
    case "user-disabled":
      return "User disabled.";
    case "ERROR_TOO_MANY_REQUESTS":
    case "operation-not-allowed":
      return "Too many requests to log into this account.";
    case "ERROR_OPERATION_NOT_ALLOWED":
      return "Server error, please try again later.";
    case "ERROR_INVALID_EMAIL":
    case "invalid-email":
      return "Email address is invalid.";
    default:
      return error.message.toString();
  }
}

List<String> userTypeList = [CLIENT, DELIVERY_MAN];

// Future<void> openMap(double latitude, double longitude) async {
//   String googleUrl = 'https://www.google.com/maps/search/?api=1&query=$latitude,$longitude';
//   if (await canLaunchUrl(Uri.parse(googleUrl))) {
//     await launchUrl(Uri.parse(googleUrl));
//   } else {
//     throw language.mapLoadingError;
//   }
// }

Future<void> openMap(
  double originLatitude,
  double originLongitude,
  double destinationLatitude,
  double destinationLongitude,
) async {
  String googleUrl =
      'https://www.google.com/maps/dir/?api=1&origin=$originLatitude,$originLongitude&destination=$destinationLatitude,$destinationLongitude';

  if (await canLaunchUrl(Uri.parse(googleUrl))) {
    await launchUrl(Uri.parse(googleUrl));
  } else {
    throw language.mapLoadingError;
  }
}

Future<void> openMapToLocation(double latitude, double longitude) async {
  String googleUrl =
      'https://www.google.com/maps/search/?api=1&query=$latitude,$longitude';

  if (await canLaunchUrl(Uri.parse(googleUrl))) {
    await launchUrl(Uri.parse(googleUrl));
  } else {
    throw language.mapLoadingError;
  }
}

Future<BitmapDescriptor> createMarkerIconFromAsset(String assetPath) async {
  final ByteData data = await rootBundle.load(assetPath);
  final Uint8List bytes = data.buffer.asUint8List();
  return BitmapDescriptor.bytes(bytes);
}

// Base64 encoded marker icons
const String _originMarkerBase64 = 'iVBORw0KGgoAAAANSUhEUgAAAOEAAADhCAMAAAAJbSJIAAAAmVBMVEX///8AkwAAkQAAjQAAjwAAjAD7/vsQmhAAigAAlAD2/Pbv+O/z+vP5/fnl8+W127Wp1amj0aNKqkqOx445ozlSrVKq0KrN583G48Zesl6azZrA4cC33LfG38bi8+JwuXAgmyDW7NZmtmZ2vXaHxYdasVowoTBCpUIqnyp9v31gtWDP5c+TypPZ6tlNpk2ezZ54uHh/vH9AqEAZb6f7AAALjUlEQVR4nO2daWOiOheAh5CAiIIKjgoOi3XrrbV3/P8/7oJiSzY2K0nfN8+XWUTMIcnZchJ+/VIoFAqFQqFQKBQKhUKhUCgUCoVCoVAoFArFd2OMbGcRuu7EDReOPTJEt+d7iZbb+GAChJCekf0BzUu8DaP/DTFtd7PXEARAwwAA6tp+s7ZFt+9B7Kmv64RsmJy6fpmMRLeyM0a4QlXi3YWEm4XopnZiON2jWvEKIdHFFd3c9gRmffeVZITJD5PRtfTm4t1AyVJ0q5uTzlBb+fJ+RCtHdMsb4pGWoSlQm4puexMcv/UA/UKfy28f3a4deANoss/GbZcZiHdjIFqGKozdAyP0U8RYtBh8RntY3XhQUCPibCxaEg52wm86gAha+/PqynlvQR3yL4YXOV1V58hrM0DWygsd+7Nrhraz9naA69XBg4wijjgCAl17WTIDwXEYQ45rB335QkeDLSCAvlvRWGPis0crnPXX9IbMmUoGzcK6Ly7ZLh6UTaNuWWZCN2vlywkT5pflsosuox8A9Bp+2/BY0xHJ5N1EjAbq/nvzG6QsSwok8lEZWkbfttKG45geBWD+rPa2hp6EAK7b3iQY0E9p8ozWdmBBjTBgRe1vEzKGuiQh8YFsGjh2atnCIgWEq+9uaycm5BgFJk/AaPEnY8n7mB4MUujTIfXkAUeCxQHAPKsPwYoziJekugHJ09rdnC354HV2fne4GXyOZjB4Zd+MGg8SKJsROQn1D+Z19hF7EvqMHT28ks/rKDxW9IgmwQ3zsuGeeBLwwLSXhk9cp4vOFA8T4pmb7L6hHXPOo3CIcQpEx1Eu0SDEtvQsv3XA1pMfxKWi1ekcH1Q8R4vs6eu1e/a1xDgFYm1iRHYh2wyEzBCQo3QX5D2FOuCEnoEcI0BZlNvVnAhwg3ciZCvnnjCJRnNs/YadqeA8jxR/HrzR3AspPvq4mYd/WklITe4Obvx3QQ7SlHNdSwkJ503//az214NHvsDnXddSQmLwC9SmRPICclf/Yram2fKuP+HXJ8Lyw0tcrw+4av2DKSHfIYuI+d0i4/O94EagQudFTHvIzzQR3qm4AGOHtQOe+FeuGJ0IX/jX4yEGf8I+GeJJVzmQrHSjVTG71tj4F5Z0swmVV6UPptQ4rfSoiSdiCoovHMJWVDbDI0SsTjcOj/jFgsJgB2s0qFlKCcqLTECrWdGYYU9vICir+IZJWKsOUr9YEQVwMK9rMu7JIkGlfXhMxIsUSiw3ZtZw83LieXdf4IYINVrD+n5whce132G5CsgYlmers+N1zhQ2uveTwTMYHN04jBFMOGMyNSH8y9ZPIf70BJl8QsI31jVRnkQEFlN6N1M4GjwwPZs/P0XCRaFAUUzJ4axu0xhYrB5e/hAJv6J1qHmYINEruH8GWINYDgkJTUPrO6yECGrzYBENs5kZLb0ZKGkS4NMG/TeuaVqvRn4PuLVgPGfC3wYQZh2W5H8SgSWdHMYjRFE5UzxLQ9clrBvXKdLJYTxmRoJ8GgcPD6lgiEzE8aFDSzwZZQnyS20skw12xMesTD4PnexEH7u1sAIp/EGbQ/xTchWpshOJZJODLbvCv/3JhONVTRZW0MvHxO3lG66mBalSct2dUKZhq3JhwpoSiVhhJRkGNpaIAJFcOq2GyERiGSBw6FMonBU+ErHP2GsVXAmx3Cm+dN64Pu4J4BYPt8u7VhKCf8vfxf1B7mJBDxh40g+ziOd2EmJDHFfSSZ8ikeBD0SrbC6pSqlrCsjW1sRI3kYOUSmSUtClVVFEjYdmo40pqIHBx7devMe7WlBafHpAQr7Lir2j1A54xKkdQ7TRNeQ5/VJnZ3iGywiUPetFqB1RpeWmEF25UJf97Ae8qVHrg20GDHUC3nUKwXOfm4aZC1KrMJ8QaolZSp5N4ftkfkyQxuSTJce/P49fS6MZHhQYEGsMCPAokixWMeoj74fl8GWq9iTDw0TggwG8nKp9fxiBCeWZysDEpMUZF1tJ8EuAz8SH7RRZpilqwwCG0O6+sshEzIjt3/L5mPkJARIJ6ZwW/IRSz8PLZgiGZVNM7+sqvZPXsXpZdiAFVf96pF1+o20jShRnUhgTUYffgnNq3IdjnLjOhfFDY9nAEx5dzO0mBQVbiZyKardq3tqg7gMuzmtsFRpkz0LmFeRRGzEg9IvEeaZk5I4aAzTbJ5h3IKgqTbCNwysyOonmDflgc2JGkJDvzPmGXkAI4r+nHcMbZri40/8SC2v90l1FPAm5vRCeLd5qUJYux/2LKXaeA6HJ6o4yHvfD2iJv55+y9EUpVcg1AZJ3j4M9bGmWkb8tTfLZQxdkf4lYMqyD3upCNBvfzTK5/qc7fiKt7roStbLrAr3EXy+i7BNSSYf2vCYF2T7shR2TPZNYqz80DkjUPEtFu7Z6LROdhUJy+QdmIXqiogQ6j2iKnKfzi/WFlwzuvQBq8VkUmNEjojtEmtFwZpXpQqsCeDTtSbAoUuqTdkEfGqf4jDjBtVbKHI8NaWhPITfotJJRdj94hD35oCpInx10HK/NWjyRnJjXCodL8DQCJzP4oiUsfTVYLYzuDzGxaW8UWKXIpGFacR8tEjhX7NtAnk9VI+BOcGZxTuzpvuYNCNm1MhmzLMM2wm5sMIG1yrRr22UnMMSrXUmFzmkYZ6GdEFCyaZRcfKTESjd1EQHAUXSP7CGED7+3HTsIb9VPxR1pC23l3p0Uwu6vxbe6WcLl+d36EyUiXp80s0ZCOrFssZFfvJAX7m1gbhHRrf46nC4m9N2ftXfI3cBWLn3cTkFZOxSJvUeySAfkmaHMWhNLpHsOZvJgD7JUVYHAP9+jDd0qTsLhoiH0VIpT8leidc+PF1i+/xSHrB4S041e1CH9tGH3GhOsEoPLadyYlODc4A6UH0pfka3t91q6BdvkbhM6otPt6zEsvwlLycDx6d4N/96A0ErJH5XuCp+Vwmujw3hwdJPOPkDW2HLaAgHXSXLQ+XbTPIZHdVeRL5xxPK6wd0MHhJeSPKXLbSfEt7hfS35v9fWQAZE7FbMc3TkW9HUDaZlKTyg0Y2qY6Ozp+D+b3rtSPIryCxfHWLxDt1g0sNV1eieorpe2JX1RNoVnv2fDgeqoVgMePhqbrQp523WyJItqa8DYhe841bq8WGvnNq8+IiL95QJFrs+uP9TpSr9MKWq1+E0++tVknHHpXpdNnxvi6CKrvWrpW5S1gLWuCrqdN8Q5DfwZ5Fq3DloqvSKr1e4CMfLtQ140q7bFhx5Nv75FUh6eTb/kC+77sYp5DA13KI42bXkRdnk5+zALsa5jmP2Z18vztA8rc8k7Z37xQZ9CXhPku7a7mKYzjbt+8bovvS8LriQDcd8k8h9zW9FjHkL/fif+6nGewzA1ij9Xt18VBAHtzMsbX97f2WnZ624+MZv1stF5fnXxmNPk8FuDmeO+ev4HOPVxjKNh3HUPx5magJ9Nn/nLkWbdAGK36j4JPxeGOUN9NniKk4QSXIjyEppBUhhPDIsjXwXlLb/t57ObLV/+ex4CaJyp/Gr3cd/bkmdyDx0xDdbht+Opb+meaBpxEZk6H08+MUZ4XQ9YucJ1x121nxjidnC7XxOn9lmAmvtYt9fzSeaSZmANtH2+DpePYTSU1bOc9DF5XR4hKefNs8M8/5FjFyFTCSivvRMuXH5BuJYfz6sWbLP8s0jRy7NI518bQdqI0XfwJp9t4dfZNLRONSOxb8XMUWFeMZTADOvGy7fz0IAj1e7YeJAXFP68fZYLh+9jyNwhaq6kUCX2KdL2dHTW9du8dm+v2PWs/90I5hiaPcfQ2eY0PZj6lYBNR837WEQLJOd667z+lSPiXMbLf19PT31U+xQYo4/ryyjv5P/L/HCDLvGy80yTMpqnoNj/AMEoX4dp1f3/huutwkTrC396oUCgUCoVCoVAoFAqFQqFQKBQKhUKhUCj+r/gPB/qbEvqMdSQAAAAASUVORK5CYII=';

const String _destinationMarkerBase64 = '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';

Future<BitmapDescriptor> getOriginMarkerIcon() async {
  final Uint8List bytes = const Base64Decoder().convert(_originMarkerBase64);
  return BitmapDescriptor.bytes(bytes);
}

Future<BitmapDescriptor> getDestinationMarkerIcon() async {
  final Uint8List bytes = const Base64Decoder().convert(_destinationMarkerBase64);
  return BitmapDescriptor.bytes(bytes);
}

Color colorFromHex(String hexColor) {
  hexColor = hexColor.toUpperCase().replaceAll("#", "");
  if (hexColor.length == 6) {
    hexColor = "FF$hexColor";
  }
  return Color(int.parse(hexColor, radix: 16));
}

getClaimStatus(String status) {
  if (status == STATUS_PENDING) {
    return Text(status, style: boldTextStyle(color: pendingColor));
  } else if (status == STATUS_IN_REVIEW) {
    return Text(status, style: boldTextStyle(color: WaitingStatusColor));
  } else if (status == APPROVED) {
    return Text(status, style: boldTextStyle(color: acceptColor));
  } else if (status == STATUS_REJECTED) {
    return Text(status, style: boldTextStyle(color: rejectedColor));
  } else {
    return Text(status, style: boldTextStyle(color: completedColor));
  }
}
//List<String> SUPPORT_TYPE = ["Vehicle", "Orders", "Delivery person"];

Widget popupDialog(String title, String message) {
  return Dialog(
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    child: Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: Colors.white,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          /// Warning Icon
          Container(
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.red.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.warning_rounded, color: Colors.red, size: 40),
          ),
          SizedBox(height: 16),

          /// Title
          Text(
            title,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.red,
            ),
          ),
          SizedBox(height: 12),

          /// Message
          Text(
            message,
            textAlign: TextAlign.left,
            style: TextStyle(fontSize: 14, color: Colors.black87),
          ),
          SizedBox(height: 24),

          /// Button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                padding: EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              onPressed: () {
                pop();
              },
              child: Text(
                "UNDERSTOOD",
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

String generate6DigitCode() {
  final random = Random();
  int code = 100000 + random.nextInt(900000);
  return code.toString();
}
