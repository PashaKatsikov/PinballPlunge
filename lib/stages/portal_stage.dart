import 'dart:async';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';

import '../media_library.dart';
import '../spine/local_stash.dart';
import '../spine/masked_http.dart';
import '../spine/pulse_sensor.dart';
import '../spine/signal_dock.dart';
import 'no_link_stage.dart';

/// Immersive full-screen WebView (the gray portal).
///
/// Wires:
///   - Forged device UA (same as MaskedHttp) so partner backends see one
///     consistent client identity across HTTP + WebView.
///   - Immersive system UI (no status/nav bar over the content).
///   - Redirect-loop recovery for `too_many_redirects` errors.
///   - Immediate offline swap on `ConnectivityResult.none` (no DNS probe).
///   - Probe-then-swap on transient WebView load errors.
///   - Warm push link delivery via SignalDock.onIncomingLink.
///   - Native file chooser hooked through the "pinboard/upload" channel.
///   - Third-party cookies + inline media autoplay.
///   - Safe-area CSS neutralizer (viewport + custom vars only, never
///     `html/body/#app/#root` padding — see webview_safe_area_injection).
///   - Keyboard scroll fix (single delayed pass, behavior:'auto').
///   - Landscape safe-area for the camera cutout via `SafeArea(bottom:
///     false)` around the WebView, so the punch-hole never overdraws
///     content.
class PortalStage extends StatefulWidget {
  const PortalStage({
    super.key,
    required this.link,
    required this.stash,
    required this.dock,
    required this.pulse,
  });

  final String link;
  final LocalStash stash;
  final SignalDock dock;
  final PulseSensor pulse;

  @override
  State<PortalStage> createState() => _PortalStageState();
}

