/// Non-web stubs for web screenshot privacy mode & notifications
void setWebPrivacyMode(bool enabled) {}

void showBrowserNotification(String title, String body) {}

Future<String> requestBrowserNotificationPermission() async {
  return 'denied';
}
