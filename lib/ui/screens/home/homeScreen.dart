import 'dart:io';
import 'package:flutter/gestures.dart';
import 'package:flutterquiz/features/ads/interstitialAdCubit.dart';
import 'package:flutterquiz/features/badges/cubits/badgesCubit.dart';
import 'package:flutterquiz/features/battleRoom/cubits/battleRoomCubit.dart';
import 'package:flutterquiz/features/battleRoom/cubits/multiUserBattleRoomCubit.dart';
import 'package:flutterquiz/features/profileManagement/cubits/updateScoreAndCoinsCubit.dart';
import 'package:flutterquiz/features/profileManagement/profileManagementRepository.dart';
import 'package:flutterquiz/features/quiz/cubits/quizCategoryCubit.dart';
import 'package:flutterquiz/features/quiz/quizRepository.dart';
import 'package:flutterquiz/ui/screens/battle/widgets/randomOrPlayFrdDialog.dart';
import 'package:flutterquiz/ui/screens/battle/widgets/roomDialog.dart';
import 'package:flutterquiz/ui/screens/home/widgets/menuBottomSheetContainer.dart';

import 'package:http/http.dart' as http;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutterquiz/app/appLocalization.dart';
import 'package:flutterquiz/app/routes.dart';
import 'package:flutterquiz/features/auth/authRepository.dart';
import 'package:flutterquiz/features/auth/cubits/authCubit.dart';
import 'package:flutterquiz/features/auth/cubits/referAndEarnCubit.dart';
import 'package:flutterquiz/features/profileManagement/cubits/userDetailsCubit.dart';
import 'package:flutterquiz/features/profileManagement/models/userProfile.dart';
import 'package:flutterquiz/features/quiz/models/quizType.dart';
import 'package:flutterquiz/features/systemConfig/cubits/systemConfigCubit.dart';
import 'package:flutterquiz/ui/screens/home/widgets/quizTypeContainer.dart';
import 'package:flutterquiz/ui/screens/home/widgets/updateAppContainer.dart';
import 'package:flutterquiz/ui/widgets/circularProgressContainner.dart';
import 'package:flutterquiz/ui/widgets/errorContainer.dart';
import 'package:flutterquiz/ui/widgets/pageBackgroundGradientContainer.dart';
import 'package:flutterquiz/ui/widgets/userAchievementScreen.dart';
import 'package:flutterquiz/utils/errorMessageKeys.dart';
import 'package:flutterquiz/utils/quizTypes.dart';
import 'package:flutterquiz/utils/stringLabels.dart';
import 'package:flutterquiz/utils/uiUtils.dart';
import 'package:path_provider/path_provider.dart';

class HomeScreen extends StatefulWidget {
  HomeScreen({
    Key? key,
  }) : super(key: key);

  @override
  _HomeScreenState createState() => _HomeScreenState();
  static Route<dynamic> route(RouteSettings routeSettings) {
    return CupertinoPageRoute(
        builder: (context) => BlocProvider<ReferAndEarnCubit>(
              create: (_) => ReferAndEarnCubit(AuthRepository()),
              child: HomeScreen(),
            ));
  }
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  final double quizTypeWidthPercentage = 0.4;
  final double quizTypeTopMargin = 0.425;
  final double quizTypeHorizontalMarginPercentage = 0.08;
  final List<int> maxHeightQuizTypeIndexes = [0, 3, 4, 7, 8];

  final double quizTypeBetweenVerticalSpacing = 0.02;

  late List<QuizType> _quizTypes = quizTypes;

  late AnimationController profileAnimationController = AnimationController(vsync: this, duration: Duration(milliseconds: 85));
  late AnimationController selfChallengeAnimationController = AnimationController(vsync: this, duration: Duration(milliseconds: 85));

  late Animation<Offset> profileSlideAnimation = Tween<Offset>(begin: Offset.zero, end: Offset(0.0, -0.0415)).animate(CurvedAnimation(parent: profileAnimationController, curve: Curves.easeIn));

  late Animation<Offset> selfChallengeSlideAnimation = Tween<Offset>(begin: Offset.zero, end: Offset(0.0, -0.0415)).animate(CurvedAnimation(parent: selfChallengeAnimationController, curve: Curves.easeIn));

  late AnimationController firstAnimationController = AnimationController(vsync: this, duration: Duration(milliseconds: 400));
  late Animation<double> firstAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(CurvedAnimation(parent: firstAnimationController, curve: Curves.easeInOut));
  late AnimationController secondAnimationController = AnimationController(vsync: this, duration: Duration(milliseconds: 400));
  late Animation<double> secondAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(CurvedAnimation(parent: secondAnimationController, curve: Curves.easeInOut));

  bool? dragUP;
  int currentMenu = 1;

  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

