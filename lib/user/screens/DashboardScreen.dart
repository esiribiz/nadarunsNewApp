import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart' as firestore;
import 'package:crisp_chat/crisp_chat.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:flutter_vector_icons/flutter_vector_icons.dart';
import '../../extensions/extension_util/context_extensions.dart';
import '../../extensions/extension_util/int_extensions.dart';
import '../../extensions/extension_util/string_extensions.dart';
import '../../extensions/extension_util/widget_extensions.dart';
import '../../main/network/RestApis.dart';
import '../../main/services/VersionServices.dart';
import '../../main/utils/Common.dart';
import '../../main/utils/Widgets.dart';
import '../../extensions/LiveStream.dart';
import '../../extensions/colors.dart';
import '../../extensions/common.dart';
import '../../extensions/decorations.dart';
import '../../extensions/shared_pref.dart';
import '../../extensions/text_styles.dart';
import '../../main.dart';
import '../../main/components/CommonScaffoldComponent.dart';
import '../../main/models/CityListModel.dart';
import '../../main/screens/NotificationScreen.dart';
import '../../main/screens/UserCitySelectScreen.dart';
import '../../main/utils/Constants.dart';
import '../../main/utils/dynamic_theme.dart';
import '../../user/fragment/AccountFragment.dart';
import '../../user/fragment/HistoryFragment.dart';
import '../../user/fragment/OrderFragment.dart';

class DashboardScreen extends StatefulWidget {
  static String tag = '/DashboardScreen';

  @override
  DashboardScreenState createState() => DashboardScreenState();
}

class DashboardScreenState extends State<DashboardScreen>
    with WidgetsBindingObserver {
  int currentIndex = 0;
  List widgetList = [OrderFragment(), HistoryFragment(), AccountFragment()];
  late CrispConfig configData;
  String? crispChatIcon;
  bool isEnable = false;
  bool get _canOpenCrispChat =>
      isEnable && appStore.crispChatWebsiteId.trim().isNotEmpty;

  void _buildCrispConfig(String websiteId) {
    User user = User(
      email: appStore.userEmail,
      nickName: " ${getStringAsync(USER_NAME)}",
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

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    appStore.setLoading(true);
    loadData();
  }

  initCrispChat() async {
    await configCrispChatData();
  }

  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        print("📢 line 67 ${appStore.isCrispChatEnabled}");
        onResumed();
        break;
      default:
    }
  }

  void onResumed() async {
    //  getDashboardDetails();
  }

  Future<void> loadData() async {
    await Future.wait<void>([getDashboardDetails(), init(), initCrispChat()]);
    setState(() {
      appStore.setLoading(false);
    });
  }

  Future<void> checkAndShowFirebasePopup() async {
    try {
      final docRef = firestore.FirebaseFirestore.instance
          .collection('show_popup')
          .doc('config'); // single config document
      final doc = await docRef.get();
      if (!doc.exists) {
        // Create default document
        await docRef.set({"show_popup": false, "message": "", "title": ""});
        return;
      }
      bool showPopup = doc.data()?['show_popup'] ?? false;
      String message = doc.data()?['message'] ?? "";
      String title = doc.data()?['title'] ?? "";

      if (showPopup) {
        Future.delayed(Duration(milliseconds: 500), () {
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (context) {
              return popupDialog(title, message);
            },
          );
        });
      }
    } catch (e) {
      print("Popup Error: $e");
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
        isEnable = isChatEnabled && websiteId.isNotEmpty;
        appStore.setIsCrispChatEnabled(isEnable);
        appStore.setCrispChatWebsiteId(websiteId);
        if (isEnable) {
          _buildCrispConfig(websiteId);
        }
        setState(() {});
      }
      if (value.appSetting != null) {
        appStore.setIsSmsOrder(value.appSetting!.isSmsOrder ?? 0);
      }
    });
  }

  Future<void> init() async {
    LiveStream().on('UpdateLanguage', (p0) {
      setState(() {});
    });
    LiveStream().on('UpdateTheme', (p0) {
      setState(() {});
    });
    checkAndShowFirebasePopup();
  }

  @override
  void setState(fn) {
    if (mounted) super.setState(fn);
  }

  String getTitle() {
    String title = language.myOrders;
    if (currentIndex == 0) {
      title = '${language.hey} ${getStringAsync(NAME)} 👋';
    } else if (currentIndex == 1) {
      title = 'History';
    } else if (currentIndex == 2) {
      title = language.account;
    }
    return title;
  }

  Future<void> configCrispChatData() async {
    if (_canOpenCrispChat) {
      _buildCrispConfig(appStore.crispChatWebsiteId.trim());
    }
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

  @override
  Widget build(BuildContext context) {
    return CommonScaffoldComponent(
      extendedBody: false,
      appBar: PreferredSize(
        preferredSize: Size(context.width(), 60),
        child: commonAppBarWidget(
          getTitle(),
          actions: [
            Container(
              margin: .symmetric(vertical: 12, horizontal: 12),
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
                        size: 18,
                      ),
                      8.width,
                      Text(
                        CityModel.fromJson(
                          getJSONAsync(CITY_DATA),
                        ).name.validate(),
                        style: primaryTextStyle(color: white),
                      ),
                    ],
                  ).onTap(
                    () {
                      UserCitySelectScreen(
                        isBack: true,
                        onUpdate: () {
                          setState(() {});
                        },
                      ).launch(context);
                    },
                    highlightColor: Colors.transparent,
                    hoverColor: Colors.transparent,
                    splashColor: Colors.transparent,
                  ),
            ).visible(currentIndex == 0),
            4.width,
            4.width,
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
                    if (appStore.allUnreadCount != 0)
                      Observer(
                        builder: (context) {
                          return Positioned(
                            right: -5,
                            top: 8,
                            child: Container(
                              height: 20,
                              width: 20,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: Colors.orange,
                                shape: BoxShape.circle,
                              ),
                              child: Text(
                                appStore.allUnreadCount.toString(),
                                style: boldTextStyle(
                                  size: appStore.allUnreadCount > 99 ? 10 : 10,
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                  ],
                )
                .onTap(
                  () {
                    NotificationScreen().launch(context);
                  },
                  highlightColor: Colors.transparent,
                  hoverColor: Colors.transparent,
                  splashColor: Colors.transparent,
                )
                .visible(currentIndex != 2),
            8.width,
          ],
          showBack: false,
        ),
      ),
      body: Stack(
        children: [
          Column(
            children: [
              Expanded(
                child:
                    widgetList[currentIndex], // Ensures it takes available space
              ),
            ],
          ),
          (_canOpenCrispChat)
              ? Positioned(
                  bottom: context.height() * 0.08,
                  right: 16,
                  child: FloatingActionButton(
                    onPressed: () async {
                      await openCrispSupportChat();
                    },
                    backgroundColor: ColorUtils.colorPrimary,
                    child: CachedNetworkImage(
                      imageUrl: crispChatIcon ?? "",
                      errorWidget: (context, url, error) =>
                          Icon(Icons.chat_bubble_outline),
                    ),
                  ),
                )
              : SizedBox(),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: currentIndex,
        selectedItemColor: ColorUtils.colorPrimary,
        unselectedItemColor: Colors.grey,
        onTap: (index) => setState(() => currentIndex = index),
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home_outlined),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.history_outlined),
            label: 'History',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outline),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}
