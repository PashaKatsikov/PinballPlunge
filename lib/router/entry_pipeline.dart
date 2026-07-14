import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../media_library.dart';
import '../schema/relay_verdict.dart';
import '../schema/run_mode.dart';
import '../screens/home_screen.dart';
import '../spine/insight.dart';
import '../spine/local_stash.dart';
import '../spine/pulse_sensor.dart';
import '../spine/relay_post.dart';
import '../spine/signal_dock.dart';
import '../spine/tracker_link.dart';
import '../stages/alert_prompt_stage.dart';
import '../stages/no_link_stage.dart';
import '../stages/portal_stage.dart';

/// Loading screen + routing engine — the single startup surface.
///
/// Directly implements the state machine in
/// `.cursor/rules/android_gray_guide.md §"Gray Flow State Machine"`. Do NOT
/// weaken any branch here without re-reading that section first.
///
/// FIRST-LAUNCH UX INVARIANT:
///   Non-organic install + Wi-Fi OFF must show the NoLinkStage on frame one
///   (before AppsFlyer is spooled). Retry restarts the entire pipeline from
///   here; the mode stays [RunMode.drifting] until we get an actual gate
///   reply, so the offline-boot user is not permanently trapped in the
///   native game.
class EntryPipeline extends StatefulWidget {
  const EntryPipeline({
    super.key,
    required this.stash,
    required this.pulse,
    required this.tracker,
    required this.relay,
    required this.dock,
  });

  final LocalStash stash;
  final PulseSensor pulse;
  final TrackerLink tracker;
  final RelayPost relay;
  final SignalDock dock;

  @override
  State<EntryPipeline> createState() => _EntryPipelineState();
}

