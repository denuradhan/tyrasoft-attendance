import 'dart:async';
import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:trust_location/trust_location.dart';
import 'package:url_launcher/url_launcher.dart';

class WebViewPage extends StatefulWidget {
  final String url;
  const WebViewPage({Key? key, required this.url}) : super(key: key);

  @override
  State<WebViewPage> createState() => _WebViewState();
}

class _WebViewState extends State<WebViewPage> with WidgetsBindingObserver {
  bool _isMockLocation = false;
  Timer? timer;

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    stopCheckLocation();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      log("page resumed");
      startCheckMockLocation();
    }
    else if(state == AppLifecycleState.paused) {
      log("page paused");
      stopCheckLocation();
    }
  }

  void stopCheckLocation() {
    timer?.cancel();
    TrustLocation.stop();
  }
  
  void startCheckMockLocation() {
    TrustLocation.start(2);
    timer = Timer(const Duration(seconds: 10), () {
      TrustLocation.stop();
    });
  }

  InAppWebViewController? webViewController;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    log("page initState");

    try {
      TrustLocation.onChange.listen((values) async {
        log(DateTime.now().toString() +
            "-Mock location checked: " +
            values.isMockLocation.toString());
        setState(() {
          _isMockLocation = values.isMockLocation ?? false;
        });
      });
    } on PlatformException catch (e) {
      log('PlatformException $e');
    }

    requestLocationPermission();
    startCheckMockLocation();
  }

  /// request location permission at runtime.
  void requestLocationPermission() async {
    var status = await Permission.location.status;
    var cameraStatus = await Permission.camera.status;

    if (status.isDenied || cameraStatus.isDenied) {
      Map<Permission, PermissionStatus> result =
          await [Permission.location, Permission.camera].request();
      if (result.values.any((element) => element.isDenied)) {
        return;
      }
    }

    if (await Permission.location.isPermanentlyDenied) {
      openAppSettings();
      return;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: getView(),
      ),
    );
  }

  Widget getView() {
    if (!_isMockLocation) {
      return InAppWebView(
        initialUrlRequest: URLRequest(url: Uri.parse(widget.url)),
        onWebViewCreated: (controller) {
          webViewController = controller;
        },
        androidOnPermissionRequest: (controller, origin, resources) async {
          return PermissionRequestResponse(
              resources: resources,
              action: PermissionRequestResponseAction.GRANT);
        },
        shouldOverrideUrlLoading: (controller, navigationAction) async {
          var uri = navigationAction.request.url!;

          if (![
            "http",
            "https",
            "file",
            "chrome",
            "data",
            "javascript",
            "about"
          ].contains(uri.scheme)) {
            if (await canLaunchUrl(Uri.parse(widget.url))) {
              // Launch the App
              await launchUrl(Uri.parse(widget.url));
              // and cancel the request
              return NavigationActionPolicy.CANCEL;
            }
          }

          return NavigationActionPolicy.ALLOW;
        },
      );
    } else {
      return const Center(
        child: Text("Please turn on location or turn off mock location"),
      );
    }
  }
}
