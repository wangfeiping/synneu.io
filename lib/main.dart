import 'dart:ffi';
import 'dart:io';
import 'package:ffi/ffi.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:git2dart/git2dart.dart';
import 'package:path_provider/path_provider.dart';
import 'app/router.dart';
import 'app/theme.dart';

class _ErrorLogger extends ProviderObserver {
  @override
  void didUpdateProvider(
    ProviderBase<Object?> provider,
    Object? previousValue,
    Object? newValue,
    ProviderContainer container,
  ) {
    if (newValue is AsyncError) {
      debugPrint('[Provider] ${provider.name ?? provider.runtimeType}: '
          '${newValue.error}\n${newValue.stackTrace}');
    }
  }
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (Platform.isAndroid) {
    // libgit2 在 Android 上创建临时 pack 文件时依赖 HOME 环境变量。
    // Android 进程默认 HOME 为 "/" (只读根目录)，导致 fetch/push 报
    // "failed to create temporary file '/pack_git2_...': Read-only file system"。
    // 必须在 PlatformSpecific.androidInitialize()（即 git_libgit2_init）之前设置，
    // 因为 libgit2 在首次初始化时读取 HOME。
    final appDir = await getApplicationDocumentsDirectory();
    _setenv('HOME', appDir.path);
    await PlatformSpecific.androidInitialize();
  }
  runApp(ProviderScope(observers: [_ErrorLogger()], child: const SynneuApp()));
}

/// 通过 FFI 调用 POSIX setenv() 设置进程环境变量。
/// Dart 的 Platform.environment 只读，必须走原生调用。
void _setenv(String key, String value) {
  final setenvFn = DynamicLibrary.process().lookupFunction<
      Int32 Function(Pointer<Char>, Pointer<Char>, Int32),
      int Function(Pointer<Char>, Pointer<Char>, int)>('setenv');
  using((arena) {
    setenvFn(
      key.toNativeUtf8(allocator: arena).cast<Char>(),
      value.toNativeUtf8(allocator: arena).cast<Char>(),
      1, // overwrite=1
    );
  });
}

class SynneuApp extends StatelessWidget {
  const SynneuApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Synneu',
      theme: lightTheme,
      darkTheme: darkTheme,
      themeMode: ThemeMode.system,
      routerConfig: router,
      debugShowCheckedModeBanner: false,
    );
  }
}
