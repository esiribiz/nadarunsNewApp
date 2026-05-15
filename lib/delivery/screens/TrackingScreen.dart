import 'dart:async';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:intl/intl.dart';
import 'package:maps_launcher/maps_launcher.dart';
import '../../extensions/extension_util/context_extensions.dart';
import '../../extensions/extension_util/int_extensions.dart';
import '../../extensions/extension_util/string_extensions.dart';
import '../../extensions/extension_util/widget_extensions.dart';
import '../../extensions/decorations.dart';
import '../../extensions/text_styles.dart';
import '../../main.dart';
import '../../main/components/CommonScaffoldComponent.dart';
import '../../main/models/OrderListModel.dart';
import '../../main/network/RestApis.dart';
import '../../main/utils/Common.dart';
import '../../main/utils/Constants.dart';
import '../../main/utils/Images.dart';
import '../components/DriverDesignSystem.dart';

class TrackingScreen extends StatefulWidget {
  final int? orderId;
  final List<OrderData> order;
  final LatLng? latLng;

  TrackingScreen({
    required this.orderId,
    required this.order,
    required this.latLng,
  });

  @override
  TrackingScreenState createState() => TrackingScreenState();
}

class TrackingScreenState extends State<TrackingScreen> {
  GoogleMapController? controller;

  List<Marker> markers = [];

  late CameraPosition initialLocation;

  LatLng? sourceLocation;

  double cameraZoom = 14;

  double cameraTilt = 0;
  double cameraBearing = 30;
  late Marker deliveryBoy;
  late LatLng orderLatLong;

  final Set<Polyline> polyline = {};
  Set<Polyline> _polylines = Set<Polyline>();
  List<LatLng> polylineCoordinates = [];

  int? orderId;

  Timer? timer;

  late StreamSubscription<Position> positionStreamTraking;

  @override
  void initState() {
    super.initState();
    init();
  }

  void init() async {
    orderId = widget.orderId;
    positionStreamTraking = Geolocator.getPositionStream().listen((
      event,
    ) async {
      sourceLocation = LatLng(event.latitude, event.longitude);

      MarkerId id = MarkerId("DeliveryBoy");
      markers.removeWhere(
        (m) => m.markerId == id || m.markerId.value.startsWith('Destination_'),
      );
      deliveryBoy = Marker(
        markerId: id,
        position: LatLng(event.latitude, event.longitude),
        infoWindow: InfoWindow(
          title: language.yourLocation,
          snippet:
              '${language.lastUpdateAt} ${DateFormat('yyyy-MM-dd hh:mm').format(DateTime.now())}',
        ),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
      );

      markers.add(deliveryBoy);
      widget.order.map((e) {
        markers.add(
          Marker(
            markerId: MarkerId('Destination_${e.id}'),
            position: e.status == ORDER_ACCEPTED || e.status == ORDER_ARRIVED
                ? LatLng(
                    e.pickupPoint!.latitude.toDouble(),
                    e.pickupPoint!.longitude.toDouble(),
                  )
                : LatLng(
                    e.deliveryPoint!.latitude.toDouble(),
                    e.deliveryPoint!.longitude.toDouble(),
                  ),
            infoWindow: InfoWindow(
              title: e.status == ORDER_ACCEPTED || e.status == ORDER_ARRIVED
                  ? e.pickupPoint!.address
                  : e.deliveryPoint!.address,
            ),
            icon: BitmapDescriptor.defaultMarkerWithHue(
              BitmapDescriptor.hueOrange,
            ),
          ),
        );
      }).toList();

      setPolyLines(orderLat: orderLatLong);
      if (controller != null) {
        onMapCreated(controller!);
      }
      setState(() {});
    });

    orderLatLong = LatLng(widget.latLng!.latitude, widget.latLng!.longitude);
  }

