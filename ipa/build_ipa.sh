#!/bin/sh
# 把离线 HTML 打成 iOS 包（.ipa）。必须跑在 macOS + Xcode 上。
#
#   ./build_ipa.sh                     使用 ../apple_order_layout_demo.html
#   ./build_ipa.sh /path/to/page.html  使用指定 HTML
#
# 产物：ipa/build/HTML.ipa（未签名，需 Sideloadly / TrollStore / AltStore 等签名后安装）
#      或者把 DEVELOPMENT_TEAM 填上后走 Xcode 自动签名，直接出可安装的包。
set -eu

cd "$(dirname "$0")"

TEAM_ID="${TEAM_ID:-}"
BUNDLE_ID="${BUNDLE_ID:-com.example.htmlorderdemo}"
SCHEME="HTMLApp"
PROJECT="HTMLApp.xcodeproj"
SRC_HTML="${1:-../apple_order_layout_demo.html}"

if [ ! -f "$PROJECT/project.pbxproj" ]; then
  echo "找不到 $PROJECT/project.pbxproj" >&2
  exit 1
fi
if [ ! -f "$SRC_HTML" ]; then
  echo "找不到 HTML：$SRC_HTML" >&2
  exit 1
fi

cp "$SRC_HTML" HTMLApp/index.html
echo "已把 $SRC_HTML 打成 HTMLApp/index.html ($(wc -c < HTMLApp/index.html | tr -d ' ') 字节)"

rm -rf build
SIGN_ARGS="CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO CODE_SIGN_IDENTITY="
if [ -n "$TEAM_ID" ]; then
  SIGN_ARGS="DEVELOPMENT_TEAM=$TEAM_ID CODE_SIGN_STYLE=Automatic"
fi

xcodebuild \
  -project "$PROJECT" \
  -scheme "$SCHEME" \
  -configuration Release \
  -sdk iphoneos \
  -destination 'generic/platform=iOS' \
  -archivePath build/HTML.xcarchive \
  PRODUCT_BUNDLE_IDENTIFIER="$BUNDLE_ID" \
  $SIGN_ARGS \
  archive

APP="build/HTML.xcarchive/Products/Applications/HTML.app"
if [ ! -d "$APP" ]; then
  echo "打包失败：没有产出 $APP" >&2
  exit 1
fi

rm -rf build/Payload build/HTML.ipa
mkdir -p build/Payload
cp -R "$APP" build/Payload/
( cd build && zip -qry HTML.ipa Payload )

echo
echo "完成：$(cd build && pwd)/HTML.ipa ($(wc -c < build/HTML.ipa | tr -d ' ') 字节)"
echo "签名安装三选一："
echo "  1) Sideloadly / AltStore：把 ipa 拖进去，用你的 Apple ID 签名"
echo "  2) TrollStore（iOS 14-16）：直接装 ipa"
echo "  3) Xcode：TEAM_ID=你的TeamID ./build_ipa.sh 出正式签名包，再用 Xcode Devices 安装"
