# synneu.io 编译与测试快速指南

> 基于实际构建验证，环境：Flutter 3.35.3 / Dart 3.9.2 / Ubuntu 24.04

---

## 一、环境要求

| 工具 | 最低版本 | 验证命令 |
|------|----------|----------|
| Flutter | 3.35.x (stable) | `flutter --version` |
| Dart | 3.9.x | `dart --version` |
| Android SDK | 35.0.0 | `flutter doctor` |
| JDK | 17+ | `java -version` |
| Git | 2.x | `git --version` |

### 检查环境完整性

```bash
flutter doctor
```

期望输出（关键项必须为 ✓）：

```
[✓] Flutter (Channel stable, 3.35.3)
[✓] Android toolchain - develop for Android devices (Android SDK version 35.0.0)
[✓] Connected device (N available)
```

---

## 二、获取依赖

```bash
# 进入项目根目录
cd synneu.io

# 安装所有依赖
flutter pub get
```

> **注意**：国内网络可配置镜像加速：
> ```bash
> export FLUTTER_STORAGE_BASE_URL=https://storage.flutter-io.cn
> export PUB_HOSTED_URL=https://pub.flutter-io.cn
> ```

---

## 三、静态分析（analyze）

```bash
flutter analyze
```

**期望输出：**
```
Analyzing synneu.io...
No issues found! (ran in ~4s)
```

分析范围覆盖所有 `lib/` 下的 Dart 文件，包括：
- 类型安全检查
- 未使用的导入
- 废弃 API 调用
- Riverpod lint 规则

---

## 四、单元测试（test）

```bash
flutter test
```

**期望输出：**
```
00:16 +1: All tests passed!
```

测试文件位置：`test/widget_test.dart`

> 如需查看详细日志：
> ```bash
> flutter test --reporter expanded
> ```

---

##五、编译构建

### 5.1 Android APK（Debug）

```bash
flutter build apk --debug
```

**期望输出：**
```
✓ Built build/app/outputs/flutter-apk/app-debug.apk
```

产物路径：`build/app/outputs/flutter-apk/app-debug.apk`（约 139 MB）

---

### 5.2 Android APK（Release）

