/// Nhắc nhở bằng thông báo: phần giao diện chung.
///
/// App thật dùng LocalReminders (thông báo của Android). Kiểm thử dùng
/// NoReminders để không cần tới điện thoại.
library;

/// Mức lặp của nhắc tiết kiệm.
enum ReminderRepeat { daily, weekly, monthly }

abstract class Reminders {
  /// Xin quyền hiện thông báo. Trả về true nếu được phép.
  Future<bool> requestPermission();

  /// Đặt nhắc tiết kiệm lặp lại lúc [hour]:[minute]. Hằng tuần thì vào
  /// [weekday] (1 = thứ Hai … 7 = Chủ nhật); hằng tháng thì vào ngày
  /// [monthDay] (1–28). Thay cho lần đặt trước đó. [skipCurrentPeriod] true
  /// khi kỳ này (hôm nay, tuần này hoặc tháng này) đã tiết kiệm rồi: lần nhắc
  /// đầu tiên rơi vào kỳ sau.
  Future<void> scheduleSavings({
    required ReminderRepeat repeat,
    required int hour,
    required int minute,
    int weekday = 7,
    int monthDay = 1,
    bool skipCurrentPeriod = false,
    required String title,
    required String body,
  });

  Future<void> cancel();

  /// Nhắc ghi chi tiêu mỗi ngày lúc [hour]:[minute]. [skipToday] true thì
  /// lần nhắc đầu tiên là ngày mai (hôm nay đã ghi khoản chi rồi).
  Future<void> scheduleExpenseCheck({
    required int hour,
    required int minute,
    required bool skipToday,
    required String title,
    required String body,
  });

  Future<void> cancelExpenseCheck();
}

class NoReminders implements Reminders {
  const NoReminders();

  @override
  Future<bool> requestPermission() async => true;

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
  }) async {}

  @override
  Future<void> cancel() async {}

  @override
  Future<void> scheduleExpenseCheck({
    required int hour,
    required int minute,
    required bool skipToday,
    required String title,
    required String body,
  }) async {}

  @override
  Future<void> cancelExpenseCheck() async {}
}
