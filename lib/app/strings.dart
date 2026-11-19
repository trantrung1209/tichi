/// Chữ hiển thị cho các phần mới (tên gọi, lời chào, Giới thiệu), có cả
/// tiếng Việt và tiếng Anh. Là getter nên đổi theo ngôn ngữ đang dùng.
library;

import '../core/l10n.dart';

class TichiStrings {
  TichiStrings._();

  // ----------------------------------------------------- Thông tin app
  static const appName = 'Tichi';
  static const appVersion = '1.3.0';
  static const author = 'Trung Nguyen';

  // ----------------------------------------------------------- Tên gọi
  static String get nameTitle => tr('Chào bạn! Tichi có thể gọi bạn là gì?',
      'Hi there! What should Tichi call you?');
  static String get nameLead => tr(
      'Hãy cho Tichi biết tên bạn để cá nhân hóa trải nghiệm.',
      'Tell Tichi your name to personalize your experience.');
  static String get nameHint => tr('Tên hoặc biệt danh', 'Name or nickname');
  static String get namePrivacy => tr(
      'Tên chỉ lưu trên máy này, không gửi đi đâu cả.',
      'Your name stays on this phone and is never sent anywhere.');
  static String get nameStart => tr('Bắt đầu', 'Get started');
  static String get editNameTitle => tr('Tên gọi của bạn', 'Your name');
  static String get editNameLabel =>
      tr('Tên hoặc biệt danh', 'Name or nickname');

  // ---------------------------------------------------------- Lời chào
  static String hello(String? name) => name == null
      ? tr('Xin chào 👋', 'Hello 👋')
      : tr('Xin chào, $name 👋', 'Hello, $name 👋');

  /// Câu chúc theo giờ trong ngày.
  static String timeGreeting(DateTime now) {
    final hour = now.hour;
    if (hour >= 5 && hour < 11) return tr('Chào buổi sáng', 'Good morning');
    if (hour >= 11 && hour < 14) return tr('Chào buổi trưa', 'Good afternoon');
    if (hour >= 14 && hour < 18) return tr('Chào buổi chiều', 'Good afternoon');
    return tr('Chào buổi tối', 'Good evening');
  }

  // ------------------------------------------------------------ Thoát app
  static String get pressBackAgain => tr(
      'Nhấn quay lại lần nữa để thoát Tichi', 'Press back again to exit Tichi');

  // ---------------------------------------------------------- Ngôn ngữ
  static String get languageTitle => tr('Ngôn ngữ', 'Language');

  // ---------------------------------------------------------- Giới thiệu
  static String get aboutMenu => tr('Giới thiệu về Tichi', 'About Tichi');
  static String get aboutMenuSubtitle =>
      tr('Tichi là gì, giúp bạn điều gì', 'What Tichi is and how it helps');
  static String get guideMenu => tr('Xem lại hướng dẫn', 'View the guide');
  static String get guideMenuSubtitle =>
      tr('Cách dùng Tichi qua từng bước', 'How to use Tichi, step by step');
  static String get aboutLead => tr(
      'Tichi giúp bạn quản lý tiền rõ ràng hơn, chi tiêu có kế hoạch và từng '
          'bước xây dựng thói quen tiết kiệm.',
      'Tichi helps you see your money clearly, spend with a plan and build '
          'a saving habit step by step.');
  static String get aboutFeaturesTitle => tr('Tichi có gì', 'What\'s inside');

  /// (biểu tượng, màu, tiêu đề, mô tả). Chỉ liệt kê tính năng đã có.
  static List<(String, String, String, String)> get aboutFeatures => [
        ('home', 'emerald', tr('Tổng quan', 'Overview'),
            tr('Theo dõi tình hình tài chính của bạn.',
                'Keep track of your finances at a glance.')),
        ('bills', 'blue', tr('Giao dịch', 'Transactions'),
            tr('Ghi chép và quản lý thu nhập, chi tiêu và chuyển tiền.',
                'Record and manage income, expenses and transfers.')),
        ('wallet', 'purple', tr('Ví', 'Wallets'),
            tr('Quản lý tiền ở nhiều ví và tài khoản khác nhau.',
                'Manage money across wallets and accounts.')),
        ('savings', 'gold', tr('Tiết kiệm', 'Savings'),
            tr('Chuyển tiền vào ví tiết kiệm riêng và theo dõi mục tiêu.',
                'Move money into a savings wallet and track your goals.')),
        ('budget', 'orange', tr('Ngân sách', 'Budgets'),
            tr('Thiết lập giới hạn và kiểm soát chi tiêu.',
                'Set limits and keep spending under control.')),
      ];
  static String get aboutPrivacy => tr(
      'Không tài khoản, không Internet, không quảng cáo. Dữ liệu chỉ nằm '
          'trên điện thoại của bạn.',
      'No account, no Internet, no ads. Your data stays on your phone.');
  static String get aboutClosing => tr(
      'Quản lý tiền tốt hơn, bắt đầu từ những điều nhỏ nhất.',
      'Better money habits start with the smallest steps.');
  static String aboutCredit() => tr('Phiên bản $appVersion · Tạo bởi $author',
      'Version $appVersion · Made by $author');
}
