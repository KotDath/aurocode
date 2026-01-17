class AppConstants {
  AppConstants._();

  static const double fileTreeWidth = 280;
  static const double aiPanelWidth = 320;
  static const double minPanelWidth = 150;
  static const double terminalHeight = 200;
  static const double minTerminalHeight = 100;

  static const Duration lspTimeout = Duration(seconds: 30);
  static const Duration fileWatcherDebounce = Duration(milliseconds: 300);
}
