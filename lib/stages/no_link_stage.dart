import 'package:flutter/material.dart';

import '../media_library.dart';
import '../spine/insight.dart';
import 'neon_pill_action.dart';

/// Shown when the device has no reachable connection. Uses the project's
/// dedicated no-wifi artwork (orientation-aware) with a Retry pill overlaid
/// at the bottom. Retry rebuilds whatever screen the caller supplies —
/// typically the loading pipeline.
///
/// Layout rules (from the user brief):
///   - NO `SafeArea` on this screen. Landscape safe-area padding would
///     shift the horizontal center off-axis so the button no longer aligns
///     with the artwork's plaque, which reads as broken.
///   - Retry button is always centered on the true horizontal midpoint.
class NoLinkStage extends StatefulWidget {
  const NoLinkStage({super.key, required this.rebuildOnRetry});

  final WidgetBuilder rebuildOnRetry;

  @override
  State<NoLinkStage> createState() => _NoLinkStageState();
}

class _NoLinkStageState extends State<NoLinkStage> {
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    Insight.screen('offline');
  }

  Future<void> _retry() async {
    if (_busy) return;
    Insight.event('offline_retry');
    setState(() => _busy = true);
    await Future<void>.delayed(const Duration(milliseconds: 550));
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(builder: widget.rebuildOnRetry),
    );
  }

  @override
  Widget build(BuildContext context) {
    final Size size = MediaQuery.of(context).size;
    final bool landscape =
        MediaQuery.of(context).orientation == Orientation.landscape;
    final String bg = landscape
        ? MediaLibrary.horizontalNoWifi
        : MediaLibrary.verticalNoWifi;

    // Button geometry — kept proportional so it aligns with the artwork's
    // plate in both orientations and never covers the illustration.
    final double buttonWidth = landscape
        ? size.width * 0.32
        : size.width * 0.62;
    final double buttonHeight = landscape ? 52 : 56;
    final double buttonBottom = landscape
        ? size.height * 0.11
        : size.height * 0.09;

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
            bottom: buttonBottom,
            child: Center(
              child: _busy
                  ? const SizedBox(
                      width: 40,
                      height: 40,
                      child: CircularProgressIndicator(
                        strokeWidth: 3,
                        valueColor:
                            AlwaysStoppedAnimation<Color>(AppTheme.accent),
                      ),
                    )
                  : NeonPillAction(
                      label: 'Retry',
                      width: buttonWidth,
                      height: buttonHeight,
                      onTap: _retry,
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
