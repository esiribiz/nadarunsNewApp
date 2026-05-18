import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import '../../extensions/extension_util/int_extensions.dart';
import '../../extensions/extension_util/string_extensions.dart';
import '../../extensions/extension_util/widget_extensions.dart';
import '../../main/utils/Widgets.dart';

import '../../extensions/animatedList/animated_list_view.dart';
import '../../extensions/system_utils.dart';
import '../../extensions/text_styles.dart';
import '../../main.dart';
import '../../main/components/CommonScaffoldComponent.dart';
import '../../main/models/UserProfileDetailModel.dart';
import '../../main/network/RestApis.dart';
import '../../main/utils/Common.dart';
import '../components/DriverDesignSystem.dart';

class EarningHistoryScreen extends StatefulWidget {
  @override
  EarningHistoryScreenState createState() => EarningHistoryScreenState();
}

class EarningHistoryScreenState extends State<EarningHistoryScreen> {
  ScrollController scrollController = ScrollController();
  List<EarningData> earningList = [];
  EarningDetail earningDetail = EarningDetail();

  int currentPage = 1;
  int totalPage = 1;

  @override
  void initState() {
    super.initState();
    init();
  }

  getUserDetailApiCall() async {
    appStore.setLoading(true);
    await getUserProfile()
        .then((value) {
          appStore.setLoading(false);
          earningDetail = value.earningDetail ?? EarningDetail();
          setState(() {});
        })
        .catchError((e) {
          log(e.toString());
          appStore.setLoading(false);
        });
  }

  void init() async {
    getUserDetailApiCall();
    getPaymentListApi();
    scrollController.addListener(() {
      if (scrollController.position.pixels ==
          scrollController.position.maxScrollExtent) {
        if (currentPage < totalPage) {
          appStore.setLoading(true);
          currentPage++;
          getPaymentListApi();
        }
      }
    });
  }

  getPaymentListApi() async {
    appStore.setLoading(true);
    await getPaymentList(page: currentPage)
        .then((value) {
          currentPage = value.pagination!.currentPage!;
          totalPage = value.pagination!.totalPages!;
          if (currentPage == 1) {
            earningList.clear();
          }
          final List<EarningData> fetched = value.data ?? [];
          for (final item in fetched) {
            // Skip items with null or zero orderId
            if (item.orderId == null || item.orderId == 0) {
              continue;
            }
            // Skip items with null or zero deliveryManCommission (empty earnings)
            if (item.deliveryManCommission == null || item.deliveryManCommission == 0) {
              continue;
            }
            // Check for duplicates based on orderId only (most reliable identifier)
            final bool alreadyAdded = earningList.any(
              (existing) => existing.orderId == item.orderId,
            );
            if (!alreadyAdded) {
              earningList.add(item);
            }
          }
          setState(() {});
        })
        .catchError((e) {
          log(e);
        })
        .whenComplete(() => appStore.setLoading(false));
  }

  @override
  void setState(fn) {
    if (mounted) super.setState(fn);
  }

  @override
  Widget build(BuildContext context) {
    return CommonScaffoldComponent(
      appBar: commonAppBarWidget(language.earningHistory),
      body: Stack(
        children: [
          Positioned.fill(
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFFF7FAFF), Colors.white],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
            ),
          ),
          Column(
            children: [
              DriverCard(
                margin: const EdgeInsets.fromLTRB(16, 12, 16, 10),
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: [
                    Expanded(
                      child: DriverMetricPill(
                        icon: Icons.account_balance_wallet_outlined,
                        label: language.earning,
                        value: printAmount(
                          earningDetail.deliveryManCommission ?? 0,
                        ),
                      ),
                    ),
                    10.width,
                    Expanded(
                      child: DriverMetricPill(
                        icon: Icons.payments_outlined,
                        label: 'Charges',
                        value: printAmount(earningDetail.adminCommission ?? 0),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: AnimatedListView(
                  padding: .symmetric(vertical: 8, horizontal: 16),
                  itemCount: earningList.length,
                  shrinkWrap: true,
                  emptyWidget: Stack(
                    children: [
                      loaderWidget().visible(appStore.isLoading),
                      emptyWidget().visible(!appStore.isLoading),
                    ],
                  ),
                  onPageScrollChange: () {},
                  onNextPage: () {
                    if (currentPage < totalPage) {
                      appStore.setLoading(true);
                      currentPage++;
                      getPaymentListApi();
                    }
                  },
                  itemBuilder: (_, index) {
                    EarningData data = earningList[index];
                    return earningCardWidget(data);
                  },
                ),
              ),
            ],
          ),
          Observer(
            builder: (context) => loaderWidget().visible(appStore.isLoading),
          ),
        ],
      ),
    );
  }

  Widget earningCardWidget(EarningData data) {
    return DriverCard(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: .start,
        children: [
          Row(
            children: [
              Text(
                '${language.orderId}: #${data.orderId}',
                style: boldTextStyle(),
              ),
              Spacer(),
              DriverStatusChip(
                label: data.paymentType.validate().capitalizeFirstLetter(),
                color: DriverPalette.primary,
              ),
            ],
          ),
          SizedBox(height: 4),
          Text(
            printDate(data.createdAt.validate()),
            style: secondaryTextStyle(),
          ),
          SizedBox(height: 10),
          Row(
            mainAxisAlignment: .spaceBetween,
            children: [
              Text(
                language.earning,
                textAlign: TextAlign.center,
                style: secondaryTextStyle(size: 13),
              ),
              Text(
                '${printAmount(data.deliveryManCommission ?? 0)}',
                style: boldTextStyle(size: 16),
              ),
            ],
          ),
          SizedBox(height: 4),
          Row(
            mainAxisAlignment: .spaceBetween,
            children: [
              Text(
                'Charges',
                textAlign: TextAlign.center,
                style: secondaryTextStyle(size: 13),
              ),
              Text(
                '${printAmount(data.adminCommission ?? 0)}',
                style: boldTextStyle(size: 16),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
