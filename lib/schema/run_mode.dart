/// Which experience the shell locked onto for this install.
///
/// - [portal]  → returning user previously routed to the WebView.
/// - [arcade]  → returning user previously routed to the native game.
/// - [drifting] → first launch, no routing decision has been made yet.
enum RunMode {
  portal,
  arcade,
  drifting;

  static RunMode fromStorage(String? raw) {
    switch (raw) {
      case 'portal':
        return RunMode.portal;
      case 'arcade':
        return RunMode.arcade;
      default:
        return RunMode.drifting;
    }
  }

  String toStorage() => name;
}
