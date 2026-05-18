import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:internet_file/internet_file.dart';
import 'package:intl/intl.dart';
import '../../extensions/extension_util/context_extensions.dart';
import '../../extensions/extension_util/int_extensions.dart';
import '../../extensions/extension_util/string_extensions.dart';
import '../../extensions/extension_util/widget_extensions.dart';
import '../../main/components/CommonScaffoldComponent.dart';
import '../../main/models/OrderListModel.dart';
import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdfx/pdfx.dart';
import 'package:pdfx/pdfx.dart' as pdf;

import '../../extensions/common.dart';
import '../../extensions/text_styles.dart';
import '../../main.dart';
import '../../main/utils/Common.dart';
import '../../main/utils/Constants.dart';
import '../../main/utils/Images.dart';
import '../../main/utils/Widgets.dart';
import '../../main/utils/dynamic_theme.dart';
import '../screens/OrderDetailScreen.dart';
import '../screens/OrderTrackingScreen.dart';
import 'package:http/http.dart' as http;

class NewOrderCardComponent extends StatefulWidget {
  final OrderData item;

  NewOrderCardComponent({required this.item});

  @override
  _NewOrderCardComponentState createState() => _NewOrderCardComponentState();
}

class _NewOrderCardComponentState extends State<NewOrderCardComponent> {
  @override
  Widget build(BuildContext context) {
    bool canTrackOrder = appStore.userType != DELIVERY_MAN &&
        [ORDER_ASSIGNED, ORDER_ACCEPTED, ORDER_ARRIVED, ORDER_PICKED_UP, ORDER_DEPARTED].contains(widget.item.status.validate()) &&
        widget.item.deliveryManId.validate() > 0;
    return GestureDetector(
      onTap: () {
        OrderDetailScreen(orderId: widget.item.id.validate())
            .launch(context, pageRouteAnimation: PageRouteAnimation.SlideBottomTop, duration: 400.milliseconds);
      },
      child: Container(
        margin: .only(bottom: 16),
        decoration: BoxDecoration(
          color: context.cardColor,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha:0.04),
              blurRadius: 12,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: .start,
          children: [
            // Header Section
            Container(
              padding: .all(16),
              decoration: BoxDecoration(
                color: ColorUtils.colorPrimary.withValues(alpha:0.05),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                ),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      // Parcel Icon
                      Container(
                        height: 48,
                        width: 48,
                        decoration: BoxDecoration(
                          color: ColorUtils.colorPrimary.withValues(alpha:0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Image.asset(
                          parcelTypeIcon(widget.item.parcelType.validate()),
                          height: 24,
                          width: 24,
                          color: ColorUtils.colorPrimary,
                        ).center(),
                      ),
                      12.width,
                      // Order Info
                      Expanded(
                        child: Column(
                          crossAxisAlignment: .start,
                          children: [
                            Text(
                              widget.item.parcelType.validate(),
                              style: boldTextStyle(size: 15),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            4.height,
                            Text(
                              '${widget.item.orderTrackingId}',
                              style: secondaryTextStyle(size: 13),
                            ),
                          ],
                        ),
                      ),
                      // Status Badge
                      Container(
                        padding: .symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: statusColor(widget.item.status.validate()).withValues(alpha:0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          orderStatus(widget.item.status!),
                          style: boldTextStyle(
                            size: 12,
                            color: statusColor(widget.item.status.validate()),
                          ),
                        ),
                      ),
                    ],
                  ),
                  12.height,
                  // Date and Amount Row
                  Row(
                    mainAxisAlignment: .spaceBetween,
                    children: [
                      if (widget.item.date != null)
                        Row(
                          children: [
                            Icon(Icons.access_time, size: 14, color: ColorUtils.colorPrimary.withValues(alpha:0.6)),
                            6.width,
                            Text(
                              DateFormat('dd MMM yyyy, hh:mm a').format(DateTime.parse("${widget.item.date!}")),
                              style: secondaryTextStyle(size: 12),
                            ),
                          ],
                        ),
                      if (widget.item.status != ORDER_CANCELLED)
                        Text(
                          printAmount(widget.item.totalAmount ?? 0),
                          style: boldTextStyle(size: 16, color: ColorUtils.colorPrimary),
                        ),
                    ],
                  ),
                ],
              ),
            ),

            // Location Details
            Container(
              padding: .all(16),
              child: Column(
                children: [
                  // Pickup Location
                  _buildLocationRow(
                    icon: ic_from,
                    label: widget.item.pickupDatetime != null ? language.picked : language.picked,
                    address: widget.item.pickupPoint!.address.validate(),
                    dateTime: widget.item.pickupDatetime,
                    startTime: widget.item.pickupPoint!.startTime,
                    endTime: widget.item.pickupPoint!.endTime,
                    contactNumber: widget.item.pickupPoint!.contactNumber,
                    isPicked: widget.item.pickupDatetime != null,
                    notePrefix: language.courierWillPickupAt,
                  ),

                  // Connection Line
                  Container(
                    margin: .only(left: 11, top: 8, bottom: 8),
                    child: Row(
                      children: [
                        Container(
                          width: 2,
                          height: 32,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                ColorUtils.colorPrimary.withValues(alpha:0.3),
                                ColorUtils.colorPrimary.withValues(alpha:0.1),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Delivery Location
                  _buildLocationRow(
                    icon: ic_to,
                    label: widget.item.deliveryDatetime != null ? language.delivered : language.delivered,
                    address: widget.item.deliveryPoint!.address.validate(),
                    dateTime: widget.item.deliveryDatetime,
                    startTime: widget.item.deliveryPoint!.startTime,
                    endTime: widget.item.deliveryPoint!.endTime,
                    contactNumber: widget.item.deliveryPoint!.contactNumber,
                    isPicked: widget.item.deliveryDatetime != null,
                    notePrefix: language.courierWillDeliverAt,
                  ),

                  // Reschedule Notice
                  if (widget.item.reScheduleDateTime != null)
                    Container(
                      margin: .only(top: 12),
                      padding: .all(12),
                      decoration: BoxDecoration(
                        color: Colors.orange.withValues(alpha:0.08),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.schedule, size: 16, color: Colors.orange),
                          8.width,
                          Expanded(
                            child: Text(
                              '${language.rescheduleMsg} ${DateFormat('yyyy-MM-dd').format(DateTime.parse(widget.item.reScheduleDateTime!))}',
                              style: secondaryTextStyle(size: 12, color: Colors.orange.shade700),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),

            // Action Buttons
            if (widget.item.status == ORDER_DELIVERED ||
                canTrackOrder ||
                widget.item.status != ORDER_CANCELLED)
              Container(
                padding: .only(left: 16, right: 16, bottom: 16),
                child: Row(
                  children: [
                    // Track Order Button
                    if (canTrackOrder)
                      Expanded(
                        child: Container(
                          height: 44,
                          decoration: BoxDecoration(
                            color: ColorUtils.colorPrimary,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            mainAxisAlignment: .center,
                            children: [
                              Text(
                                language.trackOrder,
                                style: boldTextStyle(color: Colors.white, size: 14),
                              ),
                              6.width,
                              Icon(Icons.arrow_forward, color: Colors.white, size: 18),
                            ],
                          ),
                        ).onTap(() {
                          OrderTrackingScreen(orderData: widget.item).launch(context);
                        }),
                      ),

                    // Invoice Button
                    if (widget.item.status == ORDER_DELIVERED)
                      Expanded(
                        child: Container(
                          height: 44,
                          decoration: BoxDecoration(
                            color: ColorUtils.colorPrimary,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            mainAxisAlignment: .center,
                            children: [
                              Icon(Icons.description_outlined, color: Colors.white, size: 18),
                              8.width,
                              Text(
                                language.invoice,
                                style: boldTextStyle(color: Colors.white, size: 14),
                              ),
                            ],
                          ),
                        ).onTap(() {
                          PDFViewer(
                            invoice: "${widget.item.invoice.validate()}",
                            filename: "${widget.item.id.validate()}",
                          ).launch(context);
                        }),
                      ),

                    // Navigation Button
                    if (widget.item.status != ORDER_DELIVERED &&
                        widget.item.status != ORDER_CANCELLED &&
                        canTrackOrder)
                      12.width,

                    if (widget.item.status != ORDER_DELIVERED && widget.item.status != ORDER_CANCELLED)
                      Container(
                        height: 44,
                        width: 44,
                        decoration: BoxDecoration(
                          color: ColorUtils.colorPrimary.withValues(alpha:0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          Icons.navigation,
                          color: ColorUtils.colorPrimary,
                          size: 20,
                        ).center(),
                      ).onTap(() {
                        openMap(
                          double.parse(widget.item.pickupPoint!.latitude.validate()),
                          double.parse(widget.item.pickupPoint!.longitude.validate()),
                          double.parse(widget.item.deliveryPoint!.latitude.validate()),
                          double.parse(widget.item.deliveryPoint!.longitude.validate()),
                        );
                      }),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildLocationRow({
    required String icon,
    required String label,
    required String address,
    String? dateTime,
    String? startTime,
    String? endTime,
    String? contactNumber,
    required bool isPicked,
    required String notePrefix,
  }) {
    return Column(
      crossAxisAlignment: .start,
      children: [
        Row(
          crossAxisAlignment: .start,
          children: [
            // Icon
            Container(
              height: 24,
              width: 24,
              child: ImageIcon(
                AssetImage(icon),
                size: 20,
                color: isPicked ? ColorUtils.colorPrimary : ColorUtils.colorPrimary.withValues(alpha:0.5),
              ),
            ),
            12.width,
            // Address and Details
            Expanded(
              child: Column(
                crossAxisAlignment: .start,
                children: [
                  Text(
                    label,
                    style: secondaryTextStyle(size: 12, color: ColorUtils.colorPrimary.withValues(alpha:0.7)),
                  ),
                  4.height,
                  Text(
                    address,
                    style: primaryTextStyle(size: 14),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (dateTime != null) ...[
                    6.height,
                    Container(
                      padding: .symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: ColorUtils.colorPrimary.withValues(alpha:0.08),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        printDateWithoutAt("${dateTime}Z"),
                        style: secondaryTextStyle(size: 11),
                      ),
                    ),
                  ],
                  if (dateTime == null && startTime != null && endTime != null) ...[
                    6.height,
                    Container(
                      padding: .all(8),
                      decoration: BoxDecoration(
                        color: Colors.red.withValues(alpha:0.06),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: Colors.red.withValues(alpha:0.2)),
                      ),
                      child: Text(
                        '$notePrefix ${DateFormat('dd MMM yyyy').format(DateTime.parse(startTime).toLocal())} ${language.from} ${DateFormat('hh:mm').format(DateTime.parse(startTime).toLocal())} ${language.to} ${DateFormat('hh:mm').format(DateTime.parse(endTime).toLocal())}',
                        style: secondaryTextStyle(size: 11, color: Colors.red.shade700),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            // Call Button
            if (contactNumber != null && widget.item.status != COMPLETED)
              Container(
                height: 36,
                width: 36,
                decoration: BoxDecoration(
                  color: ColorUtils.colorPrimary.withValues(alpha:0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.phone,
                  size: 18,
                  color: ColorUtils.colorPrimary,
                ).center(),
              ).onTap(() {
                commonLaunchUrl('tel:$contactNumber');
              }),
          ],
        ),
      ],
    );
  }
}

class PDFViewer extends StatefulWidget {
  final String invoice;
  final String? filename;

  PDFViewer({required this.invoice, this.filename = ""});

  @override
  State<PDFViewer> createState() => _PDFViewerState();
}

class _PDFViewerState extends State<PDFViewer> {
  PdfController? pdfController;

  @override
  void initState() {
    super.initState();
    viewPDF();
  }

  Future<void> viewPDF() async {
    try {
      setState(() {
        appStore.setLoading(true);
        pdfController = PdfController(
          document: pdf.PdfDocument.openData(InternetFile.get("${widget.invoice}")),
        );
        appStore.setLoading(false);
      });
    } catch (e) {
      print('Error viewing PDF: $e');
    }
  }

  Future<void> downloadPDF() async {
    appStore.setLoading(true);
    final response = await http.get(Uri.parse(widget.invoice));
    if (response.statusCode == 200) {
      final bytes = response.bodyBytes;
      final directory = await getExternalStorageDirectory();
      final path = directory!.path;
      String fileName = widget.filename.validate().isEmpty ? "invoice" : widget.filename.validate();
      File file = File('${path}/${fileName}.pdf');
      await file.writeAsBytes(bytes, flush: true);
      appStore.setLoading(false);
      toast("Invoice downloaded at ${file.path}");
      final filef = File(file.path);
      if (await filef.exists()) {
        OpenFile.open(file.path);
      } else {
        throw 'File does not exist';
      }
    } else {
      appStore.setLoading(false);
      toast("Failed to download PDF");
      throw Exception('Failed to download PDF');
    }
  }

  @override
  Widget build(BuildContext context) {
    return CommonScaffoldComponent(
      appBar: commonAppBarWidget(
        language.invoice,
        actions: [
          Icon(Icons.download, color: Colors.white).withWidth(60).onTap(
                () {
              downloadPDF();
            },
            splashColor: Colors.transparent,
            hoverColor: Colors.transparent,
            highlightColor: Colors.transparent,
          ),
        ],
      ),
      body: Stack(
        children: [
          if (pdfController != null)
            PdfView(
              controller: pdfController!,
            ),
          if (pdfController != null)
            PdfPageNumber(
              controller: pdfController!,
              builder: (_, loadingState, page, pagesCount) {
                if (page == 0) return loaderWidget();
                return SizedBox();
              },
            ),
          Observer(builder: (context) {
            return loaderWidget().visible(appStore.isLoading);
          }),
        ],
      ),
    );
  }
}