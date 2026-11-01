import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../../core/audio/game_audio.dart';
import '../shell/game_pause.dart';

class NitroBoot {
  final String mode;
  final int seat, seats;
  final List<String> names;
  const NitroBoot({
    required this.mode,
    this.seat = 0,
    this.seats = 8,
    this.names = const [],
  });

  String asJson() => jsonEncode({
    'mode': mode, 'seat': seat, 'seats': seats, 'names': names,
    // Online clients must not use different locally saved arenas.
    if (mode != 'offline') 'arena': 'foundry',
  });
}

class NitroViewController {
  _NitroGameViewState? _state;
  bool get ready => _state?._booted ?? false;

  Future<bool> run(String js) async {
    final s = _state;
    if (s == null || !s.mounted || !s._booted || s._error != null) return false;
    try {
      final result = await s._controller!.runJavaScriptReturningResult(js);
      return result == true || '$result' == 'true' || '$result' == '1';
    } catch (_) {
      return false;
    }
  }

  Future<bool> sendHostInput(int seat, List<Object?> args) => run(
    '(function(){if(!window.__nitroNet)return false;return window.__nitroNet.input($seat,${jsonEncode(args)})===true})()',
  );
  Future<bool> sendSnapshot(String snapshotJson) => run(
    '(function(){if(!window.__nitroNet)return false;window.__nitroNet.snapshot(${jsonEncode(snapshotJson)});return true})()',
  );
}

/// Android only: other platforms show a deliberate fallback without constructing
/// a platform WebView (including ordinary Flutter widget tests).
class NitroGameView extends StatefulWidget {
  final NitroBoot boot;
  final NitroViewController controller;
  final ValueChanged<Map<String, dynamic>> onMessage;
  final VoidCallback? onReady;
  final ValueChanged<String>? onError;
  const NitroGameView({
    super.key,
    required this.boot,
    required this.controller,
    required this.onMessage,
    this.onReady,
    this.onError,
  });

  @override
  State<NitroGameView> createState() => _NitroGameViewState();
}

