#!/bin/sh
# Tạo và cấu hình phần iOS cho Tichi. Chạy một lần trên Mac:
#   sh tool/setup_ios.sh
# Không cần Xcode: phần build iOS chạy trên Codemagic (xem codemagic.yaml).
set -e
cd "$(dirname "$0")/.."

if [ ! -d ios ]; then
  echo "→ Tạo thư mục ios (mã app com.trungnguyen.tichi)"
  flutter create --platforms=ios --org com.trungnguyen --project-name tichi .
fi

PLIST=ios/Runner/Info.plist
PB=/usr/libexec/PlistBuddy

echo "→ Tên hiển thị, ngôn ngữ, chỉ màn hình dọc"
$PB -c "Set :CFBundleDisplayName Tichi" "$PLIST" 2>/dev/null \
  || $PB -c "Add :CFBundleDisplayName string Tichi" "$PLIST"
$PB -c "Delete :CFBundleLocalizations" "$PLIST" 2>/dev/null || true
$PB -c "Add :CFBundleLocalizations array" "$PLIST"
$PB -c "Add :CFBundleLocalizations:0 string vi" "$PLIST"
$PB -c "Add :CFBundleLocalizations:1 string en" "$PLIST"
$PB -c "Delete :UISupportedInterfaceOrientations" "$PLIST" 2>/dev/null || true
$PB -c "Add :UISupportedInterfaceOrientations array" "$PLIST"
$PB -c "Add :UISupportedInterfaceOrientations:0 string UIInterfaceOrientationPortrait" "$PLIST"
$PB -c "Delete :UISupportedInterfaceOrientations~ipad" "$PLIST" 2>/dev/null || true

echo "→ Chỉ chạy trên iPhone, từ iOS 13"
PBX=ios/Runner.xcodeproj/project.pbxproj
sed -i '' 's/TARGETED_DEVICE_FAMILY = "1,2";/TARGETED_DEVICE_FAMILY = 1;/g' "$PBX"
sed -i '' -E 's/IPHONEOS_DEPLOYMENT_TARGET = (9|10|11|12)\.[0-9]+;/IPHONEOS_DEPLOYMENT_TARGET = 13.0;/g' "$PBX"
if [ -f ios/Podfile ]; then
  sed -i '' -E "s/^#? ?platform :ios, .*/platform :ios, '13.0'/" ios/Podfile
fi

echo "→ Cho thông báo nhắc hiện cả khi app đang mở"
APPDELEGATE=ios/Runner/AppDelegate.swift
if ! grep -q UNUserNotificationCenter "$APPDELEGATE"; then
  perl -0pi -e 's/import UIKit\n/import UIKit\nimport UserNotifications\n/' "$APPDELEGATE"
  perl -0pi -e 's/(didFinishLaunchingWithOptions[^{]*\{\n)/$1    UNUserNotificationCenter.current().delegate = self as? UNUserNotificationCenterDelegate\n/' "$APPDELEGATE"
fi

echo "→ Biểu tượng app iOS"
grep -q "flutter_launcher_icons:" pubspec.yaml || true
if ! grep -q "^  flutter_launcher_icons" pubspec.yaml; then
  flutter pub add --dev flutter_launcher_icons
fi
flutter pub get
dart run flutter_launcher_icons

echo ""
echo "Xong. Kiểm tra mã app:"
grep -m1 "PRODUCT_BUNDLE_IDENTIFIER = com.trungnguyen.tichi;" "$PBX" \
  && echo "OK: com.trungnguyen.tichi" \
  || echo "CẢNH BÁO: mã app không phải com.trungnguyen.tichi"
grep -c "UNUserNotificationCenter" "$APPDELEGATE" >/dev/null \
  && echo "OK: AppDelegate đã có phần thông báo" \
  || echo "LƯU Ý: chưa sửa được AppDelegate (không ảnh hưởng nhắc khi app đóng)"
