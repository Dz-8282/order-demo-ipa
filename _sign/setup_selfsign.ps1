# 自签安装工具链（Windows + iPhone + 自己的 Apple ID）
#
#   powershell -ExecutionPolicy Bypass -File setup_selfsign.ps1
#
# 只装三个官方/开源工具，不涉及任何第三方共享证书：
#   1. Apple 移动设备支持（iPhone 能被电脑识别）
#   2. Sideloadly（用你自己的 Apple ID 签名并安装 ipa）
#   3. 顺带检查 Node（可选，用来做 PWA 兜底方案）
$ErrorActionPreference = 'Continue'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

function Say($msg) { Write-Host "==> $msg" -ForegroundColor Cyan }
function Ok($msg)  { Write-Host "   [ok] $msg" -ForegroundColor Green }
function Warn($m)  { Write-Host "   [!]  $m" -ForegroundColor Yellow }

$work = Join-Path $env:USERPROFILE 'Desktop\zhuabaio\_sign'
New-Item -ItemType Directory -Force -Path $work | Out-Null

Say '1/4 检查 iPhone 连接组件（Apple 移动设备支持 / iTunes）'
$applePaths = @(
  "$env:ProgramFiles\Common Files\Apple\Mobile Device Support",
  "${env:ProgramFiles(x86)}\Common Files\Apple\Mobile Device Support",
  "$env:ProgramFiles\WindowsApps"
)
$found = $applePaths | Where-Object { Test-Path $_ }
if ($found) {
  Ok ("已存在: " + ($found -join ' ; '))
  $svc = Get-Service -Name 'Apple Mobile Device Service' -ErrorAction SilentlyContinue
  if ($svc) { Ok "Apple Mobile Device Service 状态: $($svc.Status)" } else { Warn '服务未注册，插上 iPhone 后若识别不到可重装 Apple 设备支持' }
} else {
  Warn '未检测到 Apple 移动设备支持，Sideloadly 装包时会提示缺失'
  Say '    安装命令（需要管理员）：winget install --id Apple.AppleMobileDeviceSupport -e'
}

Say '2/4 下载 Sideloadly'
$target = Join-Path $env:USERPROFILE 'Downloads\SideloadlySetup.exe'
$urls = @(
  'https://sideloadly.io/SideloadlySetup64.exe',
  'https://sideloadly.io/SideloadlySetup.exe'
)
$done = $false
foreach ($u in $urls) {
  try {
    Say "    尝试 $u"
    Invoke-WebRequest -Uri $u -OutFile $target -TimeoutSec 60 -UseBasicParsing
    if ((Get-Item $target).Length -gt 1MB) { $done = $true; Ok "已下载 -> $target（$([math]::Round((Get-Item $target).Length/1MB,1)) MB）"; break }
    Warn '文件过小，可能不是安装包'
  } catch {
    Warn "下载失败: $($_.Exception.Message)"
  }
}
if (-not $done) {
  Warn '自动下载失败，请手动打开 https://sideloadly.io 下载 Windows 版'
}

Say '3/4 可选检查'
foreach ($tool in 'node', 'python', 'git') {
  $c = Get-Command $tool -ErrorAction SilentlyContinue
  if ($c) { Ok "$tool : $($c.Source)" } else { Warn "$tool 未安装" }
}

Say '4/4 下一步'
@"
签名安装只有三步，证书是你自己的 Apple ID：

  1) 先拿到未签名 ipa（约 2 分钟，免费）：
     - 仓库推到 GitHub（见 PUSH.md）
     - Actions -> Build IPA -> Run workflow
     - 跑完在 Artifacts 下载 HTML-ipa，得到 HTML.ipa

  2) 打开 Sideloadly（安装包在 Downloads 或 https://sideloadly.io）：
     - 插上 iPhone，等它识别（首次需在手机上点“信任此电脑”）
     - 把 HTML.ipa 拖进 Sideloadly 窗口
     - Apple ID 填你自己的邮箱，Start
     - 弹窗输入 Apple ID 密码（只经过 Apple 服务器，本地只用于生成签名请求）
     - 手机上：设置 -> 通用 -> VPN与设备管理 -> 信任你的开发者证书

  3) 有效期 7 天，到期重签同一 ipa 即可；想省事可在 Apple ID 里开双重验证并在 Sideloadly 里存 app-specific 密码

日志与下载目录：$work
"@ | Write-Host
