# 订单详情演示页 → 离线 iOS App

单文件 HTML 的苹果风订单详情页，带就地编辑、产品图上传、可点进度条；仓库里同时包含把它打成离线 `.ipa` 的工程。

## 页面本体

**`apple_order_layout_demo.html` 就是项目本体**（单文件，打开即用，纯本地、零依赖、无网络请求）。打包工程只做一件事：把这份文件原样复制成 `ipa/HTMLApp/index.html` 塞进 App bundle，页面代码本身不参与改动。

- 点击可改并自动记忆（localStorage，键前缀 `order-demo:`）：产品名、价格、送货地址 5 行、交货日期、订单号、付款方式
- 产品图：点产品框上传自己的图片（自动压到 512px + JPEG 后存本地），双击恢复默认 SVG
- 进度条：点「已收到付款 / 准备发货 / 已发货 / 已送达」四档，绿色进度推进到对应标签的最右端，选中状态同样记忆
- 响应式：600px / 601–860px / 861px+ 三档断点

## 打包成 ipa

```
ipa/
├── HTMLApp/                WKWebView 壳（AppDelegate / ViewController / Info.plist / index.html）
├── HTMLApp.xcodeproj/      iOS 13+，产物 HTML.app
├── build_ipa.sh            macOS：xcodebuild archive → build/HTML.ipa
├── sign_ipa.sh             给已有 ipa 重签（自有证书 / ad-hoc / 剥签名三档）
└── README.md               详细步骤与坑
```

没有 Mac 的话，推上 GitHub 后在 Actions 里点 **Build IPA**（[workflow](.github/workflows/build-ipa.yml)），用免费的 `macos-14` runner 出**未签名 ipa**，下载回 Windows 用 Sideloadly + 自己的 Apple ID 签名安装。签名请用自己的证书：第三方共享签名出租的是他人名下的证书，掉签与授权风险都归你。

## 自测脚本

`_tools/` 是 Playwright 写的验证脚本，用来证明页面行为而不是靠肉眼：

| 脚本 | 验证内容 |
| --- | --- |
| `layout_probe.py` | 三档视口的溢出、导航遮挡、图标绘制尺寸 |
| `edit_probe.py` | 10 个可编辑字段的点击编辑、独立存储、刷新持久化 |
| `upload_probe.py` | 产品图上传 → 压缩 → 存储 → 双击还原 |
| `progress_probe.py` | 四档进度与标签右缘的对齐误差、状态记忆 |

```bash
pip install playwright pillow && playwright install msedge
python _tools/edit_probe.py apple_order_layout_demo.html _verify
```

## 说明

`order-detail.html` 是早期另一版实现（modal sheet 风格），不参与打包、也不影响项目本体；直接删掉不影响任何功能。打包链路的唯一输入始终是 `apple_order_layout_demo.html`。
