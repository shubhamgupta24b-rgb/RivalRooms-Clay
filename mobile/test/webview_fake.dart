import 'package:flutter/material.dart';
import 'package:webview_flutter_platform_interface/webview_flutter_platform_interface.dart';

/// A no-op WebView platform so widget tests can build screens that host the
/// Nitro Knockout WebView. The engine itself needs a real device: these tests
/// only cover the Flutter shell around it (intro, hand-over, pause chrome).
class FakeWebViewPlatform extends WebViewPlatform {
  static bool engineReady = false, failInjection = false;
  static final scripts = <String>[];
  static final controllers = <PlatformWebViewController>[];
  static PageEventCallback? pageFinished;
  static JavaScriptChannelParams? bridge;
  static void install() {
    engineReady = failInjection = false;
    scripts.clear();
    controllers.clear();
    pageFinished = null;
    bridge = null;
    WebViewPlatform.instance = FakeWebViewPlatform();
  }

  static void message(String json) =>
      bridge!.onMessageReceived(JavaScriptMessage(message: json));

  @override
  PlatformWebViewController createPlatformWebViewController(
    PlatformWebViewControllerCreationParams params,
  ) => _FakeWebViewController(params);

  @override
  PlatformWebViewWidget createPlatformWebViewWidget(
    PlatformWebViewWidgetCreationParams params,
  ) => _FakeWebViewWidget(params);

  @override
  PlatformNavigationDelegate createPlatformNavigationDelegate(
    PlatformNavigationDelegateCreationParams params,
  ) => _FakeNavigationDelegate(params);
}

class _FakeWebViewController extends PlatformWebViewController {
  _FakeWebViewController(super.params) : super.implementation() {
    FakeWebViewPlatform.controllers.add(this);
  }

  @override
  Future<void> loadFlutterAsset(String path) async {}

  @override
  Future<void> setJavaScriptMode(JavaScriptMode javaScriptMode) async {}

  @override
  Future<void> setBackgroundColor(Color color) async {}

  @override
  Future<void> addJavaScriptChannel(JavaScriptChannelParams params) async {
    FakeWebViewPlatform.bridge = params;
  }

  @override
  Future<void> setPlatformNavigationDelegate(
    PlatformNavigationDelegate navigationDelegate,
  ) async {}

  @override
  Future<void> runJavaScript(String javaScript) async {}

  @override
  Future<Object> runJavaScriptReturningResult(String javaScript) async {
    FakeWebViewPlatform.scripts.add(javaScript);
    if (FakeWebViewPlatform.failInjection &&
        javaScript.contains('__nitroNet.input')) {
      throw StateError('Engine unavailable');
    }
    return FakeWebViewPlatform.engineReady;
  }

  @override
  Future<void> reload() async {}
}

class _FakeWebViewWidget extends PlatformWebViewWidget {
  _FakeWebViewWidget(super.params) : super.implementation();

  @override
  Widget build(BuildContext context) => const SizedBox.expand();
}

class _FakeNavigationDelegate extends PlatformNavigationDelegate {
  _FakeNavigationDelegate(super.params) : super.implementation();

  @override
  Future<void> setOnNavigationRequest(
    NavigationRequestCallback onNavigationRequest,
  ) async {}

  @override
  Future<void> setOnPageStarted(
    PageEventCallback onPageStartedCallback,
  ) async {}

  @override
  Future<void> setOnPageFinished(
    PageEventCallback onPageFinishedCallback,
  ) async {
    FakeWebViewPlatform.pageFinished = onPageFinishedCallback;
  }

  @override
  Future<void> setOnProgress(ProgressCallback onProgressCallback) async {}

  @override
  Future<void> setOnWebResourceError(
    WebResourceErrorCallback onWebResourceErrorCallback,
  ) async {}

  @override
  Future<void> setOnUrlChange(UrlChangeCallback onUrlChangeCallback) async {}

  @override
  Future<void> setOnHttpAuthRequest(
    HttpAuthRequestCallback onHttpAuthRequestCallback,
  ) async {}

  @override
  Future<void> setOnHttpError(
    HttpResponseErrorCallback onHttpErrorCallback,
  ) async {}

  @override
  Future<void> setOnSSlAuthError(
    SslAuthErrorCallback onSslAuthErrorCallback,
  ) async {}
}
