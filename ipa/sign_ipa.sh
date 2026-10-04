#!/bin/sh
# 用来给已打好的 .ipa 重新签名（macOS 上跑）。
# 这里只做标准 codesign 流程；第三方签名服务请自行核实其证书来源与授权范围。
#
#   SIDELOAD_P12=~/certs/dev.p12 P12_PASS=密码 ./sign_ipa.sh build/HTML.ipa
#   MODE=adhoc ./sign_ipa.sh build/HTML.ipa        # ad-hoc，仅越狱/TrollStore/本地调试
#   MODE=none  ./sign_ipa.sh build/HTML.ipa        # 剥掉旧签名，交给 Sideloadly 在 Windows 上签
set -eu

cd "$(dirname "$0")"

IPA="${1:-build/HTML.ipa}"
MODE="${MODE:-p12}"
KEYCHAIN="${KEYCHAIN:-signing.keychain-db}"
KEYCHAIN_PASS="${KEYCHAIN_PASS:-signpass}"
OUT="${OUT:-build/HTML-signed.ipa}"

[ -f "$IPA" ] || { echo "找不到 ipa：$IPA（先在 macOS 上跑 ./build_ipa.sh）" >&2; exit 1; }

WORK="build/sign-work"
rm -rf "$WORK" "$OUT"
mkdir -p "$WORK"
(cd "$WORK" && unzip -q "$(cd "$(dirname "$IPA")" && pwd)/$(basename "$IPA")")
APP="$(find "$WORK/Payload" -maxdepth 1 -name '*.app' | head -1)"
[ -n "$APP" ] || { echo "ipa 结构不对：缺 Payload/*.app" >&2; exit 1; }
echo "待签名 App：$APP"

ENTITLEMENTS="build/entitlements.plist"
cat > "$ENTITLEMENTS" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>application-identifier</key>
	<string>TEAMID.com.example.htmlorderdemo</string>
	<key>com.apple.developer.team-identifier</key>
	<string>TEAMID</string>
	<key>get-task-allow</key>
	<false/>
	<key>keychain-access-groups</key>
	<array>
		<string>TEAMID.com.example.htmlorderdemo</string>
	</array>
</dict>
</plist>
PLIST

case "$MODE" in
  p12)
    [ -n "${SIDELOAD_P12:-}" ] || { echo "MODE=p12 需要 SIDELOAD_P12=证书.p12" >&2; exit 1; }
    [ -n "${PROVISION:-}" ] || { echo "MODE=p12 需要 PROVISION=描述文件.mobileprovision" >&2; exit 1; }
    security delete-keychain "$KEYCHAIN" 2>/dev/null || true
    security create-keychain -p "$KEYCHAIN_PASS" "$KEYCHAIN"
    security set-keychain-settings -lut 21600 "$KEYCHAIN"
    security unlock-keychain -p "$KEYCHAIN_PASS" "$KEYCHAIN"
    security import "$SIDELOAD_P12" -k "$KEYCHAIN" -P "${P12_PASS:-}" -T /usr/bin/codesign
    security set-key-partition-list -S apple-tool:,apple: -k "$KEYCHAIN_PASS" "$KEYCHAIN" >/dev/null
    security list-keychains -d user -s "$KEYCHAIN" $(security list-keychains -d user | tr -d '"')
    cp "$PROVISION" "$APP/embedded.mobileprovision"
    cp "$PROVISION" "$ENTITLEMENTS.source"
    echo "▶ codesign（证书签名）"
    /usr/bin/codesign --force --timestamp=none --sign "Apple Development" \
      --keychain "$KEYCHAIN" --entitlements "$ENTITLEMENTS" --generate-entitlement-der "$APP"
    ;;
  adhoc)
    echo "▶ codesign（ad-hoc，无证书）"
    /usr/bin/codesign --force --deep --sign - "$APP"
    ;;
  none)
    echo "▶ 剥掉旧签名"
    /usr/bin/codesign --remove-signature "$APP" 2>/dev/null || true
    ;;
  *)
    echo "未知 MODE：$MODE（可选 p12 / adhoc / none）" >&2
    exit 1
    ;;
esac

(cd "$WORK" && zip -qry "$(pwd)/../../$OUT" Payload 2>/dev/null) || (cd "$WORK" && zip -qry "$OLDPWD/$OUT" Payload)
echo "完成：$OUT"
case "$MODE" in
  p12)   echo "用 Xcode → Window → Devices、Apple Configurator 或 ipa 安装器装到真机" ;;
  adhoc) echo "ad-hoc 签名只有越狱重签 / TrollStore 场景适用，普通真机请用 Sideloadly 以 Apple ID 签名" ;;
  none)  echo "现在用 Sideloadly（Windows 可用）拖入 $OUT，用你的 Apple ID 完成签名安装" ;;
esac
