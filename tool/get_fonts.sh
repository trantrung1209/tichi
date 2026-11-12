#!/bin/sh
# Tải phông Be Vietnam Pro (giấy phép SIL OFL 1.1) từ kho Google Fonts
# về assets/fonts. Chỉ cần chạy một lần, trên máy có Internet.
set -e
cd "$(dirname "$0")/.."
mkdir -p assets/fonts
BASE="https://raw.githubusercontent.com/google/fonts/main/ofl/bevietnampro"
for f in BeVietnamPro-Regular.ttf BeVietnamPro-Medium.ttf BeVietnamPro-SemiBold.ttf BeVietnamPro-Bold.ttf OFL.txt; do
  echo "Đang tải $f"
  curl -fsSL "$BASE/$f" -o "assets/fonts/$f"
done
echo "Xong. Các file nằm trong assets/fonts:"
ls -l assets/fonts
