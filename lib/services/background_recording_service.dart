import 'package:flutter/foundation.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';

/// Keeps microphone recording alive when the app is backgrounded, via an
/// Android foreground service with a persistent notification. Android 14+
/// kills background microphone access without one; there is no web/desktop
/// equivalent, so this is a no-op there.
///
/// The task handler itself does no work — actual recording continues in the
/// main isolate via the `record` package. Starting the foreground service is
/// what keeps the OS from killing the process while backgrounded.
class BackgroundRecordingService {
  static bool get isSupported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  static void init() {
    if (!isSupported) return;
    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: 'recording_service',
        channelName: 'පටිගත කිරීමේ සේවාව',
        channelDescription: 'පටිගත කිරීමක් ක්‍රියාත්මක වන විට පෙන්වයි.',
        onlyAlertOnce: true,
      ),
      iosNotificationOptions: const IOSNotificationOptions(
        showNotification: false,
        playSound: false,
      ),
      foregroundTaskOptions: ForegroundTaskOptions(
        eventAction: ForegroundTaskEventAction.nothing(),
        allowWakeLock: true,
      ),
    );
  }

  static Future<void> start() async {
    if (!isSupported) return;

    if (await FlutterForegroundTask.checkNotificationPermission() !=
        NotificationPermission.granted) {
      await FlutterForegroundTask.requestNotificationPermission();
    }

    await FlutterForegroundTask.startService(
      serviceId: 256,
      serviceTypes: const [ForegroundServiceTypes.microphone],
      notificationTitle: 'පටිගත කරමින්',
      notificationText: 'පටිගත කිරීම පසුබිමින් ක්‍රියාත්මක වේ',
      callback: _startCallback,
    );
  }

  static Future<void> stop() async {
    if (!isSupported) return;
    await FlutterForegroundTask.stopService();
  }
}

@pragma('vm:entry-point')
void _startCallback() {
  FlutterForegroundTask.setTaskHandler(_NoOpTaskHandler());
}

class _NoOpTaskHandler extends TaskHandler {
  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {}

  @override
  void onRepeatEvent(DateTime timestamp) {}

  @override
  Future<void> onDestroy(DateTime timestamp, bool isTimeout) async {}

  @override
  void onReceiveData(Object data) {}

  @override
  void onNotificationButtonPressed(String id) {}

  @override
  void onNotificationPressed() {}

  @override
  void onNotificationDismissed() {}
}
