# 把订单演示页打成 iOS .ipa

页面本体是单文件 HTML（内联 CSS + JS，无外链、无字体、无网络请求），所以离线包只要一层 WKWebView 壳即可——不需要任何第三方框架。

## 目录

```
ipa/
├── HTMLApp/
│   ├── AppDelegate.swift      窗口 + 允许旋转
│   ├── ViewController.swift   WKWebView 加载离线页；接管 <input type=file> → 拍照/相册/文件
│   ├── index.html             构建时由 ../apple_order_layout_demo.html 覆盖
│   └── Info.plist             相机/相册权限文案、横竖屏、允许本地加载
├── HTMLApp.xcodeproj/
│   └── project.pbxproj        iOS 13+，target=HTMLApp，产物 HTML.app
└── build_ipa.sh               一条命令归档 + 打 ipa
```

## 打包含义（在 macOS 上跑）

```bash
cd ipa
chmod +x build_ipa.sh
./build_ipa.sh                       # 用 ../apple_order_layout_demo.html
./build_ipa.sh ~/Desktop/other.html  # 或换别的 HTML
TEAM_ID=ABCDE12345 ./build_ipa.sh    # 有开发者账号时出签名包
```

产物 `ipa/build/HTML.ipa`。默认（未传 TEAM_ID）是**未签名包**，装到真机还需要一步签名：

- Sideloadly / AltStore：ipa 拖进去，用 Apple ID 签名后安装
- TrollStore（iOS 14–16）：可直接安装未签名 ipa
- 传了 `TEAM_ID` 则走 Xcode 自动签名，随 Xcode → Window → Devices 直接装

## 运行时行为（和浏览器里一致的几处，以及差异）

- 页面用 `loadFileURL(_:allowingReadAccessTo:)` 从 App bundle 加载，飞行模式下照常运行
- 所有编辑（产品名、价格、5 行地址、交货、订单号、付款）和上传的产品图都存在 App 沙箱的 localStorage，**卸载 App 才清空**；`order-demo:photo` / `order-demo:step` 这些键名与浏览器里完全一致
- 产品图上传走 `WKUIDelegate.runOpenPanelWith`，弹「拍照 / 相册 / 文件」三选一，选完的图仍会被页面里的 canvas 压到 512px + JPEG 后存本地
- 底部悬浮导航用 `scrollView.contentInsetAdjustmentBehavior = .never` 顶到屏幕边缘，配合页面里的 `viewport-fit=cover` 直接贴到 Home 指示条

## 需要改动时的两个可选微调

- 左上角想补回 iOS 状态栏（时间/信号/电量）：在 HTML 里加回 `.statusbar` 那块，或让 WKWebView 不覆盖状态栏
- 页面顶部想避开刘海/灵动岛：给 `.sheet` 加 `padding-top: env(safe-area-inset-top)`

## 更省事的两条路（不用 Mac 的话）

1. **PWA 直接装**：iPhone 用 Safari 打开这个 HTML（放到任意 https 静态托管或本机），分享 → 添加到主屏幕，就是全屏离线 App。缺点是顶栏靠 `apple-mobile-web-app-capable` 控制，图标要另给
2. **Capacitor**：任何平台都能初始化工程，把 HTML 放进 `web/`，`npx cap add ios` 生成 Xcode 工程，之后的构建同样必须回到 macOS

## 没有 Mac：用 GitHub Actions 出 ipa，再自己签名

1. 把本仓库推到 GitHub，打开 Actions → 「Build IPA」→ Run workflow（[.github/workflows/build-ipa.yml](../.github/workflows/build-ipa.yml)）
2. 跑完在该 run 的 Artifacts 下载 `HTML-ipa`：这是**未签名 ipa**，免费、合规，不用买开发者账号
3. 回到 Windows，用 **Sideloadly**（或 AltStore）把 ipa 拖进去，填自己的 Apple ID → 它会用免费开发者证书签名并装到 iPhone（需要电脑与手机同网段/数据线，7 天有效期，重签即可续）
4. 有付费开发者账号（$99/年）时，把 `ipa/sign_ipa.sh` 的 `MODE=p12` 配上证书和描述文件，签出来的包可走 Apple Configurator / Xcode 安装，有效期 1 年

关于「全能签」这类第三方签名服务：它们出租的是别人（多为企业开发者）名下的证书，被 Apple 吊销、证书被撤回、安装后掉签都是常见结局，来源和授权也不透明。同一个人力成本下，上面第 3 步的 Sideloadly + 自己的 Apple ID 更稳，也不涉及他人证书。