  Future<void> setPolyLines({required LatLng orderLat}) async {
    _polylines.clear();
    polylineCoordinates.clear();
    String? originLat = sourceLocation!.latitude.toString();
    String? originLong = sourceLocation!.longitude.toString();
    String? destinationLat = orderLat.latitude.toString();
    String? destinationLong = orderLat.longitude.toString();
    String origins = "${originLat},${originLong}";
    String destinations = "${destinationLat},${destinationLong}";
    await getPolylineData(origins, destinations).then((value) async {
      if (value.status != null && value.status!) {
        if (value.polyline != null) {
          final points = decodePolyline(value.polyline!);
          if (points.isNotEmpty) {
            polylineCoordinates = points;
            _polylines.add(
              Polyline(
                visible: true,
                width: 5,
                polylineId: PolylineId('poly'),
                color: Color.fromARGB(255, 40, 122, 198),
                points: polylineCoordinates,
              ),
            );
            setState(() {});
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
  }

  Future<void> onMapCreated(GoogleMapController cont) async {
    cont.moveCamera(
      CameraUpdate.newLatLngZoom(
        LatLng(sourceLocation!.latitude, sourceLocation!.longitude),
        14,
      ),
    );
  }

  @override
  void setState(fn) {
    if (mounted) super.setState(fn);
  }

  @override
  void dispose() {
    positionStreamTraking.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CommonScaffoldComponent(
      appBarTitle: language.trackingOrder,
      body: sourceLocation != null
          ? Stack(
              alignment: Alignment.bottomCenter,
              children: [
                GoogleMap(
                  markers: markers.map((e) => e).toSet(),
                  polylines: _polylines,
                  mapType: MapType.normal,
                  initialCameraPosition: CameraPosition(
                    target: sourceLocation!,
                    zoom: cameraZoom,
                    tilt: cameraTilt,
                    bearing: cameraBearing,
                  ),
                  onMapCreated: onMapCreated,
                ),
                Positioned(
                  top: 16,
                  left: 16,
                  right: 16,
                  child: DriverCard(
                    margin: EdgeInsets.zero,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    child: Row(
                      children: [
                        DriverMetricPill(
                          icon: Icons.route_outlined,
                          label: 'Active stops',
                          value: '${widget.order.length}',
                        ),
                        8.width,
                        DriverMetricPill(
                          icon: Icons.gps_fixed,
                          label: 'Tracking',
                          value: orderId != null ? '#$orderId' : '--',
                        ),
                      ],
                    ),
                  ),
                ),
                Container(
                  constraints: BoxConstraints(
                    maxHeight: context.height() * 0.38,
                  ),
                  decoration: BoxDecoration(
                    color: context.scaffoldBackgroundColor,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(20),
                      topRight: Radius.circular(20),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.08),
                        blurRadius: 16,
                        offset: const Offset(0, -4),
                      ),
                    ],
                  ),
                  child: ListView.separated(
                    padding: .symmetric(vertical: 14),
                    shrinkWrap: true,
                    itemCount: widget.order.length,
                    itemBuilder: (_, index) {
                      OrderData data = widget.order[index];
                      final bool isSelected = orderId == data.id;
                      final bool toPickup =
                          data.status == ORDER_ACCEPTED ||
                          data.status == ORDER_ARRIVED;
                      final String destinationAddress = toPickup
                          ? data.pickupPoint!.address.validate()
                          : data.deliveryPoint!.address.validate();
                      return Container(
                        margin: const EdgeInsets.symmetric(horizontal: 12),
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? const Color(0xFFEFF6FF)
                              : Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isSelected
                                ? DriverPalette.primary.withValues(alpha: 0.25)
                                : Colors.grey.withValues(alpha: 0.15),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: .start,
                          children: [
                            Row(
                              mainAxisAlignment: .spaceBetween,
                              children: [
                                Text(
                                  '${language.order} #${data.id}',
                                  style: boldTextStyle(),
                                ),
                                Row(
                                  children: [
                                    Container(
                                      decoration:
                                          boxDecorationWithRoundedCorners(
                                            borderRadius: radius(defaultRadius),
                                            backgroundColor: context.cardColor,
                                          ),
                                      padding: .all(4),
                                      child: Image.asset(
                                        ic_google_map,
                                        height: 24,
                                        width: 24,
                                      ),
                                    ).onTap(() {
                                      if (toPickup) {
                                        MapsLauncher.launchCoordinates(
                                          data.pickupPoint!.latitude.toDouble(),
                                          data.pickupPoint!.longitude
                                              .toDouble(),
                                        );
                                      } else {
                                        MapsLauncher.launchCoordinates(
                                          data.deliveryPoint!.latitude
                                              .toDouble(),
                                          data.deliveryPoint!.longitude
                                              .toDouble(),
                                        );
                                      }
                                    }),
                                    10.width,
                                    SizedBox(
                                      width: 94,
                                      child: DriverPrimaryButton(
                                        label: language.track,
                                        leading: Icons.navigation_outlined,
                                        onTap: () async {
                                          orderId = data.id;
                                          orderLatLong = toPickup
                                              ? LatLng(
                                                  data.pickupPoint!.latitude
                                                      .toDouble(),
                                                  data.pickupPoint!.longitude
                                                      .toDouble(),
                                                )
                                              : LatLng(
                                                  data.deliveryPoint!.latitude
                                                      .toDouble(),
                                                  data.deliveryPoint!.longitude
                                                      .toDouble(),
                                                );
                                          await setPolyLines(
                                            orderLat: orderLatLong,
                                          );
                                          setState(() {});
                                        },
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            8.height,
                            DriverAddressRow(
                              label: toPickup
                                  ? language.pickupLocation
                                  : language.deliveryLocation,
                              address: destinationAddress,
                              isPickup: toPickup,
                            ),
                          ],
                        ),
                      );
                    },
                    separatorBuilder: (_, index) => 8.height,
                  ),
                ),
              ],
            )
          : loaderWidget(),
    );
  }
}
