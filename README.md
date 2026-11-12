# Tichi

Ứng dụng quản lý chi tiêu và tiết kiệm cá nhân cho Android, viết bằng Flutter. Hoạt động hoàn toàn offline: dữ liệu chỉ nằm trên điện thoại.

## Tính năng

- Nhiều ví (tiền mặt, ngân hàng, ví tiết kiệm), hai loại tiền VND và USD, quy đổi theo tỷ giá tự nhập.
- Ghi thu, chi, chuyển tiền giữa các ví; danh mục có biểu tượng và màu.
- Ngân sách tháng tổng và theo danh mục, cảnh báo khi gần chạm hoặc vượt.
- Mục tiêu tiết kiệm: một ví tiết kiệm phục vụ nhiều mục tiêu, gợi ý số tiền mỗi ngày, chuỗi ngày liên tiếp.
- Nhắc tiết kiệm hằng ngày, sao lưu mã hóa bằng mật khẩu, khôi phục, xuất CSV.
- Giao diện sáng, tối hoặc theo máy.

## Chạy dự án

```sh
sh tool/get_fonts.sh        # tải font Be Vietnam Pro (chạy một lần)
flutter pub get
flutter test
flutter run
```

Tạo bản phát hành: xem phần ký app trong `android/app/build.gradle.kts` (cần `android/key.properties`, không có trong git).

```sh
flutter build appbundle --release   # tệp .aab để đưa lên Google Play
```

## Quyền riêng tư

Xem [PRIVACY_POLICY.md](PRIVACY_POLICY.md).

## Giấy phép

Mã nguồn © 2026 Trung Nguyen. Font Be Vietnam Pro dùng giấy phép SIL Open Font License (`assets/fonts/OFL.txt`).
