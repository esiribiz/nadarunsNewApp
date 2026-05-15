import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:http/http.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import '../../extensions/decorations.dart';
import '../../extensions/extension_util/bool_extensions.dart';
import '../../extensions/extension_util/context_extensions.dart';
import '../../extensions/extension_util/int_extensions.dart';
import '../../extensions/extension_util/string_extensions.dart';
import '../../extensions/extension_util/widget_extensions.dart';
import '../../main/network/NetworkUtils.dart';
import '../../main/utils/Widgets.dart';
import 'package:path_provider/path_provider.dart';
import 'package:screenshot/screenshot.dart';
import 'package:syncfusion_flutter_signaturepad/signaturepad.dart';

import '../../extensions/app_text_field.dart';
import '../../extensions/common.dart';
import '../../extensions/confirmation_dialog.dart';
import '../../extensions/system_utils.dart';
import '../../extensions/text_styles.dart';
import '../../extensions/widgets.dart';
import '../../main.dart';
import '../../main/components/CommonScaffoldComponent.dart';
import '../../main/models/OrderListModel.dart';
import '../../main/network/RestApis.dart';
import '../../main/utils/Common.dart';
import '../../main/utils/Constants.dart';
import '../../main/utils/dynamic_theme.dart';
import '../../user/components/CancelOrderDialog.dart';
import '../components/DriverDesignSystem.dart';

class ReceivedScreenOrderScreen extends StatefulWidget {
  final OrderData? orderData;
  final bool isShowPayment;

  ReceivedScreenOrderScreen({this.orderData, this.isShowPayment = false});

  @override
  ReceivedScreenOrderScreenState createState() =>
      ReceivedScreenOrderScreenState();
}

class ReceivedScreenOrderScreenState extends State<ReceivedScreenOrderScreen> {
  final GlobalKey<FormState> formKey = GlobalKey<FormState>();

  GlobalKey<SfSignaturePadState> signaturePicUPPadKey = GlobalKey();
  GlobalKey<SfSignaturePadState> signatureDeliveryPadKey = GlobalKey();

  ScreenshotController pickupScreenshotController = ScreenshotController();
  ScreenshotController deliveryScreenshotController = ScreenshotController();

  TextEditingController picUpController = TextEditingController();
  TextEditingController deliveryDateController = TextEditingController();
  TextEditingController reasonController = TextEditingController();

  XFile? imageProfile;
  int val = 0;

  File? imageSignature;
  File? deliverySignature;
  bool mIsUpdate = false;
  int groupVal = 0;
  String? reason;
  bool mIsCheck = false;

  String? _pickupDatetime;
  String? _deliveryDatetime;

  List<File>? _image = [];
  final ImagePicker _picker = ImagePicker();

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

  String _formatDateTimeForDisplay(DateTime dateTime) {
    return DateFormat('yyyy-MM-dd HH:mm:ss').format(dateTime);
  }

  String _formatDateTimeForApi(DateTime dateTime) {
    return DateFormat('yyyy-MM-dd HH:mm:ss').format(dateTime.toUtc());
  }

  @override
  void initState() {
    print("recieved order");
    print("-------isShow Payment--${widget.isShowPayment}------");
    print(
      "-------paymentCollectFrom--${widget.orderData?.paymentCollectFrom}------",
    );
    super.initState();
    init();
  }

  Future<void> _pickImage(ImageSource source) async {
    final XFile? pickedFile = await _picker.pickImage(source: source);

    if (pickedFile != null) {
      _image!.add(File(pickedFile.path));
      setState(() {});
    }
  }

  void _removeImage(int index) {
    setState(() {
      _image!.removeAt(index);
    });
  }

  Future<void> init() async {
    mIsUpdate = widget.orderData != null;
    if (mIsUpdate) {
      final DateTime now = DateTime.now();
      final String rawPickupDatetime = widget.orderData!.pickupDatetime
          .validate()
          .trim();
      final DateTime? parsedPickupDatetime = _tryParseDateTime(
        rawPickupDatetime,
      );

      if (rawPickupDatetime.isEmpty) {
        _pickupDatetime = _formatDateTimeForApi(now);
      } else if (parsedPickupDatetime != null) {
        _pickupDatetime = rawPickupDatetime;
      } else {
        _pickupDatetime = _formatDateTimeForApi(now);
      }

      picUpController.text = _formatDateTimeForDisplay(
        (parsedPickupDatetime ?? now).toLocal(),
      );
      reasonController.text = widget.orderData!.reason.validate();
      reason = widget.orderData!.reason.validate();
      log(picUpController);
    }

    if (widget.orderData!.status == ORDER_DEPARTED) {
      final DateTime now = DateTime.now();
      deliveryDateController.text = _formatDateTimeForDisplay(now.toLocal());
      _deliveryDatetime = _formatDateTimeForApi(now);
    }
  }

