import 'package:flutter/material.dart';

import '../config/pinboard_brief.dart';
import '../media_library.dart';
import '../spine/insight.dart';
import '../spine/local_stash.dart';
import '../spine/pulse_sensor.dart';
import '../spine/signal_dock.dart';
import 'neon_pill_action.dart';
import 'portal_stage.dart';

/// Push opt-in promo shown once (per cooldown) before the WebView opens.
///
/// Layout rules (from the user brief):
///   - NO `SafeArea` — the landscape safe-area inset would shift the
///     horizontal center and the Accept / Skip pills would no longer sit
///     under the artwork's plaque. Buttons must always be centered on the
///     true horizontal midpoint of the screen.
///   - Accept + Skip are stacked (Column) so their widths match, and the
///     stack is placed by [Positioned(left: 0, right: 0, bottom: ...)] +
///     [Center] to guarantee horizontal centering in both orientations.
class AlertPromptStage extends StatefulWidget {
  const AlertPromptStage({
    super.key,
    required this.stash,
    required this.dock,
    required this.pulse,
    required this.contentLink,
  });

  final LocalStash stash;
  final SignalDock dock;
  final PulseSensor pulse;
  final String contentLink;

  @override
  State<AlertPromptStage> createState() => _AlertPromptStageState();
}

class _AlertPromptStageState extends State<AlertPromptStage> {
  @override
  void initState() {
    super.initState();
    Insight.screen('push_invite');
  }

  Future<void> _accept(BuildContext context) async {
    Insight.event('push_invite_accept');
    final bool granted = await widget.dock.askPermission();
    Insight.tag('notif_permission', granted ? 'granted' : 'denied');
    Insight.event(granted ? 'push_granted' : 'push_denied');
    if (!granted) {
      await widget.stash.writeAlertPromptCooldown(_cooldownTarget());
    }
    if (context.mounted) _forward(context);
  }

  Future<void> _skip(BuildContext context) async {
    Insight.event('push_invite_skip');
    Insight.tag('notif_permission', 'skipped');
    await widget.stash.writeAlertPromptCooldown(_cooldownTarget());
    if (context.mounted) _forward(context);
  }

  int _cooldownTarget() =>
      DateTime.now().millisecondsSinceEpoch ~/ 1000 +
      PinboardBrief.alertPromptCooldown;

  void _forward(BuildContext context) {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => PortalStage(
          link: widget.contentLink,
          stash: widget.stash,
          dock: widget.dock,
          pulse: widget.pulse,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final Size size = MediaQuery.of(context).size;
    final bool landscape =
        MediaQuery.of(context).orientation == Orientation.landscape;
    final String bg = landscape
        ? MediaLibrary.horizontalAlerts
        : MediaLibrary.verticalAlerts;

    final double buttonWidth =
        landscape ? size.width * 0.36 : size.width * 0.68;
    final double bottom =
        landscape ? size.height * 0.07 : size.height * 0.08;
    final double gap = landscape ? 10 : 14;

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          Image.asset(
            bg,
            fit: BoxFit.cover,
            width: size.width,
            height: size.height,
          ),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.center,
                end: Alignment.bottomCenter,
                colors: <Color>[Colors.transparent, Color(0x99000000)],
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: bottom,
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: <Widget>[
                  NeonPillAction(
                    label: 'Accept',
                    width: buttonWidth,
                    height: landscape ? 50 : 56,
                    compact: landscape,
                    onTap: () => _accept(context),
                  ),
                  SizedBox(height: gap),
                  NeonGhostAction(
                    label: 'Skip',
                    width: buttonWidth,
                    height: landscape ? 42 : 48,
                    compact: landscape,
                    onTap: () => _skip(context),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