  @override
  void initState() {
    _initLocalNotification();
    checkForUpdates();
    setupInteractedMessage();
    setQuizMenu();
    createAds();
    super.initState();
  }

  void createAds() {
    Future.delayed(Duration.zero, () {
      context.read<InterstitialAdCubit>().createInterstitialAd(context);

      //context.read<RewardedAdCubit>().createRewardedAd(context);
    });
  }

  void _initLocalNotification() async {
    const AndroidInitializationSettings initializationSettingsAndroid = AndroidInitializationSettings('app_icon');
    final IOSInitializationSettings initializationSettingsIOS = IOSInitializationSettings(onDidReceiveLocalNotification: (int id, String? title, String? body, String? payLoad) {
      print("For ios version <= 9 notification will be shown here");
      return Future.value();
    });

    final InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsIOS,
    );
    await flutterLocalNotificationsPlugin.initialize(initializationSettings, onSelectNotification: _onTapLocalNotification);
    _requestPermissionsForIos();
  }

  Future<void> _requestPermissionsForIos() async {
    if (Platform.isIOS) {
      flutterLocalNotificationsPlugin.resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>()?.requestPermissions();
    }
  }

  void setQuizMenu() {
    Future.delayed(Duration.zero, () {
      final systemCubit = context.read<SystemConfigCubit>();
      if (systemCubit.getIsContestAvailable() == "0") {
        _quizTypes.removeWhere((element) => element.quizTypeEnum == QuizTypes.contest);
      }
      if (systemCubit.getIsDailyQuizAvailable() == "0") {
        _quizTypes.removeWhere((element) => element.quizTypeEnum == QuizTypes.dailyQuiz);
      }
      if (systemCubit.getIsAudioQuestionAvailable() == "0") {
        _quizTypes.removeWhere((element) => element.quizTypeEnum == QuizTypes.audioQuestions);
      }
      if (systemCubit.getIsFunNLearnAvailable() == "0") {
        _quizTypes.removeWhere((element) => element.quizTypeEnum == QuizTypes.funAndLearn);
      }
      if (systemCubit.getIsGuessTheWordAvailable() == "0") {
        _quizTypes.removeWhere((element) => element.quizTypeEnum == QuizTypes.guessTheWord);
      }
      setState(() {});
    });
  }

  late bool showUpdateContainer = false;

  void checkForUpdates() async {
    await Future.delayed(Duration.zero);
    if (context.read<SystemConfigCubit>().isForceUpdateEnable()) {
      try {
        bool forceUpdate = await UiUtils.forceUpdate(context.read<SystemConfigCubit>().getAppVersion());
        print(forceUpdate);
        if (forceUpdate) {
          setState(() {
            showUpdateContainer = true;
          });
        }
      } catch (e) {
        print(e.toString());
      }
    }
  }

  Future<void> setupInteractedMessage() async {
    RemoteMessage? initialMessage = await FirebaseMessaging.instance.getInitialMessage();
    if (initialMessage != null) {
      _handleMessage(initialMessage);
    }
    // handle background notification
    FirebaseMessaging.onMessageOpenedApp.listen(_handleMessage);
    FirebaseMessaging.onBackgroundMessage(UiUtils.onBackgroundMessage);
    //handle foreground notification
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      print("Notification arrvied");
      var data = message.data;

      var title = data['title'].toString();
      var body = data['body'].toString();
      var type = data['type'].toString();

      var image = data['image'];

      //if notification type is badges then update badges in cubit list
      if (type == "badges") {
        print("Notificaiton for unlocking new badge");
        String badgeType = data['badge_type'];
        Future.delayed(Duration.zero, () {
          context.read<BadgesCubit>().unlockBadge(badgeType);
        });
      }
      //payload is some data you want to pass in local notification
      image != null ? generateImageNotification(title, body, image, type, type) : generateSimpleNotification(title, body, type);
    });
  }

  // notification type is category then move to category screen
  Future<void> _handleMessage(RemoteMessage message) async {
    print("User has opened the app by tapping on notification");
    try {
      if (message.data['type'] == 'category') {
        Navigator.of(context).pushNamed(Routes.category, arguments: {"quizType": QuizTypes.quizZone});
      } else if (message.data['type'] == 'badges') {
        //if user open app by tapping
        UiUtils.updateBadgesLocally(context);
        Navigator.of(context).pushNamed(Routes.badges);
      }
    } catch (e) {
      print(e);
    }
  }

  Future<void> _onTapLocalNotification(String? payload) async {
    //
    String type = payload ?? "";
    if (type == "badges") {
      Navigator.of(context).pushNamed(Routes.badges);
    } else if (type == "category") {
      Navigator.of(context).pushNamed(
        Routes.category,
      );
    }
  }

  Future<void> generateImageNotification(String title, String msg, String image, String payloads, String type) async {
    var largeIconPath = await _downloadAndSaveFile(image, 'largeIcon');
    var bigPicturePath = await _downloadAndSaveFile(image, 'bigPicture');
    var bigPictureStyleInformation = BigPictureStyleInformation(FilePathAndroidBitmap(bigPicturePath), hideExpandedLargeIcon: true, contentTitle: title, htmlFormatContentTitle: true, summaryText: msg, htmlFormatSummaryText: true);
    var androidPlatformChannelSpecifics = AndroidNotificationDetails(
        'com.bookaz.quizland', //channel id
        'flutterquiz', //channel name
        'flutterquiz', //channel description
        largeIcon: FilePathAndroidBitmap(largeIconPath),
        styleInformation: bigPictureStyleInformation,
        icon: "app_icon");
    var platformChannelSpecifics = NotificationDetails(android: androidPlatformChannelSpecifics);
    await flutterLocalNotificationsPlugin.show(0, title, msg, platformChannelSpecifics, payload: payloads);
  }

  Future<String> _downloadAndSaveFile(String url, String fileName) async {
    final Directory directory = await getApplicationDocumentsDirectory();
    final String filePath = '${directory.path}/$fileName';
    final http.Response response = await http.get(Uri.parse(url));
    final File file = File(filePath);
    await file.writeAsBytes(response.bodyBytes);
    return filePath;
  }

  // notification on foreground
  Future<void> generateSimpleNotification(String title, String body, String payloads) async {
    print("Trigger local notification");
    var androidPlatformChannelSpecifics = AndroidNotificationDetails(
        'com.bookaz.quizland', //channel id
        'flutterquiz', //channel name
        'flutterquiz', //channel description
        importance: Importance.max,
        priority: Priority.high,
        ticker: 'ticker',
        icon: "app_icon");
    const IOSNotificationDetails iosNotificationDetails = IOSNotificationDetails();

    var platformChannelSpecifics = NotificationDetails(android: androidPlatformChannelSpecifics, iOS: iosNotificationDetails);
    await flutterLocalNotificationsPlugin.show(0, title, body, platformChannelSpecifics, payload: payloads);
  }

  @override
  void dispose() {
    profileAnimationController.dispose();
    selfChallengeAnimationController.dispose();

    super.dispose();
  }

  double _getTopMarginForQuizTypeContainer(int quizTypeIndex) {
    double topMarginPercentage = quizTypeTopMargin;
    int baseCondition = quizTypeIndex % 2 == 0 ? 0 : 1;
    for (int i = quizTypeIndex; i > baseCondition; i = i - 2) {
      //
      double topQuizTypeHeight = maxHeightQuizTypeIndexes.contains(i - 2) ? UiUtils.quizTypeMaxHeightPercentage : UiUtils.quizTypeMinHeightPercentage;

      topMarginPercentage = topMarginPercentage + quizTypeBetweenVerticalSpacing + topQuizTypeHeight;
    }
    return topMarginPercentage;
  }

  void startAnimation() async {
    selfChallengeAnimationController.forward().then((value) async {
      await profileAnimationController.forward();
      await selfChallengeAnimationController.reverse();
      profileAnimationController.reverse();
    });
  }

  void _navigateToQuizZone(int containerNumber) {
    //container number will be [1,2,3,4]
    if (currentMenu == 1) {
      if (containerNumber == 1) {
        _onQuizTypeContainerTap(0);
      } else if (containerNumber == 2) {
        _onQuizTypeContainerTap(1);
        print("Navigate to _quizTypes : ${_quizTypes[1].title}");
      } else if (containerNumber == 3) {
        _onQuizTypeContainerTap(2);
        print("Navigate to _quizTypes : ${_quizTypes[2].title}");
      } else {
        _onQuizTypeContainerTap(3);
        print("Navigate to _quizTypes : ${_quizTypes[3].title}");
      }
    } else if (currentMenu == 2) {
      //determine
      if (containerNumber == 1) {
        _onQuizTypeContainerTap(4);
      } else if (containerNumber == 2) {
        if (_quizTypes.length >= 6) {
          _onQuizTypeContainerTap(5);
          print("Navigate to _quizTypes : ${_quizTypes[5].title}");
        }
      } else if (containerNumber == 3) {
        if (_quizTypes.length >= 7) {
          _onQuizTypeContainerTap(6);
          print("Navigate to _quizTypes : ${_quizTypes[6].title}");
        }
      } else {
        if (_quizTypes.length >= 8) {
          _onQuizTypeContainerTap(7);
          print("Navigate to _quizTypes : ${_quizTypes[7].title}");
        }
      }
    } else {
      if (containerNumber == 1) {
        if (_quizTypes.length >= 9) {
          _onQuizTypeContainerTap(8);
          print("Navigate to _quizTypes : ${_quizTypes[8].title}");
        }
      } else if (containerNumber == 2) {
        if (_quizTypes.length >= 10) {
          _onQuizTypeContainerTap(9);
          print("Navigate to _quizTypes : ${_quizTypes[9].title}");
        }
      }
    }
  }

  void _onQuizTypeContainerTap(int quizTypeIndex) {
    if (_quizTypes[quizTypeIndex].quizTypeEnum == QuizTypes.dailyQuiz) {
      if (context.read<SystemConfigCubit>().getIsDailyQuizAvailable() == "1") {
        Navigator.of(context).pushNamed(Routes.quiz, arguments: {"quizType": QuizTypes.dailyQuiz, "numberOfPlayer": 1, "quizName": "Daily Quiz"});
      } else {
        UiUtils.setSnackbar(AppLocalization.of(context)!.getTranslatedValues(currentlyNotAvailableKey)!, context, false);
      }
    } else if (_quizTypes[quizTypeIndex].quizTypeEnum == QuizTypes.quizZone) {
      Navigator.of(context).pushNamed(Routes.category, arguments: {"quizType": QuizTypes.quizZone});
    } else if (_quizTypes[quizTypeIndex].quizTypeEnum == QuizTypes.selfChallenge) {
      Navigator.of(context).pushNamed(Routes.selfChallenge);
    } //
    else if (_quizTypes[quizTypeIndex].quizTypeEnum == QuizTypes.battle) {
      //
      context.read<BattleRoomCubit>().emit(BattleRoomInitial());

      showDialog(
        context: context,
        builder: (context) => MultiBlocProvider(providers: [
          BlocProvider<QuizCategoryCubit>(create: (_) => QuizCategoryCubit(QuizRepository())),
          BlocProvider<UpdateScoreAndCoinsCubit>(create: (_) => UpdateScoreAndCoinsCubit(ProfileManagementRepository())),
        ], child: RandomOrPlayFrdDialog()),
      );
    } else if (_quizTypes[quizTypeIndex].quizTypeEnum == QuizTypes.trueAndFalse) {
      Navigator.of(context).pushNamed(Routes.quiz, arguments: {"quizType": QuizTypes.trueAndFalse, "numberOfPlayer": 1, "quizName": "True & False"});
    } else if (_quizTypes[quizTypeIndex].quizTypeEnum == QuizTypes.funAndLearn) {
      Navigator.of(context).pushNamed(Routes.category, arguments: {"quizType": QuizTypes.funAndLearn});
    } else if (_quizTypes[quizTypeIndex].quizTypeEnum == QuizTypes.groupPlay) {
      context.read<MultiUserBattleRoomCubit>().emit(MultiUserBattleRoomInitial());
      //
      showDialog(
          context: context,
          builder: (context) => MultiBlocProvider(providers: [
                BlocProvider<QuizCategoryCubit>(create: (_) => QuizCategoryCubit(QuizRepository())),
                BlocProvider<UpdateScoreAndCoinsCubit>(create: (_) => UpdateScoreAndCoinsCubit(ProfileManagementRepository())),
              ], child: RoomDialog(quizType: QuizTypes.groupPlay)));
      //
    } else if (_quizTypes[quizTypeIndex].quizTypeEnum == QuizTypes.contest) {
      if (context.read<SystemConfigCubit>().getIsContestAvailable() == "1") {
        Navigator.of(context).pushNamed(Routes.contest);
      } else {
        UiUtils.setSnackbar(AppLocalization.of(context)!.getTranslatedValues(currentlyNotAvailableKey)!, context, false);
      }
    } else if (_quizTypes[quizTypeIndex].quizTypeEnum == QuizTypes.guessTheWord) {
      Navigator.of(context).pushNamed(Routes.category, arguments: {"quizType": QuizTypes.guessTheWord});
    } else if (_quizTypes[quizTypeIndex].quizTypeEnum == QuizTypes.audioQuestions) {
      Navigator.of(context).pushNamed(Routes.category, arguments: {"quizType": QuizTypes.audioQuestions});
    }
  }

  Widget _buildProfileContainer(double statusBarPadding) {
    return Align(
      alignment: Alignment.topCenter,
      child: GestureDetector(
        onTap: () {
          //
          Navigator.of(context).pushNamed(Routes.profile);
        },
        child: SlideTransition(
          position: profileSlideAnimation,
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 10.0),
            child: BlocBuilder<UserDetailsCubit, UserDetailsState>(
              bloc: context.read<UserDetailsCubit>(),
              builder: (context, state) {
                if (state is UserDetailsFetchSuccess) {
                  return Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: Theme.of(context).primaryColor,
                        radius: 37.5,
                        backgroundImage: CachedNetworkImageProvider(state.userProfile.profileUrl!),
                      ),
                      SizedBox(
                        width: MediaQuery.of(context).size.width * (0.0175),
                      ),
                      Flexible(
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  state.userProfile.name!,
                                  style: TextStyle(
                                    fontSize: 16.0,
                                    fontWeight: FontWeight.bold,
                                    color: Theme.of(context).primaryColor,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                Text(
                                  state.userProfile.email!.isEmpty ? state.userProfile.mobileNumber! : state.userProfile.email!,
                                  style: TextStyle(
                                    fontSize: 13.0,
                                    color: Theme.of(context).primaryColor.withOpacity(0.6),
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                SizedBox(
                                  height: constraints.maxHeight * (0.05),
                                ),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    UserAchievementContainer(title: AppLocalization.of(context)!.getTranslatedValues("rankLbl")!, value: state.userProfile.allTimeRank ?? "0"),
                                    UserAchievementContainer(title: AppLocalization.of(context)!.getTranslatedValues("coinsLbl")!, value: state.userProfile.coins ?? "0"),
                                    UserAchievementContainer(title: AppLocalization.of(context)!.getTranslatedValues("scoreLbl")!, value: UiUtils.formatNumber(int.parse(state.userProfile.allTimeScore ?? "0"))),
                                  ], //
                                ),
                              ],
                            );
                          },
                        ),
                      )
                    ],
                  );
                }
                return Container();
              },
            ),
            margin: EdgeInsets.only(top: MediaQuery.of(context).size.height * (0.085) + statusBarPadding),
            decoration: BoxDecoration(
              color: Theme.of(context).backgroundColor,
              //gradient: UiUtils.buildLinerGradient([Theme.of(context).primaryColor, Theme.of(context).colorScheme.secondary], Alignment.topCenter, Alignment.bottomCenter),
              boxShadow: [
                UiUtils.buildBoxShadow(offset: Offset(5, 5), blurRadius: 10.0),
              ],
              borderRadius: BorderRadius.circular(30.0),
            ),
            width: MediaQuery.of(context).size.width * (0.84),
            height: MediaQuery.of(context).size.height * (0.16),
          ),
        ),
      ),
    );
  }

  Widget _buildSelfChallenge(double statusBarPadding) {
    return GestureDetector(
      onTap: () {
        Navigator.of(context).pushNamed(Routes.selfChallenge);
      },
      child: Align(
        alignment: Alignment.topCenter,
        child: SlideTransition(
          position: selfChallengeSlideAnimation,
          child: Container(
            margin: EdgeInsets.only(top: MediaQuery.of(context).size.height * 0.28 + statusBarPadding),
            decoration: BoxDecoration(
              color: Theme.of(context).backgroundColor,

              //gradient: UiUtils.buildLinerGradient([Theme.of(context).colorScheme.secondary, Theme.of(context).primaryColor], Alignment.centerLeft, Alignment.centerRight),

              boxShadow: [UiUtils.buildBoxShadow(offset: Offset(5.0, 5.0), blurRadius: 10.0)],
              borderRadius: BorderRadius.circular(20.0),
            ),
            width: MediaQuery.of(context).size.width * (0.84),
            height: MediaQuery.of(context).size.height * (0.1),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20.0),
              child: Stack(
                clipBehavior: Clip.hardEdge,
                children: [
                  Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: Container(
                      margin: EdgeInsetsDirectional.only(start: 20.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            AppLocalization.of(context)!.getTranslatedValues(selfChallengeLbl)!,
                            style: TextStyle(
                              fontSize: 16.0,
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).primaryColor,
                            ),
                          ),
                          SizedBox(
                            height: 1.0,
                          ),
                          Text(
                            AppLocalization.of(context)!.getTranslatedValues(challengeYourselfLbl)!,
                            style: TextStyle(
                              fontSize: 14.0,
                              color: Theme.of(context).primaryColor.withOpacity(0.6),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Align(
                    alignment: AlignmentDirectional.centerEnd,
                    child: Transform.scale(scale: 0.55, child: SvgPicture.asset("assets/images/selfchallenge_icon.svg")),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildQuizType(int quizTypeIndex, double statusBarPadding) {
    double quizTypeHorizontalMargin = MediaQuery.of(context).size.width * quizTypeHorizontalMarginPercentage;
    double topMarginPercentage = quizTypeTopMargin;

    if (quizTypeIndex - 2 < 0) {
      topMarginPercentage = quizTypeTopMargin;
    } else {
      topMarginPercentage = _getTopMarginForQuizTypeContainer(quizTypeIndex);
    }

    bool isLeft = quizTypeIndex % 2 == 0;

    if (quizTypeIndex < 4) {
      return AnimatedBuilder(
        builder: (context, child) {
          return Positioned(
            top: (MediaQuery.of(context).size.height * topMarginPercentage) + statusBarPadding,
            left: isLeft ? quizTypeHorizontalMargin : null,
            right: isLeft ? null : quizTypeHorizontalMargin,
            child: SlideTransition(
              position: firstAnimation.drive<Offset>(Tween<Offset>(begin: Offset.zero, end: Offset(isLeft ? -1.0 : 1.0, 0))),
              child: FadeTransition(
                opacity: firstAnimation.drive<double>(Tween<double>(begin: 1.0, end: 0.0)),
                child: child!,
              ),
            ),
          );
        },
        animation: firstAnimationController,
        child: QuizTypeContainer(
          quizType: _quizTypes[quizTypeIndex],
          widthPercentage: quizTypeWidthPercentage,
          heightPercentage: maxHeightQuizTypeIndexes.contains(quizTypeIndex) ? UiUtils.quizTypeMaxHeightPercentage : UiUtils.quizTypeMinHeightPercentage,
        ),
      );
    } else if (quizTypeIndex < 8) {
      return AnimatedBuilder(
        builder: (context, child) {
          double endMarginPercentage = quizTypeTopMargin;
          //change static number to length of menu
          if (quizTypeIndex == 6 || quizTypeIndex == 7) {
            double previousTopQuizTypeHeight = maxHeightQuizTypeIndexes.contains(quizTypeIndex - 2) ? UiUtils.quizTypeMaxHeightPercentage : UiUtils.quizTypeMinHeightPercentage;
            endMarginPercentage = quizTypeTopMargin + quizTypeBetweenVerticalSpacing + previousTopQuizTypeHeight;
          }

          double topPositionPercentage = firstAnimation.drive<double>(Tween(begin: topMarginPercentage, end: endMarginPercentage)).value;

          return Positioned(
            top: (MediaQuery.of(context).size.height * topPositionPercentage) + statusBarPadding,
            left: isLeft ? quizTypeHorizontalMargin : null,
            right: isLeft ? null : quizTypeHorizontalMargin,
            child: SlideTransition(
              position: secondAnimation.drive<Offset>(Tween<Offset>(begin: Offset.zero, end: Offset(isLeft ? -1.0 : 1.0, 0))),
              child: FadeTransition(
                opacity: secondAnimation.drive<double>(Tween<double>(begin: 1.0, end: 0.0)),
                child: child!,
              ),
            ),
          );
        },
        animation: firstAnimationController,
        child: QuizTypeContainer(
          quizType: _quizTypes[quizTypeIndex],
          widthPercentage: quizTypeWidthPercentage,
          heightPercentage: maxHeightQuizTypeIndexes.contains(quizTypeIndex) ? UiUtils.quizTypeMaxHeightPercentage : UiUtils.quizTypeMinHeightPercentage,
        ),
      );
    } else {
      return AnimatedBuilder(
        animation: firstAnimationController,
        builder: (context, child) {
          return AnimatedBuilder(
            builder: (context, child) {
              double firstEndMarginPercentage = _getTopMarginForQuizTypeContainer(quizTypeIndex - 4);
              double topPositionPercentage = 0.0;

              topPositionPercentage = firstAnimation.drive<double>(Tween(begin: topMarginPercentage, end: firstEndMarginPercentage)).value;
              topPositionPercentage = topPositionPercentage - (firstEndMarginPercentage - quizTypeTopMargin) * (secondAnimation.drive<double>(Tween(begin: 0.0, end: 1.0)).value);

              return Positioned(
                top: (MediaQuery.of(context).size.height * topPositionPercentage) + statusBarPadding,
                left: isLeft ? quizTypeHorizontalMargin : null,
                right: isLeft ? null : quizTypeHorizontalMargin,
                child: child!,
              );
            },
            animation: secondAnimationController,
            child: QuizTypeContainer(
              quizType: _quizTypes[quizTypeIndex],
              widthPercentage: quizTypeWidthPercentage,
              heightPercentage: maxHeightQuizTypeIndexes.contains(quizTypeIndex) ? UiUtils.quizTypeMaxHeightPercentage : UiUtils.quizTypeMinHeightPercentage,
            ),
          );
        },
      );
    }
  }

  List<Widget> _buildQuizTypes(double statusBarPadding) {
    List<Widget> children = [];
    for (int i = 0; i < _quizTypes.length; i++) {
      children.add(_buildQuizType(i, statusBarPadding));
    }
    return children;
  }

  Widget _buildTopMenu(double statusBarPadding) {
    return Align(
      alignment: Alignment.topRight,
      child: Padding(
        padding: EdgeInsets.only(top: statusBarPadding + 5.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Container(
              width: 45,
              height: 40,
              decoration: BoxDecoration(
                color: Theme.of(context).backgroundColor,
                boxShadow: [
                  UiUtils.buildBoxShadow(offset: Offset(5, 5), blurRadius: 10.0),
                ],
                borderRadius: BorderRadius.circular(15.0),
              ),
              child: IconButton(
                  onPressed: () {
                    Navigator.of(context).pushNamed(Routes.leaderBoard);
                  },
                  icon: SvgPicture.asset(
                    UiUtils.getImagePath("leaderboard_dark.svg"),
                  )),
            ),
            SizedBox(
              width: 12.5,
            ),
            Container(
              width: 45,
              height: 40,
              decoration: BoxDecoration(
                color: Theme.of(context).backgroundColor,
                boxShadow: [
                  UiUtils.buildBoxShadow(offset: Offset(5, 5), blurRadius: 10.0),
                ],
                borderRadius: BorderRadius.circular(15.0),
              ),
              child: IconButton(
                onPressed: () {
                  showModalBottomSheet(
                      isScrollControlled: true,
                      elevation: 5.0,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(20.0),
                        topRight: Radius.circular(20.0),
                      )),
                      context: context,
                      builder: (context) {
                        return MenuBottomSheetContainer();
                      });
                },
                icon: Icon(
                  Icons.menu,
                  color: Theme.of(context).primaryColor,
                ),
              ),
            ),
            SizedBox(
              width: MediaQuery.of(context).size.width * (0.085),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopMenuContainer(double statusBarPadding) {
    return Positioned(
      top: MediaQuery.of(context).size.height * (quizTypeTopMargin) + statusBarPadding,
      child: GestureDetector(
        onTap: () {},
        onTapUp: (tapDownDetails) {
          double firstTapStartDx = quizTypeHorizontalMarginPercentage * MediaQuery.of(context).size.width;
          double topTapStartDy = quizTypeTopMargin * MediaQuery.of(context).size.height + statusBarPadding;

          double secondTapStartDx = MediaQuery.of(context).size.width - MediaQuery.of(context).size.width * (quizTypeWidthPercentage + quizTypeHorizontalMarginPercentage);

          double thirdTapStartDy = MediaQuery.of(context).size.height * (quizTypeBetweenVerticalSpacing + quizTypeTopMargin + UiUtils.quizTypeMaxHeightPercentage) + statusBarPadding;
          double fourthTapStartDy = MediaQuery.of(context).size.height * (quizTypeBetweenVerticalSpacing + quizTypeTopMargin + UiUtils.quizTypeMinHeightPercentage) + statusBarPadding;

          if (tapDownDetails.globalPosition.dx >= firstTapStartDx && tapDownDetails.globalPosition.dx <= (firstTapStartDx + MediaQuery.of(context).size.width * quizTypeWidthPercentage)) {
            //
            if (tapDownDetails.globalPosition.dy >= topTapStartDy && tapDownDetails.globalPosition.dy <= (topTapStartDy + (MediaQuery.of(context).size.height * UiUtils.quizTypeMaxHeightPercentage))) {
              _navigateToQuizZone(1);
            } else if (tapDownDetails.globalPosition.dy >= thirdTapStartDy && tapDownDetails.globalPosition.dy <= (thirdTapStartDy + (MediaQuery.of(context).size.height * UiUtils.quizTypeMinHeightPercentage))) {
              _navigateToQuizZone(3);
            }
          } else if (tapDownDetails.globalPosition.dx >= secondTapStartDx && tapDownDetails.globalPosition.dx <= (secondTapStartDx + MediaQuery.of(context).size.width * quizTypeWidthPercentage)) {
            if (tapDownDetails.globalPosition.dy >= topTapStartDy && tapDownDetails.globalPosition.dy <= (topTapStartDy + (MediaQuery.of(context).size.height * UiUtils.quizTypeMinHeightPercentage))) {
              _navigateToQuizZone(2);
            } else if (tapDownDetails.globalPosition.dy >= fourthTapStartDy && tapDownDetails.globalPosition.dy <= (fourthTapStartDy + (MediaQuery.of(context).size.height * UiUtils.quizTypeMaxHeightPercentage))) {
              _navigateToQuizZone(4);
            }
          }
        },
        dragStartBehavior: DragStartBehavior.start,
        onVerticalDragUpdate: (dragUpdateDetails) {
          if (currentMenu == 1) {
            //when firstMenu is selected
            double dragged = dragUpdateDetails.primaryDelta! / MediaQuery.of(context).size.height;
            firstAnimationController.value = firstAnimationController.value - 2.50 * dragged;
          } else if (currentMenu == 2) {
            //when second _quizTypes
            if (dragUP == null) {
              if (dragUpdateDetails.primaryDelta! < 0) {
                if (_quizTypes.length > 8) {
                  dragUP = true;
                }
              } else if (dragUpdateDetails.primaryDelta! > 0) {
                dragUP = false;
              } else {}
            }

            //
            if (dragUP != null) {
              if (dragUP!) {
                double dragged = dragUpdateDetails.primaryDelta! / MediaQuery.of(context).size.height;
                secondAnimationController.value = secondAnimationController.value - 2.50 * dragged;
              } else {
                double dragged = dragUpdateDetails.primaryDelta! / MediaQuery.of(context).size.height;
                firstAnimationController.value = firstAnimationController.value - 2.50 * dragged;
              }
            }
          } else {
            double dragged = dragUpdateDetails.primaryDelta! / MediaQuery.of(context).size.height;
            secondAnimationController.value = secondAnimationController.value - 2.50 * dragged;
          }
        },
        onVerticalDragEnd: (dragEndDetails) async {
          if (currentMenu == 1) {
            if (firstAnimationController.value > 0.3) {
              currentMenu = 2;
              await firstAnimationController.forward();
              startAnimation();
            } else {
              firstAnimationController.reverse();
              currentMenu = 1;
            }
          } else if (currentMenu == 2) {
            //when currentMenu is 2 then handle this condition
            if (dragUP != null) {
              if (dragUP!) {
                if (secondAnimationController.value > 0.3) {
                  currentMenu = 3;
                  await secondAnimationController.forward();
                  startAnimation();
                } else {
                  secondAnimationController.reverse();
                  currentMenu = 2;
                }
              } else {
                if (firstAnimationController.value > 0.7) {
                  firstAnimationController.forward();
                  currentMenu = 2;
                } else {
                  firstAnimationController.reverse();
                  currentMenu = 1;
                }
              }
            }

            dragUP = null;
          } else {
            //
            if (secondAnimationController.value > 0.7) {
              secondAnimationController.forward();
              currentMenu = 3;
            } else {
              secondAnimationController.reverse();
              currentMenu = 2;
            }
          }
        },
        child: Container(
          color: Colors.transparent,
          width: MediaQuery.of(context).size.width,
          height: MediaQuery.of(context).size.height * (1.0 - quizTypeTopMargin),
        ),
      ),
    );
  }

  Widget _buildHomeScreen(List<Widget> children) {
    return Stack(
      children: [
        PageBackgroundGradientContainer(),
        ...children,
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final statusBarPadding = MediaQuery.of(context).padding.top;
    return Scaffold(
      body: BlocConsumer<UserDetailsCubit, UserDetailsState>(
        listener: (context, state) {
          if (state is UserDetailsFetchSuccess) {
            UiUtils.fetchBookmarkAndBadges(context: context, userId: state.userProfile.userId!);
          }
        },
        bloc: context.read<UserDetailsCubit>(),
        builder: (context, state) {
          if (state is UserDetailsFetchInProgress || state is UserDetailsInitial) {
            return _buildHomeScreen([
              Center(
                child: CircularProgressContainer(
                  useWhiteLoader: false,
                ),
              )
            ]);
          }
          if (state is UserDetailsFetchFailure) {
            return _buildHomeScreen([
              ErrorContainer(
                showBackButton: true,
                errorMessage: AppLocalization.of(context)!.getTranslatedValues(convertErrorCodeToLanguageKey(state.errorMessage))!,
                onTapRetry: () {
                  context.read<UserDetailsCubit>().fetchUserDetails(context.read<AuthCubit>().getUserFirebaseId());
                },
                showErrorImage: true,
                errorMessageColor: Theme.of(context).primaryColor,
              )
            ]);
          }

          UserProfile userProfile = (state as UserDetailsFetchSuccess).userProfile;
          if (userProfile.status == "0") {
            return _buildHomeScreen([
              ErrorContainer(
                showBackButton: true,
                errorMessage: AppLocalization.of(context)!.getTranslatedValues(accountDeactivatedKey)!,
                onTapRetry: () {
                  context.read<UserDetailsCubit>().fetchUserDetails(context.read<AuthCubit>().getUserFirebaseId());
                },
                showErrorImage: true,
                errorMessageColor: Theme.of(context).primaryColor,
              )
            ]);
          }

          return _buildHomeScreen([
            _buildTopMenu(statusBarPadding),
            _buildProfileContainer(statusBarPadding),
            _buildSelfChallenge(statusBarPadding),
            ..._buildQuizTypes(statusBarPadding),
            _buildTopMenuContainer(statusBarPadding),
            showUpdateContainer ? UpdateAppContainer() : Container(),
          ]);
        },
      ),
    );
  }
}
