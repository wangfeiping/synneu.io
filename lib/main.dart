import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:git2dart/git2dart.dart';
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
  // git2dart 在 Android 上需要提前初始化（解压捆绑的 CA 证书）
  if (Platform.isAndroid) {
    await PlatformSpecific.androidInitialize();
  }
  runApp(ProviderScope(observers: [_ErrorLogger()], child: const SynneuApp()));
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
