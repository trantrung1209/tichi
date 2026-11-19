/// Nhắc nhở bằng thông báo của điện thoại (flutter_local_notifications),
/// chạy trên cả Android và iPhone.
///
/// - Dùng lịch "không chính xác tuyệt đối" (inexactAllowWhileIdle) nên không
///   cần quyền báo thức chính xác; Android có thể trễ vài phút để tiết kiệm pin.
/// - Giờ nhắc tính theo giờ trên máy rồi đổi sang UTC. Việt Nam không đổi giờ
///   theo mùa nên giờ nhắc luôn đúng.
library;

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;

import 'reminders.dart';
import '../core/l10n.dart';

const int _reminderId = 1001;
const int _expenseReminderId = 1002;
const String savingsReminderPayload = 'savings_reminder';
const String expenseReminderPayload = 'expense_reminder';

/// Lần nhắc kế tiếp theo giờ trên máy, sau thời điểm [now].
///
/// [skipToday] (hằng ngày) hoặc [skipCurrentPeriod] (mọi mức): kỳ hiện tại đã
/// làm rồi nên không nhắc trong kỳ này. Kỳ = ngày, tuần (thứ Hai tới Chủ
/// nhật) hoặc tháng chứa [now].
DateTime nextReminderTime({
  required DateTime now,
  required ReminderRepeat repeat,
  required int hour,
  required int minute,
  int weekday = 7,
  int monthDay = 1,
  bool skipToday = false,
  bool skipCurrentPeriod = false,
}) {
  switch (repeat) {
    case ReminderRepeat.daily:
      var next = DateTime(now.year, now.month, now.day, hour, minute);
      if (skipToday || skipCurrentPeriod || !next.isAfter(now)) {
        next = DateTime(now.year, now.month, now.day + 1, hour, minute);
      }
      return next;
    case ReminderRepeat.weekly:
      final offset = (weekday - now.weekday) % 7;
      var next = DateTime(now.year, now.month, now.day + offset, hour, minute);
      if (!next.isAfter(now)) {
        next = DateTime(next.year, next.month, next.day + 7, hour, minute);
      }
      if (skipCurrentPeriod) {
        final weekEnd = DateTime(now.year, now.month, now.day + 8 - now.weekday);
        if (next.isBefore(weekEnd)) {
          next = DateTime(next.year, next.month, next.day + 7, hour, minute);
        }
      }
      return next;
    case ReminderRepeat.monthly:
      var next = DateTime(now.year, now.month, monthDay, hour, minute);
      if (!next.isAfter(now) || skipCurrentPeriod) {
        next = DateTime(now.year, now.month + 1, monthDay, hour, minute);
      }
      return next;
  }
}

class LocalReminders implements Reminders {
  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  /// [onTap] được gọi với payload khi người dùng bấm vào thông báo lúc app
  /// đang mở.
  Future<void> init({void Function(String payload)? onTap}) async {
    const settings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher_foreground'),
      // iPhone: không xin quyền ngay khi mở app; chỉ xin khi người dùng bật
      // nhắc nhở (xem requestPermission).
      iOS: DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      ),
    );
    await _plugin.initialize(
      settings: settings,
      onDidReceiveNotificationResponse: (response) {
        final payload = response.payload;
        if (payload != null) onTap?.call(payload);
      },
    );
  }

  /// Payload của thông báo đã mở app, hoặc null nếu app mở bình thường.
  Future<String?> launchPayload() async {
    final details = await _plugin.getNotificationAppLaunchDetails();
    if (!(details?.didNotificationLaunchApp ?? false)) return null;
    return details?.notificationResponse?.payload;
  }

  @override
  Future<bool> requestPermission() async {
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (android != null) {
      return await android.requestNotificationsPermission() ?? true;
    }
    final ios = _plugin.resolvePlatformSpecificImplementation<
        IOSFlutterLocalNotificationsPlugin>();
    if (ios != null) {
      return await ios.requestPermissions(
              alert: true, badge: false, sound: true) ??
          false;
    }
    return true;
  }

  @override
  Future<void> scheduleSavings({
    required ReminderRepeat repeat,
    required int hour,
    required int minute,
    int weekday = 7,
    int monthDay = 1,
    bool skipCurrentPeriod = false,
    required String title,
    required String body,
  }) async {
    await _plugin.cancel(id: _reminderId);
    final next = nextReminderTime(
        now: DateTime.now(),
        repeat: repeat,
        hour: hour,
        minute: minute,
        weekday: weekday,
        monthDay: monthDay,
        skipCurrentPeriod: skipCurrentPeriod);
    await _plugin.zonedSchedule(
      id: _reminderId,
      title: title,
      body: body,
      scheduledDate: tz.TZDateTime.from(next, tz.UTC),
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          'savings_reminder',
          tr('Nhắc tiết kiệm', 'Savings reminder'),
          channelDescription: tr('Nhắc tiết kiệm theo lịch bạn chọn',
              'Savings reminder on the schedule you choose'),
        ),
        iOS: const DarwinNotificationDetails(),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      matchDateTimeComponents: switch (repeat) {
        ReminderRepeat.daily => DateTimeComponents.time,
        ReminderRepeat.weekly => DateTimeComponents.dayOfWeekAndTime,
        ReminderRepeat.monthly => DateTimeComponents.dayOfMonthAndTime,
      },
      payload: savingsReminderPayload,
    );
  }

  @override
  Future<void> cancel() => _plugin.cancel(id: _reminderId);

  @override
  Future<void> scheduleExpenseCheck({
    required int hour,
    required int minute,
    required bool skipToday,
    required String title,
    required String body,
  }) async {
    await _plugin.cancel(id: _expenseReminderId);
    final next = nextReminderTime(
        now: DateTime.now(),
        repeat: ReminderRepeat.daily,
        hour: hour,
        minute: minute,
        skipToday: skipToday);
    await _plugin.zonedSchedule(
      id: _expenseReminderId,
      title: title,
      body: body,
      scheduledDate: tz.TZDateTime.from(next, tz.UTC),
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          'expense_reminder',
          tr('Nhắc ghi chi tiêu', 'Expense reminder'),
          channelDescription: tr(
              'Nhắc lúc tối khi cả ngày chưa ghi khoản chi nào',
              'Evening reminder when no expense was logged today'),
        ),
        iOS: const DarwinNotificationDetails(),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
      payload: expenseReminderPayload,
    );
  }

  @override
  Future<void> cancelExpenseCheck() => _plugin.cancel(id: _expenseReminderId);
}
