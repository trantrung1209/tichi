/// Nhắc tiết kiệm hằng ngày: phần giao diện chung.
///
/// App thật dùng LocalReminders (thông báo của Android). Kiểm thử dùng
/// NoReminders để không cần tới điện thoại.
library;

abstract class Reminders {
  /// Xin quyền hiện thông báo. Trả về true nếu được phép.
  Future<bool> requestPermission();

  /// Đặt nhắc mỗi ngày lúc [hour]:[minute] với nội dung cho trước. Thay cho
  /// lần đặt trước đó.
  Future<void> scheduleDaily({
    required int hour,
    required int minute,
    required String title,
    required String body,
  });

  Future<void> cancel();
}

class NoReminders implements Reminders {
  const NoReminders();

  @override
  Future<bool> requestPermission() async => true;

  @override
  Future<void> scheduleDaily({
    required int hour,
    required int minute,
    required String title,
    required String body,
  }) async {}

  @override
  Future<void> cancel() async {}
}