  Future<File> saveSignature(ScreenshotController screenshotController) async {
    final image = await screenshotController.capture(
      delay: Duration(milliseconds: 10),
    );
    final tempDir = await getTemporaryDirectory();
    File file = await File('${tempDir.path}/image.png').create();
    if (image != null) {
      file.writeAsBytesSync(image);
    }
    return file;
  }

  saveDelivery() async {
    print("4 139----------saveDelivery called");
    appStore.setLoading(true);
    await updateOrder(
          orderId: widget.orderData!.id,
          pickupDatetime: _pickupDatetime,
          deliveryDatetime: _deliveryDatetime,
          clientName: (deliverySignature != null || imageSignature != null)
              ? '1'
              : '0',
          deliveryman: deliverySignature != null ? '1' : '0',
          picUpSignature: imageSignature,
          reason: reasonController.text,
          deliverySignature: deliverySignature,
          orderStatus: widget.orderData!.status == ORDER_DEPARTED
              ? ORDER_DELIVERED
              : widget.orderData!.status == ORDER_PICKED_UP
              ? ORDER_DEPARTED
              : ORDER_PICKED_UP,
          selectedFiles: _image,
        )
        .then((value) {
          print("5----------saveDelivery response 153");
          appStore.setLoading(false);
          toast(
            widget.orderData!.status == ORDER_DEPARTED
                ? language.orderDeliveredSuccessfully
                : widget.orderData!.status == ORDER_PICKED_UP
                ? language.orderDepartedSuccessfully
                : language.orderPickupSuccessfully,
          );
          finish(context, true);
        })
        .catchError((error) {
          appStore.setLoading(false);
          toast(error.toString());
          log(error);
        });
  }

  @override
  void setState(fn) {
    if (mounted) super.setState(fn);
  }