class _EntryPipelineState extends State<EntryPipeline>
    with SingleTickerProviderStateMixin {
  double _progress = 0.06;
  bool _routed = false;
  late final AnimationController _dots;

  @override
  void initState() {
    super.initState();
    _dots = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
    widget.dock.onTokenRotated = _repostOnTokenRefresh;
    Insight.screen('loading');
    _drive();
  }

  @override
  void dispose() {
    widget.dock.onTokenRotated = null;
    _dots.dispose();
    super.dispose();
  }

  void _lift(double value) {
    if (mounted) setState(() => _progress = value);
  }

  Future<void> _drive() async {
    await widget.dock.engage();
    _lift(0.22);

    switch (widget.stash.readMode()) {
      case RunMode.arcade:
        await _openArcade(startAt: 0.4);
        break;
      case RunMode.portal:
        await _resumePortal();
        break;
      case RunMode.drifting:
        await _firstLaunch();
        break;
    }
  }

  Future<void> _firstLaunch() async {
    // Frame-one offline check. If we cannot reach the internet, jump straight
    // to the no-wifi screen. Do NOT commit to RunMode.arcade — the user just
    // has no network yet.
    if (!await widget.pulse.isOnline()) {
      _toOffline();
      return;
    }
    _lift(0.42);

    await widget.tracker.spool();
    await Future.wait<void>(<Future<void>>[
      widget.tracker.awaitInstallPayload(),
      widget.tracker.awaitDeepLink(),
    ]);
    _lift(0.7);

    final RelayVerdict verdict = await _askRelay();
    if (verdict.approved && verdict.hasDestination) {
      await widget.stash.writeMode(RunMode.portal);
      _lift(1.0);
      await _settle();
      _toPortal(verdict.destination!);
    } else {
      // Only a successful HTTP reply with ok:false commits to the arcade —
      // never a network failure.
      if (verdict.diagnostic != 'no-endpoint' &&
          !verdict.diagnostic!.startsWith('http-')) {
        // Genuine transport failure — fall back to the arcade for this
        // launch only, do NOT persist the mode.
        await _openArcade(startAt: 0.9);
        return;
      }
      await widget.stash.writeMode(RunMode.arcade);
      await _openArcade(startAt: 0.9);
    }
  }

  Future<void> _resumePortal() async {
    if (!await widget.pulse.isOnline()) {
      _lift(1.0);
      _toOffline();
      return;
    }
    _lift(0.42);

    // Pending push URL wins over everything.
    final String? pending = await widget.stash.takePendingLink();
    if (pending != null) {
      Insight.event('route_push_link');
      _lift(1.0);
      await _settle();
      _toPortal(pending);
      return;
    }

    final String? cached = await widget.stash.readCachedLink();

    await widget.tracker.spool();
    await Future.wait<void>(<Future<void>>[
      widget.tracker.awaitInstallPayload(seconds: 10),
      widget.tracker.awaitDeepLink(),
    ]);
    _lift(0.75);

    final RelayVerdict verdict = await _askRelay();
    _lift(1.0);
    await _settle();

    if (verdict.approved && verdict.hasDestination) {
      _toPortal(verdict.destination!);
    } else if (cached != null && cached.isNotEmpty) {
      Insight.event('route_cached_link');
      _toPortal(cached);
    } else {
      _toOffline();
    }
  }

  Future<RelayVerdict> _askRelay() async {
    final String locale = Platform.localeName.replaceAll('-', '_');
    final Map<String, dynamic> body =
        await widget.tracker.assembleGateBody(
      locale: locale,
      pushToken: widget.dock.token,
    );
    // Identify the session by AppsFlyer id as soon as attribution is known.
    Insight.identify(
      body['af_id']?.toString(),
      tags: <String, String>{
        'af_status': body['af_status']?.toString() ?? '',
        'media_source': body['media_source']?.toString() ?? '',
        'campaign': body['campaign']?.toString() ?? '',
        'os': body['os']?.toString() ?? '',
        'locale': body['locale']?.toString() ?? '',
      },
    );
    return widget.relay.query(body);
  }

  void _repostOnTokenRefresh(String token) async {
    final String locale = Platform.localeName.replaceAll('-', '_');
    final Map<String, dynamic> body =
        await widget.tracker.assembleGateBody(
      locale: locale,
      pushToken: token,
    );
    widget.relay.query(body);
  }

  Future<void> _settle() =>
      Future<void>.delayed(const Duration(milliseconds: 320));

  Future<void> _openArcade({required double startAt}) async {
    Insight.tag('run_mode', 'native');
    Insight.event('route_native');
    _lift(startAt);
    // The arcade is portrait-only.
    await SystemChrome.setPreferredOrientations(<DeviceOrientation>[
      DeviceOrientation.portraitUp,
    ]);
    await _warmArcadeArt();
    _lift(1.0);
    await _settle();
    if (_routed || !mounted) return;
    _routed = true;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(builder: (_) => const HomeScreen()),
    );
  }

  Future<void> _warmArcadeArt() async {
    for (final String path in MediaLibrary.arcadeArt) {
      if (!mounted) return;
      try {
        await precacheImage(AssetImage(path), context);
      } catch (_) {}
    }
  }

  void _toPortal(String link) {
    if (_routed || !mounted) return;
    _routed = true;
    Insight.tag('run_mode', 'web');
    Insight.event('route_web');
    if (widget.stash.shouldOfferAlertPrompt()) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(
          builder: (_) => AlertPromptStage(
            stash: widget.stash,
            dock: widget.dock,
            pulse: widget.pulse,
            contentLink: link,
          ),
        ),
      );
    } else {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(
          builder: (_) => PortalStage(
            link: link,
            stash: widget.stash,
            dock: widget.dock,
            pulse: widget.pulse,
          ),
        ),
      );
    }
  }

  void _toOffline() {
    if (_routed || !mounted) return;
    _routed = true;
    Insight.event('route_offline');
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => NoLinkStage(
          rebuildOnRetry: (_) => EntryPipeline(
            stash: widget.stash,
            pulse: widget.pulse,
            tracker: widget.tracker,
            relay: widget.relay,
            dock: widget.dock,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool landscape =
        MediaQuery.of(context).orientation == Orientation.landscape;
    final String bg = landscape
        ? MediaLibrary.horizontalLoading
        : MediaLibrary.verticalLoading;

    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: AppTheme.background,
        body: IgnorePointer(
          child: Stack(
            fit: StackFit.expand,
            children: <Widget>[
              Image.asset(bg, fit: BoxFit.cover),
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.center,
                    end: Alignment.bottomCenter,
                    colors: <Color>[Colors.transparent, Color(0x99000000)],
                  ),
                ),
              ),
              Align(
                alignment: Alignment.bottomCenter,
                child: Padding(
                  padding: EdgeInsets.only(
                    left: 32,
                    right: 32,
                    bottom: landscape ? 30 : 60,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      AnimatedBuilder(
                        animation: _dots,
                        builder: (BuildContext context, _) {
                          final int n =
                              (_dots.value * 4).floor() % 4;
                          return Text(
                            'Loading${'.' * n}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1.5,
                              height: 1.0,
                              shadows: <Shadow>[
                                Shadow(
                                  color: Color(0xFF7A5CFF),
                                  blurRadius: 16,
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 14),
                      _ProgressTrack(value: _progress),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProgressTrack extends StatelessWidget {
  const _ProgressTrack({required this.value});

  final double value;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints c) {
        return Container(
          height: 18,
          decoration: BoxDecoration(
            color: const Color(0x55000000),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.8),
              width: 2,
            ),
          ),
          child: Align(
            alignment: Alignment.centerLeft,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 240),
              curve: Curves.easeOut,
              width: c.maxWidth * value.clamp(0.0, 1.0),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: <Color>[
                    Color(0xFF23D6E0),
                    Color(0xFF1E7BFF),
                    Color(0xFFFF2FB3),
                  ],
                ),
                borderRadius: BorderRadius.circular(10),
                boxShadow: const <BoxShadow>[
                  BoxShadow(color: Color(0xAAFF2FB3), blurRadius: 10),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
