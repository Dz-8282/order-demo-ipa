# 推到 GitHub 并出 ipa

仓库目录：`C:\Users\Administrator\Desktop\zhuabaio`（项目本体是 `apple_order_layout_demo.html`）
这台机器目前**没装 git、也没装 gh**，所以下面两条路都不依赖它们——挑一条走完即可。

## 方法 A：网页上传（零安装，最稳）

1. 浏览器打开 https://github.com/new → 仓库名随便（如 `order-demo`）→ **Public** → Create
2. 在新仓库页面点 **uploading an existing file**
3. 把 `C:\Users\Administrator\Desktop\zhuabaio` 里的这些**文件夹和文件**拖进上传区（整目录拖，GitHub 会保留层级）：

   ```
   .github/          ← 必须，工作流在这里（含 workflows/build-ipa.yml）
   ipa/
   _tools/
   _verify/
   apple_order_layout_demo.html
   README.md
   .gitignore
   .gitattributes
   ```

   `order-detail.html`、`_f.png`、`_z.png`、`_probe.html`、`_render_check.html`、`_verify_430x932.png`、`.write_probe.txt` 不用传。
4. Commit changes
5. 顶部 **Actions** → 左侧 **Build IPA** → **Run workflow** → Run（约 1–2 分钟）
6. 跑完点进这次 run → 页面底部 **Artifacts** → 下载 `HTML-ipa`（得到 `HTML.ipa`，未签名）
7. 回到本机：打开 Sideloadly → 拖入 `HTML.ipa` → 填自己的 Apple ID → Start，插上 iPhone 即可装上

## 方法 B：命令行（装了 git 之后）

```powershell
winget install --id Git.Git -e --source winget

cd C:\Users\Administrator\Desktop\zhuabaio
git init -b main
git add .github ipa _tools _verify apple_order_layout_demo.html README.md .gitignore .gitattributes
git commit -m "订单详情演示页 + 离线打包工程"
git remote add origin https://github.com/<你的用户名>/<仓库名>.git
git push -u origin main
```

推送时弹出的窗口用浏览器登录一次你自己的 GitHub 账号完成授权，密码/令牌只在 GitHub 侧输入，不经过我。

已有 `gh` 的话可以更省事：

```powershell
gh auth login
gh repo create order-demo --public --source . --push
gh workflow run "Build IPA"
gh run watch
gh run download --name HTML-ipa
```

## 签名（第 7 步的说明）

Sideloadly 用你自己的免费 Apple ID 证书签名安装，7 天有效，到期重签续命；$99/年开发者账号则 1 年。
第三方共享签名（如「全能签」）出租的是别人名下的证书，掉签、被吊销、来源不明都是常见结局，不建议在这条链路上用。