class _PortalStageState extends State<PortalStage>
    with WidgetsBindingObserver {
  late final WebViewController _view;
  bool _spinner = true;
  bool _offlineDispatched = false;
  String? _lastMainFrame;
  int _redirectRetries = 0;
  StreamSubscription<List<ConnectivityResult>>? _connSub;

  // Kept in sync with MainActivity.kt channel name.
  static const MethodChannel _uploadChannel = MethodChannel('pinboard/upload');

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    SystemChrome.setPreferredOrientations(<DeviceOrientation>[
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    _enterImmersive();
    _prepareController();

    widget.dock.onIncomingLink = (String link) {
      if (mounted) _view.loadRequest(Uri.parse(link));
    };

    _connSub =
        widget.pulse.updates.listen((List<ConnectivityResult> statuses) {
      if (statuses.isNotEmpty &&
          statuses.every(
              (ConnectivityResult e) => e == ConnectivityResult.none)) {
        // Synchronous swap — DO NOT await a DNS probe here.
        _routeToOffline();
      }
    });
  }

  void _enterImmersive() {
    // Full immersive — hides both bars. Keyboard is handled entirely by the
    // JS scrollIntoView fix (visualViewport), so we do NOT want Android to
    // physically resize the window.
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _enterImmersive();
  }

  void _prepareController() {
    _view = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setUserAgent(maskedNet.userAgent)
      ..setBackgroundColor(Colors.black)
      ..enableZoom(false)
      ..setNavigationDelegate(NavigationDelegate(
        onPageStarted: (_) {
          if (mounted) setState(() => _spinner = true);
        },
        onPageFinished: (_) {
          if (mounted) setState(() => _spinner = false);
          _redirectRetries = 0;
          _injectSafeAreaKiller();
          _injectKeyboardScroll();
        },
        onWebResourceError: (WebResourceError err) {
          if (err.isForMainFrame != true) return;
          final String desc = err.description.toLowerCase();

          // 1. Redirect-loop recovery.
          final bool loop = desc.contains('too_many_redirects') ||
              desc.contains('too many redirects') ||
              err.errorCode == -1007 ||
              err.errorCode == -9;
          if (loop && _lastMainFrame != null && _redirectRetries < 3) {
            _redirectRetries++;
            _view.loadRequest(Uri.parse(_lastMainFrame!));
            return;
          }

          // 2. Cover the native error page immediately.
          if (mounted) setState(() => _spinner = true);

          // 3. Skip the redundant DNS probe for well-known disconnect codes.
          final bool disconnect = desc.contains('name_not_resolved') ||
              desc.contains('err_name_not_resolved') ||
              desc.contains('internet_disconnected') ||
              desc.contains('network_changed') ||
              err.errorCode == -105 ||
              err.errorCode == -106 ||
              err.errorCode == -21;
          if (disconnect) {
            _routeToOffline();
          } else {
            _routeToOfflineIfDown();
          }
        },
        onNavigationRequest: (NavigationRequest req) {
          final Uri? uri = Uri.tryParse(req.url);
          if (uri == null) return NavigationDecision.prevent;
          const Set<String> inApp = <String>{
            'http',
            'https',
            'about',
            'data',
            'blob',
          };
          if (inApp.contains(uri.scheme)) {
            if (req.isMainFrame) _lastMainFrame = req.url;
            return NavigationDecision.navigate;
          }
          _openExternally(uri);
          return NavigationDecision.prevent;
        },
      ));

    _configureAndroid();
    _view.loadRequest(Uri.parse(widget.link));
  }

  void _configureAndroid() {
    if (!Platform.isAndroid) return;
    if (_view.platform is! AndroidWebViewController) return;
    final AndroidWebViewController a =
        _view.platform as AndroidWebViewController;

    // Inline autoplay, no tap-to-start gate.
    a.setMediaPlaybackRequiresUserGesture(false);

    // Grant partner-site media / DRM permission requests without a modal —
    // the site only asks when the user explicitly opts in.
    a.setOnPlatformPermissionRequest(
      (PlatformWebViewPermissionRequest req) => req.grant(),
    );

    // Native file chooser (no file_picker dependency — see pitfalls §1).
    a.setOnShowFileSelector(_pickFiles);

    // Third-party cookies survive OAuth / cashier redirects.
    final AndroidWebViewCookieManager cookies = AndroidWebViewCookieManager(
      AndroidWebViewCookieManagerCreationParams
          .fromPlatformWebViewCookieManagerCreationParams(
        const PlatformWebViewCookieManagerCreationParams(),
      ),
    );
    cookies.setAcceptThirdPartyCookies(a, true);
  }

  Future<List<String>> _pickFiles(FileSelectorParams params) async {
    try {
      final List<Object?>? picked = await _uploadChannel.invokeMethod<List<Object?>>(
        'pick',
        <String, Object>{
          'multiple': params.mode == FileSelectorMode.openMultiple,
          'mimeTypes':
              params.acceptTypes.where((String t) => t.trim().isNotEmpty).toList(),
        },
      );
      if (picked == null) return const <String>[];
      return picked.whereType<String>().toList();
    } catch (_) {
      return const <String>[];
    }
  }

  Future<void> _openExternally(Uri uri) async {
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {}
  }

  Future<void> _routeToOfflineIfDown() async {
    if (_offlineDispatched) return;
    final bool online = await widget.pulse.isOnline();
    if (online) return;
    _routeToOffline();
  }

  void _routeToOffline() {
    if (_offlineDispatched || !mounted) return;
    _offlineDispatched = true;
    final String resume = _lastMainFrame ?? widget.link;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => NoLinkStage(
          rebuildOnRetry: (_) => PortalStage(
            link: resume,
            stash: widget.stash,
            dock: widget.dock,
            pulse: widget.pulse,
          ),
        ),
      ),
    );
  }

  void _injectKeyboardScroll() {
    _view.runJavaScript(r'''
(function(){
  if (window.__pbKb) return; window.__pbKb = true;
  function isField(el){return el&&(el.tagName==='INPUT'||el.tagName==='TEXTAREA'||el.isContentEditable);}
  function bring(){
    var el=document.activeElement; if(!isField(el))return;
    var vp=window.visualViewport;
    if(vp){
      var r=el.getBoundingClientRect(); var bottom=vp.offsetTop+vp.height;
      if(r.bottom>bottom-20||r.top<vp.offsetTop){el.scrollIntoView({behavior:'auto',block:'nearest'});}
    } else { el.scrollIntoView({behavior:'auto',block:'nearest'}); }
  }
  document.addEventListener('focusin',function(e){ if(isField(e.target)) setTimeout(bring,350); });
  if(window.visualViewport){
    var prev=window.visualViewport.height;
    window.visualViewport.addEventListener('resize',function(){
      var h=window.visualViewport.height; if(h<prev) setTimeout(bring,120); prev=h;
    });
  }
})();
''');
  }

  void _injectSafeAreaKiller() {
    _view.runJavaScript(r'''
(function(){
  if(window.__pbSa) return; window.__pbSa=true;
  var ID='__pb_sa';
  // NOTE: never touch html/body/#app/#root padding — it collapses partner
  // site gutters. Only override safe-area CSS variables + narrow known
  // decorative header classes.
  var CSS=':root{--safe-area-inset-top:0px!important;--safe-area-inset-right:0px!important;'
    +'--safe-area-inset-bottom:0px!important;--safe-area-inset-left:0px!important;'
    +'--sat:0px!important;--sar:0px!important;--sab:0px!important;--sal:0px!important;'
    +'--safe-top:0px!important;--safe-bottom:0px!important;--safe-left:0px!important;--safe-right:0px!important;}'
    +'.gameview-mobile-header,.app-header,.js-safe-top{padding-top:0!important;margin-top:0!important;}';
  function kbOpen(){ if(!window.visualViewport)return false; return window.visualViewport.height<window.innerHeight*0.75; }
  function apply(){
    if(kbOpen())return;
    var head=document.head||document.documentElement; if(!head)return;
    var m=document.querySelector('meta[name="viewport"]');
    if(m && !/viewport-fit\s*=\s*contain/i.test(m.getAttribute('content')||'')){
      var c=(m.getAttribute('content')||'').replace(/,?\s*viewport-fit\s*=\s*\w+/ig,'').trim();
      m.setAttribute('content', c+(c?', ':'')+'viewport-fit=contain');
    }
    var s=document.getElementById(ID);
    if(!s){ s=document.createElement('style'); s.id=ID; head.appendChild(s); }
    if(s.textContent!==CSS) s.textContent=CSS;
  }
  apply();
  ['pushState','replaceState'].forEach(function(fn){
    var o=history[fn]; history[fn]=function(){var r=o.apply(this,arguments); setTimeout(apply,80); setTimeout(apply,400); return r;};
  });
  window.addEventListener('popstate',function(){setTimeout(apply,80);});
  setInterval(apply,2500);
})();
''');
  }

  Future<void> _back() async {
    if (await _view.canGoBack()) {
      await _view.goBack();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _connSub?.cancel();
    widget.dock.onIncomingLink = null;
    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.manual,
      overlays: SystemUiOverlay.values,
    );
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final MediaQueryData mq = MediaQuery.of(context);
    final bool landscape = mq.orientation == Orientation.landscape;
    // Keep the WebView clear of the portrait status band (visible even in
    // immersiveSticky briefly after a swipe) and of the camera cutout in
    // landscape. `SafeArea(bottom: false)` handles both without adding a
    // bottom inset that would clip content while the keyboard is up.
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, _) async {
        if (!didPop) await _back();
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        resizeToAvoidBottomInset: false,
        body: Stack(
          fit: StackFit.expand,
          children: <Widget>[
            SafeArea(
              bottom: false,
              child: WebViewWidget(controller: _view),
            ),
            if (_spinner && !landscape)
              const ColoredBox(
                color: Color(0x88000000),
                child: Center(
                  child: CircularProgressIndicator(
                    valueColor:
                        AlwaysStoppedAnimation<Color>(AppTheme.accent),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
