import 'dart:async';

import 'package:flutter/material.dart';
import '../../extensions/LiveStream.dart';
import '../../extensions/common.dart';
import '../../extensions/decorations.dart';
import '../../extensions/extension_util/context_extensions.dart';
import '../../extensions/extension_util/int_extensions.dart';
import '../../extensions/extension_util/list_extensions.dart';
import '../../extensions/extension_util/widget_extensions.dart';
import '../../extensions/text_styles.dart';
import '../../main.dart';
import '../../main/models/OrderListModel.dart';
import '../../main/network/RestApis.dart';
import '../../main/utils/Common.dart';
import '../../main/utils/Constants.dart';
import '../../main/utils/dynamic_theme.dart';
import '../components/NewOrderCardComponent.dart';
import '../screens/CreateOrderScreen.dart';

class OrderFragment extends StatefulWidget {
  static String tag = '/OrderFragment';

  @override
  OrderFragmentState createState() => OrderFragmentState();
}

class OrderFragmentState extends State<OrderFragment>
    with WidgetsBindingObserver {
  List<OrderData> orderList = [];
  bool isLoadingOrders = true;
  Timer? _ordersRefreshTimer;
  bool _isFetchingOrders = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    init();
    LiveStream().on('UpdateOrderData', (p0) {
      getOrderListApiCall();
    });
    _startOrdersAutoRefresh();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      getOrderListApiCall();
    }
  }

  Future<void> getOrderData() async {
    await getOrderListApiCall(showLoader: true);
  }

  Future<void> init() async {
    await getOrderData();
  }

  void _startOrdersAutoRefresh() {
    _ordersRefreshTimer?.cancel();
    _ordersRefreshTimer = Timer.periodic(const Duration(seconds: 4), (timer) {
      if (!mounted) return;
      getOrderListApiCall();
    });
  }

  Future<void> getOrderListApiCall({bool showLoader = false}) async {
    if (_isFetchingOrders) return;
    _isFetchingOrders = true;
    if (showLoader && orderList.isEmpty) {
      isLoadingOrders = true;
      setState(() {});
    }
    await getOrderList(page: 1, excludeStatus: ORDER_DRAFT)
        .then((value) {
          appStore.setAllUnreadCount(value.allUnreadCount.validate());

          if (value.walletData != null) {
            appStore.availableBal = value.walletData!.totalAmount;
          }
          orderList = value.data
              .validate()
              .where(
                (e) =>
                    e.status != ORDER_DELIVERED &&
                    e.status != ORDER_CANCELLED &&
                    e.status != ORDER_DRAFT,
              )
              .toList();
        })
        .catchError((e) {
          if (orderList.isEmpty) {
            orderList.clear();
          }
          if (showLoader) {
            toast(e.toString(), print: true);
          }
        })
        .whenComplete(() {
          isLoadingOrders = false;
          _isFetchingOrders = false;
          setState(() {});
        });
  }

  Future<void> openCreateOrderFlow() async {
    await CreateOrderScreen().launch(
      context,
      pageRouteAnimation: PageRouteAnimation.Fade,
    );
    await getOrderListApiCall();
  }

  String greetingLabel() {
    int hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }

  Widget quickLocationTile({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Row(
      children: [
        Icon(icon, size: 20, color: textPrimaryColorGlobal),
        12.width,
        Column(
          crossAxisAlignment: .start,
          children: [
            Text(title, style: primaryTextStyle()),
            2.height,
            Text(subtitle, style: secondaryTextStyle(size: 12)),
          ],
        ).expand(),
      ],
    ).paddingSymmetric(vertical: 8).onTap(() {
      openCreateOrderFlow();
    });
  }

  Widget dashboardPromptCard() {
    return Container(
      width: context.width(),
      padding: .all(16),
      decoration: boxDecorationWithRoundedCorners(
        borderRadius: BorderRadius.circular(defaultRadius),
        border: Border.all(
          color: ColorUtils.colorPrimary.withValues(alpha: 0.15),
        ),
      ),
      child: Column(
        crossAxisAlignment: .start,
        children: [
          Row(
            children: [
              Column(
                crossAxisAlignment: .start,
                children: [
                  Text(greetingLabel(), style: secondaryTextStyle()),
                  4.height,
                  Text('What are you sending?', style: boldTextStyle(size: 22)),
                ],
              ).expand(),
              commonCachedNetworkImage(
                appStore.userProfile,
                width: 44,
                height: 44,
                fit: BoxFit.cover,
              ).cornerRadiusWithClipRRect(22),
            ],
          ),
          14.height,
          Container(
            width: context.width(),
            padding: .symmetric(horizontal: 12, vertical: 12),
            decoration: boxDecorationWithRoundedCorners(
              borderRadius: BorderRadius.circular(defaultRadius),
              backgroundColor: appStore.isDarkMode
                  ? ColorUtils.scaffoldSecondaryDark
                  : Colors.grey.shade100,
            ),
            child: Row(
              children: [
                Icon(Icons.search, size: 18),
                10.width,
                Text('Where to?', style: secondaryTextStyle()),
              ],
            ),
          ).onTap(() {
            openCreateOrderFlow();
          }),
          12.height,
          quickLocationTile(
            icon: Icons.work_outline,
            title: 'Work',
            subtitle: '123 Business St, City',
          ),
          quickLocationTile(
            icon: Icons.home_outlined,
            title: 'Home',
            subtitle: '456 Main St, City',
          ),
          quickLocationTile(
            icon: Icons.local_airport_outlined,
            title: 'Airport',
            subtitle: 'City Airport',
          ),
          4.height,
          Text(
            'See all',
            style: boldTextStyle(color: ColorUtils.colorPrimary),
          ).onTap(() {
            openCreateOrderFlow();
          }),
        ],
      ),
    );
  }

  Widget suggestionsCard() {
    return Container(
      width: context.width(),
      padding: .all(14),
      decoration: boxDecorationWithRoundedCorners(
        borderRadius: BorderRadius.circular(defaultRadius),
        border: Border.all(
          color: ColorUtils.colorPrimary.withValues(alpha: 0.15),
        ),
      ),
      child: Row(
        crossAxisAlignment: .start,
        children: [
          Icon(Icons.shopping_bag_outlined, color: ColorUtils.colorPrimary),
          10.width,
          Column(
            crossAxisAlignment: .start,
            children: [
              Text('Shopping Mall', style: boldTextStyle()),
              4.height,
              Text('789 Market St, City', style: secondaryTextStyle(size: 12)),
            ],
          ).expand(),
        ],
      ),
    ).onTap(() {
      openCreateOrderFlow();
    });
  }

  Widget activeJobsSection() {
    if (isLoadingOrders && orderList.isEmpty) {
      return loaderWidget();
    }
    if (orderList.isEmpty) {
      return Container(
        width: context.width(),
        padding: .all(14),
        decoration: boxDecorationWithRoundedCorners(
          borderRadius: BorderRadius.circular(defaultRadius),
          backgroundColor: ColorUtils.colorPrimary.withValues(alpha: 0.08),
        ),
        child: Column(
          crossAxisAlignment: .start,
          children: [
            Text('No active deliveries right now.', style: boldTextStyle()),
            6.height,
            Text(
              'Your next package adventure is one tap away.',
              style: secondaryTextStyle(size: 12),
            ),
            10.height,
            Text(
              'Create new job',
              style: boldTextStyle(color: ColorUtils.colorPrimary),
            ).onTap(() {
              openCreateOrderFlow();
            }),
          ],
        ),
      );
    }
    return Column(
      children: [
        ...orderList
            .take(3)
            .map((item) => NewOrderCardComponent(item: item).paddingBottom(12))
            .toList(),
        Container(
          width: context.width(),
          padding: .symmetric(horizontal: 12, vertical: 10),
          decoration: boxDecorationWithRoundedCorners(
            borderRadius: BorderRadius.circular(defaultRadius),
            backgroundColor: ColorUtils.colorPrimary.withValues(alpha: 0.08),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.info_outline,
                size: 16,
                color: ColorUtils.colorPrimary,
              ),
              8.width,
              Text(
                "Tap any active job to follow its live progress and delivery updates.",
                style: secondaryTextStyle(size: 12),
              ).expand(),
            ],
          ),
        ),
      ],
    );
  }

  @override
  void setState(fn) {
    if (mounted) super.setState(fn);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _ordersRefreshTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: () async {
        await getOrderListApiCall();
      },
      child: ListView(
        key: const PageStorageKey<String>('user-order-home-list'),
        physics: BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
        padding: .only(left: 16, right: 16, top: 16, bottom: 100),
        children: [
          dashboardPromptCard(),
          22.height,
          Text('Suggestions', style: boldTextStyle(size: 18)),
          10.height,
          suggestionsCard(),
          22.height,
          Row(
            children: [
              Text('Active jobs', style: boldTextStyle(size: 18)).expand(),
              Text(
                'New job',
                style: boldTextStyle(color: ColorUtils.colorPrimary),
              ).onTap(() {
                openCreateOrderFlow();
              }),
            ],
          ),
          10.height,
          activeJobsSection(),
        ],
      ),
    );
  }
}