发布前需配置签名，参考 [Flutter 官方签名文档](https://docs.flutter.dev/deployment/android)。

```bash
# 生成签名密钥
keytool -genkey -v -keystore ~/synneu-release.jks \
  -keyalg RSA -keysize 2048 -validity 10000 \
  -alias synneu

# 构建 release APK
flutter build apk --release

# 或构建 AAB（推荐上架 Google Play）
flutter build appbundle --release
```

产物路径：
- APK：`build/app/outputs/flutter-apk/app-release.apk`
- AAB：`build/app/outputs/bundle/release/app-release.aab`

---

### 5.3 iOS（需 macOS + Xcode 15+）

```bash
# Debug 构建
flutter build ios --debug --no-codesign

# Release 构建（需要开发者证书）
flutter build ios --release
```

> 当前开发环境为 Linux，iOS 构建需在 macOS 上执行。

---

### 5.4 Web（辅助测试用）

```bash
flutter build web
```

产物路径：`build/web/`

---

## 六、运行调试

### 连接设备后直接运行

```bash
# 查看可用设备
flutter devices

# 运行到指定设备（android / chrome / linux）
flutter run -d android
flutter run -d chrome
```

### 热重载 / 热重启

运行后在终端输入：

| 键 | 操作 |
|----|------|
| `r` | 热重载（保留状态） |
| `R` | 热重启（重置状态） |
| `q` | 退出 |
| `d` | 断开设备 |

---

## 七、常见问题排查

### Q1：`flutter pub get` 超时或失败

设置国内镜像：
```bash
export FLUTTER_STORAGE_BASE_URL=https://storage.flutter-io.cn
export PUB_HOSTED_URL=https://pub.flutter-io.cn
flutter pub get
```

---

### Q2：Android 构建报 `record_linux` 接口不兼容

**症状：**
```
Error: The non-abstract class 'RecordLinux' is missing implementations
```

**原因：** `record` 包版本过低（< 6.0.0），`record_linux` 与平台接口不匹配。

**修复：** 确认 `pubspec.yaml` 中版本为 `^6.0.0`，然后：
```bash
flutter pub upgrade record
flutter pub get
```

---

### Q3：Gradle 构建超时

```bash
# 增加 Gradle 超时（单位：秒）
flutter build apk --debug --dart-define=FLUTTER_TOOL_TIMEOUT=600
```

或在 `android/gradle.properties` 中添加：
```properties
org.gradle.daemon=true
org.gradle.jvmargs=-Xmx4g
```

---

### Q4：Android SDK 找不到

```bash
flutter config --android-sdk /path/to/android-sdk
flutter doctor --android-licenses
```

---

### Q5：iOS 权限弹窗不出现

检查 `ios/Runner/Info.plist` 是否包含：
```xml
<key>NSMicrophoneUsageDescription</key>
<string>synneu.io 需要麦克风权限以支持语音输入笔记</string>
<key>NSSpeechRecognitionUsageDescription</key>
<string>synneu.io 需要语音识别权限将语音自动转换为文字</string>
```

---

## 八、本次验证结果（2026-03-04）

| 测试项 | 命令 | 结果 |
|--------|------|------|
| 静态分析 | `flutter analyze` | ✅ No issues found |
| 单元测试 | `flutter test` | ✅ 1/1 passed |
| Android Debug 构建 | `flutter build apk --debug` | ✅ app-debug.apk (139 MB) |

环境：Flutter 3.35.3 / Dart 3.9.2 / Android SDK 35.0.0 / Ubuntu 24.04.3 LTS

## 联机调试

### android

ADB 路径：/opt/tools/android-sdk/platform-tools/adb  
Android SDK：/opt/tools/android-sdk  
ANDROID_HOME：/opt/tools/android-sdk  
  
连上 Android 手机后直接执行 flutter run 即可，APK 会自动编译安装到设备上。  

```text                                                                                                                                                                                         
  Android 真机联调步骤                                                                                                                                                                        
                                                            
  1. 手机侧：开启开发者选项 + USB 调试                                                                                                                                                        
                                                                                                                                                                                            
  1. 进入 设置 → 关于手机，连续点击「版本号」7 次，解锁开发者选项                                                                                                                             
  2. 进入 设置 → 开发者选项，开启：                                                                                                                                                           
    - USB 调试                                                                                                                                                                                
    - USB 安装（部分机型）                                                                                                                                                                    
                                                                                                                                                                                              
  2. 用 USB 线连接电脑                                                                                                                                                                        

  # 确认设备识别
  adb devices

  期望输出（unauthorized 说明需在手机上点击"允许 USB 调试"弹窗）：
  List of devices attached
  R5CN10XXXXX    device

  3. 运行到真机

  # 确认 Flutter 也识别到设备
  flutter devices

  # 指定设备运行（有多设备时用 -d）
  flutter run

  # 或指定设备 ID
  flutter run -d <device-id>

  4. 无线调试（Android 11+，不用 USB）

  # 手机进入"开发者选项 → 无线调试"，记下 IP 和端口，例如 192.168.1.5:41337

  # 配对（第一次需要）
  adb pair 192.168.1.5:41337

  # 连接
  adb connect 192.168.1.5:37185

  # 确认
  adb devices
  flutter run
```

### ios

```text

  iOS 真机联调（需 macOS）

  当前开发环境是 Linux，iOS 真机调试必须在 macOS + Xcode 上执行，Linux 无法直接调试 iOS 设备。

  如果有 macOS 机器：

  # 连接 iPhone，信任电脑（手机弹窗点"信任"）
  flutter devices   # 会出现 iPhone 设备

  # 运行（首次需 Xcode 配置签名）
  flutter run -d <iphone-device-id>

  需要在 Xcode 中配置：Runner → Signing & Capabilities → Team 选择 Apple 账号（免费账号可真机调试，但应用 7 天有效期）。
```


