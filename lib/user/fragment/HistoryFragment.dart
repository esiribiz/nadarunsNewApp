import 'package:flutter/material.dart';
import '../../extensions/decorations.dart';
import '../../extensions/common.dart';
import '../../extensions/extension_util/context_extensions.dart';
import '../../extensions/extension_util/int_extensions.dart';
import '../../extensions/extension_util/list_extensions.dart';
import '../../extensions/extension_util/widget_extensions.dart';
import '../../extensions/text_styles.dart';
import '../../main/models/OrderListModel.dart';
import '../../main/network/RestApis.dart';
import '../../main/screens/order_history_list.dart' as history_ui;
import '../../main/utils/Common.dart';
import '../../main/utils/Constants.dart';
import '../../main/utils/dynamic_theme.dart';

class HistoryFragment extends StatefulWidget {
  @override
  State<HistoryFragment> createState() => _HistoryFragmentState();
}

class _HistoryFragmentState extends State<HistoryFragment> {
  List<OrderData> historyOrders = [];
  int page = 1;
  int totalPage = 1;
  bool isLoading = true;
  bool isLoadingMore = false;

  @override
  void initState() {
    super.initState();
    loadHistory();
  }

  Future<void> loadHistory({bool isRefresh = false}) async {
    if (isRefresh) {
      page = 1;
      totalPage = 1;
    }
    if (page > totalPage) return;

    if (isRefresh || historyOrders.isEmpty) {
      isLoading = true;
      setState(() {});
    } else {
      isLoadingMore = true;
      setState(() {});
    }

    await getUserOrderHistoryList(page: page)
        .then((value) {
          totalPage = value.pagination!.totalPages.validate(value: 1);
          if (page == 1) historyOrders.clear();
          historyOrders.addAll(value.data.validate());
          setState(() {});
        })
        .catchError((e) {
          toast(e.toString(), print: true);
        })
        .whenComplete(() {
          isLoading = false;
          isLoadingMore = false;
          setState(() {});
        });
  }

  Future<void> loadNextPage() async {
    if (isLoadingMore) return;
    if (page >= totalPage) return;
    page++;
    await loadHistory();
  }

  Widget emptyHistoryRemark() {
    return Container(
      width: context.width(),
      margin: .symmetric(horizontal: 16),
      padding: .all(16),
      decoration: boxDecorationWithRoundedCorners(
        borderRadius: BorderRadius.circular(defaultRadius),
        backgroundColor: ColorUtils.colorPrimary.withValues(alpha: 0.08),
      ),
      child: Column(
        crossAxisAlignment: .start,
        children: [
          Text('No deliveries in history yet.', style: boldTextStyle()),
          6.height,
          Text(
            'Your future parcels are probably still deciding their grand entrance.',
            style: secondaryTextStyle(size: 12),
          ),
        ],
      ),
    );
  }

  @override
  void setState(fn) {
    if (mounted) super.setState(fn);
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading && historyOrders.isEmpty) return loaderWidget();

    return RefreshIndicator(
      onRefresh: () async {
        await loadHistory(isRefresh: true);
      },
      child: NotificationListener<ScrollNotification>(
        onNotification: (ScrollNotification scrollInfo) {
          if (scrollInfo.metrics.pixels >=
              scrollInfo.metrics.maxScrollExtent - 80) {
            loadNextPage();
          }
          return false;
        },
        child: ListView(
          physics: BouncingScrollPhysics(
            parent: AlwaysScrollableScrollPhysics(),
          ),
          padding: .only(top: 16, bottom: 100),
          children: [
            if (historyOrders.isEmpty)
              SizedBox(
                height: context.height() * 0.45,
                child: Center(child: emptyHistoryRemark()),
              )
            else
              ...historyOrders
                  .map(
                    (item) => history_ui.OrderHistoryItem(
                      orderData: item,
                    ).paddingSymmetric(horizontal: 16, vertical: 4),
                  )
                  .toList(),
            loaderWidget().visible(isLoadingMore).paddingBottom(12),
          ],
        ),
      ),
    );
  }
}
