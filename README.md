# synneu.io

集成git 和ai agent(ZeroClaw)的多模态笔记应用。支持andriod和ios。

## 基本功能需求

```text
1. 使用flutter 技术支持android和ios；
2. 能够选择创建还是更新；
   然后通过文本输入或语音输入：
   如果是文本输入直接保存或更新到文件；
   如果是语音先保存为语音文件，然后自动识别为文字并保存或更新到文本文件中；
3. 通过集成的git 配置和管理(同步，更新，选择，创建等)项目；
   可选择文件放入哪个项目并进行版本管理。
```

## 项目简介

### 基础实现

一 Flutter 工程初始化 + 依赖配置 + 目录结构  

二 文本笔记 CRUD（列表页 + 编辑页 + 文件读写）  

三 Git 项目管理（创建/选择/commit/push/pull/remote）  

四 语音输入 + 实时转写 + 写入笔记  

### 代码结构

18 个 Dart 源文件

```test
  lib/
  ├── main.dart                              # 入口（ProviderScope）
  ├── app/router.dart                        # go_router 路由
  ├── app/theme.dart                         # Material3 主题
  ├── features/
  │   ├── note/
  │   │   ├── domain/note.dart               # 笔记模型
  │   │   ├── data/note_repository.dart      # 文件系统读写
  │   │   └── presentation/
  │   │       ├── note_list_page.dart        # 笔记列表页
  │   │       ├── note_edit_page.dart        # 笔记编辑页（含语音栏）
  │   │       └── note_provider.dart         # Riverpod 状态
  │   ├── project/
  │   │   ├── domain/project.dart            # 项目模型
  │   │   ├── data/project_repository.dart   # Git 操作封装
  │   │   └── presentation/
  │   │       ├── project_list_page.dart     # 项目列表页
  │   │       ├── project_detail_page.dart   # Git 操作面板
  │   │       └── project_provider.dart      # Riverpod 状态
  │   └── voice/
  │       ├── domain/voice_record.dart       # 语音状态模型
  │       ├── data/voice_repository.dart     # 录音 + 语音识别
  │       └── presentation/
  │           ├── voice_input_widget.dart    # 录音 UI 组件
  │           └── voice_provider.dart        # Riverpod 状态
  └── shared/widgets/loading_widget.dart     # 通用加载/错误组件
```

### 关键能力

  - 文本笔记：创建/编辑/删除，存储为 .md 文件  
  - Git 管理：git init / add / commit / push / pull / remote，配置用户名邮箱  
  - 语音输入：长按录音 → 实时转写 → 自动追加到笔记内容  
  - 权限：Android（麦克风/存储/网络）、iOS（NSMicrophoneUsageDescription 等）均已配置  

