import 'package:flutter_foreground_task/flutter_foreground_task.dart';

// 必须是顶层函数，且带此 pragma，才能在独立 isolate 中被调用
@pragma('vm:entry-point')
void _ttsTaskCallback() {
  FlutterForegroundTask.setTaskHandler(_TtsTaskHandler());
}

class _TtsTaskHandler extends TaskHandler {
  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {}

  @override
  void onRepeatEvent(DateTime timestamp) {}

  @override
  Future<void> onDestroy(DateTime timestamp) async {}
}

/// 封装 flutter_foreground_task 的生命周期，供 TtsRepository 调用。
class TtsForegroundService {
  static const _serviceId = 501;

  static void init() {
    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: 'synneu_tts',
        channelName: 'Synneu TTS 服务',
        channelDescription: 'TTS 语音合成与播放后台服务',
        onlyAlertOnce: true,
        playSound: false,
      ),
      iosNotificationOptions: const IOSNotificationOptions(
        showNotification: false,
      ),
      foregroundTaskOptions: ForegroundTaskOptions(
        eventAction: ForegroundTaskEventAction.nothing(),
        autoRunOnBoot: false,
      ),
    );
  }

  static Future<void> start(String message) async {
    if (await FlutterForegroundTask.isRunningService) {
      await update(message);
      return;
    }
    await FlutterForegroundTask.startService(
      serviceId: _serviceId,
      notificationTitle: 'Synneu TTS',
      notificationText: message,
      callback: _ttsTaskCallback,
    );
  }

  static Future<void> update(String message) async {
    await FlutterForegroundTask.updateService(
      notificationTitle: 'Synneu TTS',
      notificationText: message,
    );
  }

  static Future<void> stop() async {
    if (await FlutterForegroundTask.isRunningService) {
      await FlutterForegroundTask.stopService();
    }
  }
}
