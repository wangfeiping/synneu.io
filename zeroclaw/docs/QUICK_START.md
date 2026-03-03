# ZeroClaw 集成测试App 开发报告

基于 [ZeroClaw](https://github.com/zeroclaw-labs/zeroclaw) AI Agent 的 Flutter 移动端新闻采集应用。

## 项目结构

### 代码架构

```code
在 ./zeroclaw/ 中创建了完整的 Flutter App，15 个 Dart 文件，共约 2163 行，flutter analyze 零错误。                                                                                          

  zeroclaw/
  ├── lib/
  │   ├── main.dart                    # 应用入口（Provider 注入）
  │   ├── models/
  │   │   ├── news.dart                # NewsItem 数据模型
  │   │   └── site.dart                # NewsSite（含 9 个默认网站）
  │   ├── services/
  │   │   ├── database_service.dart    # SQLite 本地新闻缓存（sqflite）
  │   │   ├── cookie_service.dart      # Cookie 加密存储（Keychain/Keystore）
  │   │   ├── zeroclaw_service.dart    # ZeroClaw Daemon HTTP 客户端
  │   │   ├── webview_service.dart     # WebView 控制 + JS 注入 + 新闻提取
  │   │   └── news_provider.dart       # ChangeNotifier 全局状态管理
  │   ├── screens/
  │   │   ├── home_screen.dart         # 主界面（Material 3 底部导航）
  │   │   ├── news_screen.dart         # 新闻列表 + 过滤
  │   │   ├── webview_screen.dart      # 内嵌浏览器（登录/采集）
  │   │   ├── sites_screen.dart        # 网站管理（启用/禁用/登录）
  │   │   └── settings_screen.dart     # ZeroClaw 连接配置
  │   └── widgets/
  │       ├── news_card.dart           # 新闻卡片（带来源标签）
  │       └── site_tile.dart           # 网站列表项（带状态徽章）
  ├── android/app/src/main/
  │   └── AndroidManifest.xml          # 网络权限 + 后台任务权限
  ├── pubspec.yaml                     # 依赖：webview_flutter, flutter_secure_storage, sqflite, provider, http, workmanager
  └── README.md                        # 使用说明
```

### 关键实现

  ┌────────────────────────────────┬────────────────────────────────────────────────────────┐
  │            规范要求            │                        实现方式                        │
  ├────────────────────────────────┼────────────────────────────────────────────────────────┤
  │ 浏览器伪装 (FR-001)            │ 注入 stealth JS，设置 Desktop Chrome UA                │
  ├────────────────────────────────┼────────────────────────────────────────────────────────┤
  │ JS 执行 (FR-002)               │ WebViewController.runJavaScript*                       │
  ├────────────────────────────────┼────────────────────────────────────────────────────────┤
  │ Cookie 持久化 (FR-006, FR-010) │ flutter_secure_storage（AES-256/Keychain）             │
  ├────────────────────────────────┼────────────────────────────────────────────────────────┤
  │ 登录状态检测 (FR-007)          │ 各网站 JS selector 检测                                │
  ├────────────────────────────────┼────────────────────────────────────────────────────────┤
  │ 智能提取 (FR-011)              │ FT/Reuters/通用 JS 注入提取                            │
  ├────────────────────────────────┼────────────────────────────────────────────────────────┤
  │ ZeroClaw Agent 控制 (FR-016)   │ HTTP POST 到本地 daemon                                │
  ├────────────────────────────────┼────────────────────────────────────────────────────────┤
  │ 多网站支持 (FR-012)            │ FT/Reuters/Bloomberg/CNBC/WSJ/BBC/Guardian/财新/FT中文 │
  └────────────────────────────────┴────────────────────────────────────────────────────────┘

### 依赖

| 库 | 用途 |
|---|---|
| `webview_flutter` | WebView 内核 |
| `flutter_secure_storage` | Cookie 安全存储（Keychain/Keystore） |
| `sqflite` | 本地新闻缓存 |
| `provider` | 状态管理 |
| `http` | ZeroClaw HTTP 通信 |
| `workmanager` | 后台定时采集 |

## 编译测试                                                                                                                                                                      
                                                                                                                                                                                              
  1. 进入项目目录                                                                                                                                                                             
                                                                                                                                                                                              
  cd /opt/gopath/src/github.com/wangfeiping/synneu.io/zeroclaw                                                                                                                                
                                                                                                                                                                                              
  2. 检查环境                                                                                                                                                                                 
                                                                                                                                                                                              
  # 查看已连接设备                                                                                                                                                                            
  adb devices                                                                                                                                                                                 
                                                                                                                                                                                              
  # 查看 Flutter 识别的设备                                                                                                                                                                   
  flutter devices

  3. 调试模式直接运行（推荐测试用）

  # 直接安装并运行到已连接的 Android 设备
  flutter run --release

  4. 编译 APK 包

  # 编译 release APK（体积较小，性能最佳）
  flutter build apk --release

  # 或编译 split-abi APK（按 CPU 架构分包，更小）
  flutter build apk --release --split-per-abi

  APK 输出路径：
  build/app/outputs/flutter-apk/app-release.apk
  # split 模式：
  build/app/outputs/flutter-apk/app-arm64-v8a-release.apk   # 主流手机
  build/app/outputs/flutter-apk/app-armeabi-v7a-release.apk # 老机型

  5. 通过 adb 安装到手机

  # 安装 release APK
  adb install build/app/outputs/flutter-apk/app-release.apk

  # 如果之前装过旧版本，加 -r 覆盖安装
  adb install -r build/app/outputs/flutter-apk/app-release.apk

  # split 模式安装 arm64（推荐现代手机）
  adb install -r build/app/outputs/flutter-apk/app-arm64-v8a-release.apk

  6. 查看日志（排查问题）

  # 查看 Flutter/Dart 日志
  flutter logs

  # 或直接用 adb logcat 过滤
  adb logcat -s flutter


## 注意

手机需要提前开启"USB 调试"（开发者选项），并通过 USB 连接电脑，adb devices 显示设备序列号（非 unauthorized）才能正常安装。

## 功能

- **WebView 自动化**：内嵌浏览器，支持浏览器指纹伪装（Desktop Chrome UA）
- **登录持久化**：Cookie 加密存储（iOS Keychain / Android Keystore），一次登录长期有效
- **AI 驱动采集**：通过 ZeroClaw Agent 控制采集流程，智能提取新闻
- **多网站支持**：FT、Reuters、Bloomberg、CNBC、WSJ、BBC、Guardian、财新、FT中文

## 架构

```
Flutter App (UI)
    │ HTTP
ZeroClaw Daemon (Rust AI Agent)
    │ WebView
目标新闻网站
```

## 运行

### 1. 启动 ZeroClaw Daemon

```bash
# 安装 ZeroClaw
cargo install zeroclaw

# 启动 daemon（默认端口 3456）
zeroclaw service start
```

### 2. 运行 Flutter App

```bash
cd zeroclaw/
flutter pub get
flutter run
```

### 3. 配置连接

在 App **设置** 页面配置 ZeroClaw 地址（默认 `127.0.0.1:3456`），点击"测试连接"确认在线。

## 规格文档

详见 [`./zeroclaw_flutter_webview_spec_20260302_0153.md`](./zeroclaw_flutter_webview_spec_20260302_0153.md)


