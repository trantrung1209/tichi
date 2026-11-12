/// Nhắc tiết kiệm bằng thông báo của Android (flutter_local_notifications).
///
/// - Dùng lịch "không chính xác tuyệt đối" (inexactAllowWhileIdle) nên không
///   cần quyền báo thức chính xác; Android có thể trễ vài phút để tiết kiệm pin.
/// - Giờ nhắc tính theo giờ trên máy rồi đổi sang UTC. Việt Nam không đổi giờ
///   theo mùa nên giờ nhắc luôn đúng.
library;

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;

import 'reminders.dart';

const int _reminderId = 1001;
const String savingsReminderPayload = 'savings_reminder';

class LocalReminders implements Reminders {
  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  /// [onTap] được gọi khi người dùng bấm vào thông báo lúc app đang mở.
  Future<void> init({void Function()? onTap}) async {
    const settings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher_foreground'),
    );
    await _plugin.initialize(
      settings: settings,
      onDidReceiveNotificationResponse: (response) {
        if (response.payload == savingsReminderPayload) onTap?.call();
      },
    );
  }

  /// True nếu app vừa được mở bằng cách bấm vào thông báo nhắc tiết kiệm.
  Future<bool> launchedFromReminder() async {
    final details = await _plugin.getNotificationAppLaunchDetails();
    return (details?.didNotificationLaunchApp ?? false) &&
        details?.notificationResponse?.payload == savingsReminderPayload;
  }

  @override
  Future<bool> requestPermission() async {
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    return await android?.requestNotificationsPermission() ?? true;
  }

  @override
  Future<void> scheduleDaily({
    required int hour,
    required int minute,
    required String title,
    required String body,
  }) async {
    await _plugin.cancel(id: _reminderId);
    final now = DateTime.now();
    var next = DateTime(now.year, now.month, now.day, hour, minute);
    if (!next.isAfter(now)) next = next.add(const Duration(days: 1));
    await _plugin.zonedSchedule(
      id: _reminderId,
      title: title,
      body: body,
      scheduledDate: tz.TZDateTime.from(next, tz.UTC),
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          'savings_reminder',
          'Nhắc tiết kiệm',
          channelDescription: 'Nhắc tiết kiệm hằng ngày theo giờ bạn chọn',
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
      payload: savingsReminderPayload,
    );
  }

  @override
  Future<void> cancel() => _plugin.cancel(id: _reminderId);
}
