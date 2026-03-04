# synneu.io 项目记忆

## 项目概况
- Flutter 多模态笔记 App（Android + iOS）
- 集成 Git 版本管理 + AI Agent（ZeroClaw）
- Flutter 3.35.3 / Dart 3.9.2

## 关键文件
- `lib/main.dart` - 入口，ProviderScope + MaterialApp.router
- `lib/app/router.dart` - go_router 路由配置
- `lib/app/theme.dart` - Material3 主题（light/dark）
- `lib/features/note/` - 笔记功能（domain/data/presentation）
- `lib/features/project/` - Git 项目管理
- `lib/features/voice/` - 语音输入与转写
- `lib/shared/widgets/` - 公共组件

## 技术栈
- 状态管理：flutter_riverpod 2.6.1
- 路由：go_router
- 语音录制：record 5.x（使用实例方法 _recorder.hasPermission()，非静态）
- 语音识别：speech_to_text 7.x（使用 SpeechListenOptions 替代废弃参数）
- Git 操作：Process.run('git', ...) 系统调用
- 持久化：shared_preferences（项目列表）+ 本地文件（笔记 .md 文件）

## 开发计划
- 完整开发计划见 `docs/dev_plan_20260304.md`
- MVP 4 个阶段均已完成初版代码，flutter analyze 无错误

## 注意事项
- `record` 包 hasPermission 是实例方法，不是静态方法
- `speech_to_text` cancelOnError 需通过 SpeechListenOptions 传入
- StateProvider 初始值需写 `(ref) => null`，不能用 `_`