  @override
  Widget build(BuildContext context) {
    final bool isDeparted = widget.orderData!.status == ORDER_DEPARTED;
    final bool isPickedUp = widget.orderData!.status == ORDER_PICKED_UP;
    final bool isPickupStage =
        widget.orderData!.status == ORDER_ACCEPTED ||
        widget.orderData!.status == ORDER_ARRIVED;
    return CommonScaffoldComponent(
      appBar: commonAppBarWidget(
        isDeparted || isPickedUp ? language.orderDeliver : language.orderPickup,
        backWidget: IconButton(
          onPressed: () {
            finish(context, false);
          },
          icon: Icon(Icons.arrow_back, color: Colors.white),
        ),
      ),
      body: Form(
        key: formKey,
        child: Stack(
          children: [
            Positioned.fill(
              child: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFFF6F9FF), Color(0xFFFFFFFF)],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
              ),
            ),
            SingleChildScrollView(
              padding: .only(left: 16, top: 18, right: 16, bottom: 16),
              child: Column(
                crossAxisAlignment: .start,
                children: [
                  DriverCard(
                    margin: EdgeInsets.zero,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const DriverStatusChip(
                              label: 'Order',
                              color: DriverPalette.primary,
                            ),
                            8.width,
                            Text(
                              '#${widget.orderData!.id.validate()}',
                              style: boldTextStyle(size: 16),
                            ),
                            const Spacer(),
                            DriverStatusChip(
                              label: isDeparted
                                  ? language.orderDeliver
                                  : language.orderPickup,
                              color: isDeparted
                                  ? const Color(0xFF6366F1)
                                  : DriverPalette.primary,
                            ),
                          ],
                        ),
                        14.height,
                        DriverStepProgress(
                          currentIndex: isDeparted ? 3 : (isPickedUp ? 2 : 1),
                          labels: const [
                            'Request',
                            'Pickup',
                            'Transit',
                            'Delivered',
                          ],
                          icons: const [
                            Icons.post_add_outlined,
                            Icons.inventory_2_outlined,
                            Icons.local_shipping_outlined,
                            Icons.task_alt_outlined,
                          ],
                          statusColors: const [
                            Color(0xFFF59E0B),
                            Color(0xFF2563EB),
                            Color(0xFF06B6D4),
                            Color(0xFF10B981),
                          ],
                        ),
                        if (widget.isShowPayment.validate()) ...[
                          12.height,
                          DriverMetricPill(
                            icon: Icons.account_balance_wallet_outlined,
                            label: language.collectedAmount,
                            value: printAmount(
                              widget.orderData!.totalAmount ?? 0,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (widget.orderData!.paymentId == null ||
                      widget.orderData!.paymentId == 0)
                    Container(
                      margin: const EdgeInsets.only(top: 12),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.red.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: Colors.red.withValues(alpha: 0.2),
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.info_outline, color: Colors.red),
                          12.width,
                          Expanded(
                            child:
                                widget.orderData!.paymentCollectFrom ==
                                    PAYMENT_ON_DELIVERY
                                ? Text(
                                    language.paymentCollectFromDelivery,
                                    style: secondaryTextStyle(
                                      color: Colors.red.shade700,
                                    ),
                                  )
                                : Text(
                                    language.paymentCollectFromPickup,
                                    style: secondaryTextStyle(
                                      color: Colors.red.shade700,
                                    ),
                                  ),
                          ),
                        ],
                      ),
                    ),
                  16.height,
                  DriverCard(
                    margin: EdgeInsets.zero,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${language.order} ${language.pickupDatetime.toLowerCase()}',
                          style: boldTextStyle(),
                        ),
                        8.height,
                        AppTextField(
                          readOnly: true,
                          textFieldType: TextFieldType.OTHER,
                          controller: picUpController,
                          decoration: commonInputDecoration(),
                        ),
                        if (isDeparted) ...[
                          10.height,
                          Text(
                            language.deliveryDatetime,
                            style: boldTextStyle(),
                          ),
                          8.height,
                          AppTextField(
                            readOnly: true,
                            textFieldType: TextFieldType.PHONE,
                            controller: deliveryDateController,
                            decoration: commonInputDecoration(),
                          ),
                        ],
                        14.height,
                        Text(language.userSignature, style: boldTextStyle()),
                        8.height,
                        widget.orderData!.pickupConfirmByClient == 1 ||
                                isDeparted
                            ? commonCachedNetworkImage(
                                widget.orderData!.pickupTimeSignature,
                                fit: BoxFit.cover,
                                height: 150,
                                width: context.width(),
                              )
                            : Container(
                                height: 150,
                                width: context.width(),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(
                                    defaultRadius,
                                  ),
                                  color: Colors.grey.withValues(alpha: 0.15),
                                ),
                                child: Screenshot(
                                  controller: pickupScreenshotController,
                                  child: SfSignaturePad(
                                    key: signaturePicUPPadKey,
                                    minimumStrokeWidth: 1,
                                    maximumStrokeWidth: 3,
                                    strokeColor: ColorUtils.colorPrimary,
                                  ),
                                ),
                              ),
                        if (widget.orderData!.pickupConfirmByClient != 1)
                          Align(
                            alignment: Alignment.bottomRight,
                            child: TextButton(
                              child: Text(
                                language.clear,
                                style: boldTextStyle(
                                  color: ColorUtils.colorPrimary,
                                  decoration: TextDecoration.underline,
                                ),
                              ),
                              onPressed: () async {
                                try { signaturePicUPPadKey.currentState?.clear(); } catch (e) { log('Error clearing signature: $e'); }
                              },
                            ),
                          ),
                        if (isDeparted ||
                            widget.orderData!.status == ORDER_DELIVERED) ...[
                          4.height,
                          Text(
                            language.deliveryTimeSignature,
                            style: boldTextStyle(),
                          ),
                          8.height,
                        ],
                        if (isDeparted)
                          Container(
                            height: 150,
                            width: context.width(),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(
                                defaultRadius,
                              ),
                              color: Colors.grey.withValues(alpha: 0.15),
                            ),
                            child: Screenshot(
                              controller: deliveryScreenshotController,
                              child: SfSignaturePad(
                                key: signatureDeliveryPadKey,
                                minimumStrokeWidth: 1,
                                maximumStrokeWidth: 3,
                                strokeColor: ColorUtils.colorPrimary,
                              ),
                            ),
                          ).visible(
                            isDeparted ||
                                widget.orderData!.status == ORDER_DELIVERED,
                          ),
                        if (isDeparted)
                          Align(
                            alignment: Alignment.bottomRight,
                            child: TextButton(
                              child: Text(
                                language.clear,
                                style: boldTextStyle(
                                  color: ColorUtils.colorPrimary,
                                  decoration: TextDecoration.underline,
                                ),
                              ),
                              onPressed: () async {
                                try { signatureDeliveryPadKey.currentState?.clear(); } catch (e) { log('Error clearing delivery signature: $e'); }
                              },
                            ),
                          ).visible(
                            isDeparted ||
                                widget.orderData!.status == ORDER_DELIVERED,
                          ),
                        CheckboxListTile(
                          dense: true,
                          contentPadding: .zero,
                          value: mIsCheck,
                          activeColor: ColorUtils.colorPrimary,
                          checkColor: Colors.white,
                          title: Text(
                            widget.orderData!.paymentCollectFrom ==
                                    PAYMENT_ON_DELIVERY
                                ? language.paymentCollectFrom
                                : language.isPaymentCollected,
                            style: primaryTextStyle(),
                          ),
                          onChanged: (val) {
                            mIsCheck = val!;
                            setState(() {});
                          },
                        ).visible(widget.isShowPayment),
                      ],
                    ),
                  ),
                  14.height,
                  DriverCard(
                    margin: EdgeInsets.zero,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(language.proof, style: boldTextStyle()),
                        14.height,
                        Row(
                          crossAxisAlignment: .start,
                          children: [
                            Container(
                              decoration: boxDecorationDefault(
                                border: Border.all(
                                  color: ColorUtils.colorPrimary,
                                ),
                                borderRadius: BorderRadius.circular(
                                  defaultRadius,
                                ),
                              ),
                              width: 100,
                              height: 100,
                              child: Icon(
                                Icons.add_a_photo_outlined,
                                color: ColorUtils.colorPrimary,
                                size: 24,
                              ),
                            ).onTap(() {
                              _pickImage(ImageSource.camera);
                            }),
                            10.width,
                            if (_image != null && _image!.isNotEmpty)
                              Expanded(
                                child: SizedBox(
                                  height: 120,
                                  child: ListView.builder(
                                    scrollDirection: Axis.horizontal,
                                    itemCount: _image!.length,
                                    itemBuilder: (context, index) {
                                      return buildFileWidget(
                                        _image![index],
                                        index,
                                      );
                                    },
                                  ),
                                ),
                              )
                            else
                              Expanded(
                                child: Container(
                                  height: 100,
                                  alignment: Alignment.center,
                                  decoration: boxDecorationDefault(
                                    color: const Color(0xFFF1F5F9),
                                    borderRadius: BorderRadius.circular(
                                      defaultRadius,
                                    ),
                                  ),
                                  child: Text(
                                    'Add package photos',
                                    style: secondaryTextStyle(),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  16.height,
                  Row(
                    children: [
                      Expanded(
                        child: DriverPrimaryButton(
                          label: isDeparted
                              ? language.confirmDelivery
                              : isPickedUp
                              ? language.departed
                              : language.confirmPickup,
                          onTap: () async {
                            if (!mIsCheck &&
                                (widget.orderData!.paymentId == null ||
                                    widget.orderData!.paymentId == 0) &&
                                widget.isShowPayment) {
                              return toast(language.pleaseConfirmPayment);
                            } else {
                              if (_image != null && _image!.isNotEmpty) {
                                await saveProofData();
                                await saveOrderData();
                              } else {
                                await saveOrderData();
                              }
                            }
                          },
                        ),
                      ),
                      if (isPickupStage) 12.width,
                      if (isPickupStage)
                        Expanded(
                          child: OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.red,
                              side: BorderSide(
                                color: Colors.red.withValues(alpha: 0.6),
                              ),
                              minimumSize: const Size.fromHeight(52),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            onPressed: () async {
                              showInDialog(
                                context,
                                barrierDismissible: false,
                                contentPadding: .all(16),
                                builder: (p0) {
                                  return CancelOrderDialog(
                                    orderId: widget.orderData!.id.validate(),
                                    onUpdate: () {
                                      finish(context);
                                    },
                                  );
                                },
                              );
                            },
                            child: Text(
                              language.cancelOrder,
                              style: boldTextStyle(color: Colors.red),
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            Observer(
              builder: (_) => loaderWidget().visible(appStore.isLoading),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> saveProofData() async {
    MultipartRequest multiPartRequest = await getMultiPartRequest(
      'profOfpicture-save',
    );
    multiPartRequest.fields['order_id'] = widget.orderData!.id.toString();
    multiPartRequest.fields['type'] = widget.orderData!.status == ORDER_DEPARTED
        ? ORDER_DELIVERY_TIME
        : ORDER_PICK_UP_TIME;
    if (_image != null && _image!.length > 0) {
      for (var element in _image!) {
        multiPartRequest.files.add(
          await MultipartFile.fromPath("prof_file[]", element.path),
        );
      }
    }

    multiPartRequest.headers.addAll(buildHeaderTokens());
    await sendMultiPartRequest(
      multiPartRequest,
      onSuccess: (data) async {
        if (data != null) {
          toast(data["message"]);

          //  finish(context);
          print("2 462----------saveproff data res");
          print(data.toString());
        }
      },
      onError: (error) {
        log("MULTIPART ERROR:::::::: ${error}");
        toast(error.toString(), print: true);
      },
    ).catchError((e, s) {
      log("MULTIPART ERROR:::::::: ${e}, STACKTRACE:::::: ${s}");
      toast(e.toString());
    });
  }

  Future<void> saveOrderData() async {
    print("3 479----------saveOrderData called");
    if (widget.orderData!.status == ORDER_DEPARTED) {
      if (deliveryDateController.text.isEmpty) {
        return toast(language.selectDeliveryTimeMsg);
      }
    }

    // Capture signatures based on current status
    if (widget.orderData!.status == ORDER_ACCEPTED ||
        widget.orderData!.status == ORDER_ARRIVED) {
      if (imageSignature == null) {
        try {
          imageSignature = await saveSignature(pickupScreenshotController);
          log(imageSignature!.path);
        } catch (e) {
          toast('Failed to capture pickup signature');
          log(e);
          return;
        }
      }
    }
    if (widget.orderData!.status == ORDER_DEPARTED) {
      if (deliverySignature == null) {
        try {
          deliverySignature = await saveSignature(deliveryScreenshotController);
          log(deliverySignature!.path);
        } catch (e) {
          toast('Failed to capture delivery signature');
          log(e);
          return;
        }
      }
    }

    if ((widget.orderData!.paymentId == null ||
            widget.orderData!.paymentId == 0) &&
        widget.orderData!.paymentCollectFrom == PAYMENT_ON_PICKUP &&
        (widget.orderData!.status == ORDER_ACCEPTED ||
            widget.orderData!.status == ORDER_ARRIVED)) {
      appStore.setLoading(true);
      await paymentConfirmDialog(widget.orderData!);
      appStore.setLoading(false);
    } else if ((widget.orderData!.paymentId == null ||
            widget.orderData!.paymentId == 0) &&
        widget.orderData!.paymentCollectFrom == PAYMENT_ON_DELIVERY &&
        widget.orderData!.status == ORDER_DEPARTED) {
      appStore.setLoading(true);
      await paymentConfirmDialog(widget.orderData!);
      appStore.setLoading(false);
    } else {
      showConfirmDialogCustom(
        context,
        primaryColor: ColorUtils.colorPrimary,
        dialogType: DialogType.CONFIRMATION,
        title: orderTitle(widget.orderData!.status!),
        positiveText: language.yes,
        negativeText: language.no,
        onAccept: (c) async {
          saveDelivery();
        },
      );
    }
  }

  Future<void> paymentConfirmDialog(OrderData orderData) {
    return showConfirmDialogCustom(
      context,
      primaryColor: ColorUtils.colorPrimary,
      dialogType: DialogType.CONFIRMATION,
      title: orderTitle(orderData.status!),
      positiveText: language.yes,
      negativeText: language.cancel,
      onAccept: (c) async {
        appStore.setLoading(true);
        Map req = {
          'order_id': orderData.id,
          'client_id': orderData.clientId,
          'datetime': picUpController.text,
          'total_amount': orderData.totalAmount,
          'payment_type': PAYMENT_TYPE_CASH,
          'payment_status': PAYMENT_PAID,
        };
        await savePayment(req)
            .then((value) async {
              await saveDelivery()
                  .then((value) async {
                    appStore.setLoading(false);
                    finish(context, true);
                  })
                  .catchError((error) {
                    appStore.setLoading(false);
                    log(error);
                  });
            })
            .catchError((error) {
              appStore.setLoading(false);
              log(error);
            });
      },
      onCancel: (v) {
        finish(context, false);
      },
    );
  }

  Widget buildFileWidget(File file, int index) {
    return Stack(
      children: [
        Container(
          width: 100,
          height: 100,
          decoration: boxDecorationWithRoundedCorners(
            border: Border.all(color: ColorUtils.colorPrimary),
            backgroundColor: Color(0xff1A1A1A),
          ),
          child: Image.file(
            width: 100,
            height: 100,
            File(file.path), // File object for local image display
            fit: BoxFit.cover,
          ).cornerRadiusWithClipRRect(10),
        ).paddingOnly(left: 4),
        Positioned(
          right: 4,
          top: 4,
          child:
              Container(
                    width: 20,
                    height: 20,
                    color: ColorUtils.borderColor,
                    child: Icon(
                      size: 16,
                      Icons.delete_forever,
                      color: Colors.red,
                    ).center(),
                  )
                  .onTap(() {
                    _removeImage(index);
                    setState(() {});
                  })
                  .cornerRadiusWithClipRRect(40),
        ),
      ],
    );
  }
}