class _NitroGameViewState extends State<NitroGameView>
    with WidgetsBindingObserver {
  WebViewController? _controller;
  bool _booted = false, _polling = false, _hidden = false;
  bool _pausedByApp = false;
  String? _error;
  Timer? _retry, _timeout;
  ValueNotifier<bool>? _pause;

  bool get _supported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  @override
  void initState() {
    super.initState();
    widget.controller._state = this;
    if (!_supported) return;
    WidgetsBinding.instance.addObserver(this);
    GameAudio.settings.addListener(_syncAudio);
    _timeout = Timer(
      const Duration(seconds: 25),
      () => _fail(
        'Nitro could not start. This Android device needs WebGL 2 and WebAssembly. Leave and try again.',
      ),
    );
    unawaited(_load());
  }

  Future<void> _load() async {
    try {
      final c = WebViewController();
      _controller = c;
      await c.setJavaScriptMode(JavaScriptMode.unrestricted);
      await c.setBackgroundColor(const Color(0xFF05080C));
      await c.addJavaScriptChannel(
        'NitroBridge',
        onMessageReceived: (m) {
          if (!mounted || _error != null) return;
          try {
            final value = jsonDecode(m.message);
            if (value is Map<String, dynamic>) {
              if (value['kind'] == 'engine_error') {
                _fail('Nitro engine stopped: ${value['message']}');
              } else {
                widget.onMessage(value);
              }
            }
          } on FormatException catch (_) {
            /* Ignore malformed bridge messages. */
          }
        },
      );
      await c.setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (_) => _startPolling(),
          onNavigationRequest: (request) =>
              request.url.startsWith(
                'file:///android_asset/flutter_assets/assets/nitro/',
              )
              ? NavigationDecision.navigate
              : NavigationDecision.prevent,
          onWebResourceError: (error) {
            if (error.isForMainFrame != false)
              _fail('Nitro could not load: ${error.description}');
          },
        ),
      );
      // The self-contained bundle has no imports and embeds WASM bytes. Its
      // deferred classic script avoids file-origin ES-module CORS restrictions.
      if (!mounted || _error != null) return;
      await c.loadFlutterAsset('assets/nitro/index.html');
      if (mounted) setState(() {});
    } catch (e) {
      _fail('Nitro could not load: $e');
    }
  }

  void _startPolling() {
    if (_booted || _error != null || _retry != null) return;
    _retry = Timer.periodic(const Duration(milliseconds: 120), (_) => _poll());
    unawaited(_poll());
  }

  Future<void> _poll() async {
    if (!mounted || _polling || _booted || _error != null) return;
    _polling = true;
    try {
      final r = await _controller!.runJavaScriptReturningResult(
        '(function(){if(window.__nitroBoot&&!window.__nitroBooted){'
        'window.__nitroBooted=true;window.__nitroBoot(${jsonEncode(widget.boot.asJson())});}'
        'return !!window.__nitroDebug&&!!window.__nitroNet})()',
      );
      if (mounted &&
          _error == null &&
          (r == true || '$r' == 'true' || '$r' == '1')) {
        _retry?.cancel();
        _timeout?.cancel();
        setState(() => _booted = true);
        _syncAudio();
        _syncPause();
        widget.onReady?.call();
      }
    } catch (e) {
      _fail('Nitro engine could not initialize: $e');
    } finally {
      _polling = false;
    }
  }

  void _fail(String text) {
    if (!mounted || _error != null) return;
    _retry?.cancel();
    _timeout?.cancel();
    setState(() => _error = text);
    _controller?.runJavaScript('window.__nitroDebug?.dispose()').ignore();
    widget.onError?.call(text);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final pause = GamePause.maybeOf(context);
    if (_pause != pause) {
      _pause?.removeListener(_syncPause);
      _pause = pause;
      _pause?.addListener(_syncPause);
    }
    _syncPause();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _hidden = state != AppLifecycleState.resumed;
    _syncPause();
  }

  void _syncPause() {
    // Online simulation must not pause for one client's menu or app visibility.
    if (!_booted || widget.boot.mode != 'offline') return;
    final paused = _hidden || (_pause?.value ?? false);
    if (paused == _pausedByApp) return;
    _pausedByApp = paused;
    unawaited(
      widget.controller.run(
        'window.__nitroDebug.${paused ? 'pause' : 'resume'}();true',
      ),
    );
  }

  void _syncAudio() {
    final s = GameAudio.settings.value;
    unawaited(
      widget.controller.run(
        'window.__nitroDebug.audioSettings(${jsonEncode({'music': s.music, 'sfx': s.sfx, 'volume': s.volume})});true',
      ),
    );
  }

  @override
  void dispose() {
    _retry?.cancel();
    _timeout?.cancel();
    _pause?.removeListener(_syncPause);
    GameAudio.settings.removeListener(_syncAudio);
    WidgetsBinding.instance.removeObserver(this);
    // Stop the JS loop and WebAudio while the native platform view is released.
    _controller?.runJavaScript('window.__nitroDebug?.dispose()').ignore();
    if (widget.controller._state == this) widget.controller._state = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_supported)
      return const ColoredBox(
        color: Color(0xFF05080C),
        child: Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'Nitro Knockout requires Android with WebGL 2 and WebAssembly.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white),
            ),
          ),
        ),
      );
    if (_error != null)
      return ColoredBox(
        color: const Color(0xFF05080C),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              _error!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white),
            ),
          ),
        ),
      );
    return Stack(
      fit: StackFit.expand,
      children: [
        if (_controller != null) WebViewWidget(controller: _controller!),
        IgnorePointer(
          key: const ValueKey('nitro-loading-cover'),
          ignoring: _booted,
          child: AnimatedOpacity(
            opacity: _booted ? 0 : 1,
            duration: const Duration(milliseconds: 240),
            child: const ColoredBox(
              color: Color(0xFF05080C),
              child: Center(
                child: CircularProgressIndicator(color: Color(0xFF38E8FF)),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
