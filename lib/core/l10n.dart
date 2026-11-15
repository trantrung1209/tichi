/// Ngôn ngữ đang dùng. TichiApp đặt [L10n.en] theo cài đặt của người dùng
/// (Theo máy, Tiếng Việt hoặc English), rồi vẽ lại toàn bộ màn hình.
library;

class L10n {
  L10n._();

  /// true: tiếng Anh; false: tiếng Việt.
  static bool en = false;
}

/// Chọn câu theo ngôn ngữ đang dùng: [vi] cho tiếng Việt, [en] cho tiếng Anh.
String tr(String vi, String en) => L10n.en ? en : vi;
