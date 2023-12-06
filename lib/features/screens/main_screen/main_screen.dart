// ignore_for_file: avoid_print, prefer_collection_literals, deprecated_member_use
import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_webview_pro/webview_flutter.dart';
import 'package:raon/features/widgets/app_cookie_handler.dart';
import 'package:raon/features/widgets/app_version_check_handler.dart';
import 'package:raon/features/widgets/back_handler_button.dart';
import 'package:raon/features/widgets/permission_handler.dart';
import 'package:tosspayments_widget_sdk_flutter/model/tosspayments_url.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  static String routeName = "/main";

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> with WidgetsBindingObserver {
  /// Initialize WebView Controller
  final Completer<WebViewController> _controller =
      Completer<WebViewController>();

  WebViewController? viewController;

  /// Initialize Main Page URL
  final String url = "http://raon.sogeum.kr/";

  /// Import BackHandlerButton
  BackHandlerButton? backHandlerButton;

  /// Import App Cookie Handler
  AppCookieHandler? appCookieHandler;

  /// Page Loading Indicator
  bool isLoading = false;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addObserver(this);

    /// Improve Android Performance
    if (Platform.isAndroid) WebView.platform = SurfaceAndroidWebView();

    /// Exit Application with double touch
    _controller.future.then(
      (WebViewController webViewController) {
        viewController = webViewController;
        backHandlerButton = BackHandlerButton(
          context: context,
          controller: webViewController,
          mainUrl: url,
        );
      },
    );

    /// Request user permission to access external storage
    StoragePermissionHandler permissionHandler =
        StoragePermissionHandler(context);

    permissionHandler.requestStoragePermission();

    /// Initialize Cookie Settings
    appCookieHandler = AppCookieHandler(url, url);

    /// App Version Check Manually
    AppVersionChecker appVersionChecker = AppVersionChecker(context);

    appVersionChecker.getAppVersion();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    if (state == AppLifecycleState.resumed) {
      backHandlerButton?.isAppForeground = true;

      print("앱이 포그라운드 상태입니다.");
    } else {
      backHandlerButton?.isAppForeground = false;

      print("앱이 백그라운드 상태입니다.");
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: false,
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          LayoutBuilder(
            builder: (BuildContext context, BoxConstraints constraints) {
              return WillPopScope(
                onWillPop: () async {
                  if (backHandlerButton != null) {
                    return backHandlerButton!.onWillPop();
                  }
                  return false;
                },
                child: SizedBox(
                  height: constraints.maxHeight,
                  child: SafeArea(
                    child: WebView(
                      initialUrl: url,
                      javascriptMode: JavascriptMode.unrestricted,
                      onPageStarted: (String url) async {
                        setState(() {
                          isLoading = true;
                        });

                        print("Current Url: $url");
                      },
                      onPageFinished: (String url) async {
                        setState(() {
                          isLoading = false;
                        });

                        /// Soft Keyboard hide input field on Android issue
                        if (Platform.isAndroid) {
                          if (url.contains(url) && viewController != null) {
                            await viewController!.runJavascript("""
                              (function() {
                                function scrollToFocusedInput(event) {
                                  const focusedElement = document.activeElement;
                                  if (focusedElement.tagName.toLowerCase() === 'input' || focusedElement.tagName.toLowerCase() === 'textarea') {
                                    setTimeout(() => {
                                      focusedElement.scrollIntoView({ behavior: 'smooth', block: 'center' });
                                    }, 500);
                                  }
                                }
                                document.addEventListener('focus', scrollToFocusedInput, true);
                              })();
                            """);
                          }
                        }
                      },
                      onWebViewCreated:
                          (WebViewController webViewController) async {
                        _controller.complete(webViewController);
                        viewController = webViewController;

                        /// Get Cookie Statement
                        await appCookieHandler?.setCookies(
                          appCookieHandler!.cookieValue,
                          appCookieHandler!.domain,
                          appCookieHandler!.cookieName,
                          appCookieHandler!.url,
                        );
                      },
                      navigationDelegate: (request) async {
                        /// Toss Payments
                        final appScheme = ConvertUrl(request.url);

                        if (appScheme.isAppLink()) {
                          try {
                            await appScheme.launchApp();
                          } on Error catch (e) {
                            print("Request to Toss Payments is invalid: $e");
                          }

                          return NavigationDecision.prevent;
                        }

                        return NavigationDecision.navigate;
                      },
                      onWebResourceError: (error) {
                        print("Error Code: ${error.errorCode}");
                        print("Error Description: ${error.description}");
                      },
                      zoomEnabled: false,
                      gestureRecognizers: Set()
                        ..add(
                          Factory<EagerGestureRecognizer>(
                            () => EagerGestureRecognizer(),
                          ),
                        ),
                      gestureNavigationEnabled: true,
                    ),
                  ),
                ),
              );
            },
          ),
          isLoading
              ? const Center(
                  child: CircularProgressIndicator.adaptive(),
                )
              : Container(),
        ],
      ),
    );
  }
}
