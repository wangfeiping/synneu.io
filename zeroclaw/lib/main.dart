import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'services/database_service.dart';
import 'services/zeroclaw_service.dart';
import 'services/news_provider.dart';
import 'screens/home_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final zeroclaw = ZeroClawService();
  await zeroclaw.loadConfig();

  runApp(
    MultiProvider(
      providers: [
        Provider<ZeroClawService>.value(value: zeroclaw),
        ChangeNotifierProvider(
          create: (_) => NewsProvider(
            DatabaseService.instance,
            zeroclaw,
          ),
        ),
      ],
      child: const ZeroClawApp(),
    ),
  );
}

class ZeroClawApp extends StatelessWidget {
  const ZeroClawApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ZeroClaw',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF1A1A2E),
          brightness: Brightness.light,
        ),
        useMaterial3: true,
        cardTheme: const CardThemeData(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(12)),
          ),
        ),
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF1A1A2E),
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
        cardTheme: const CardThemeData(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(12)),
          ),
        ),
      ),
      home: const HomeScreen(),
    );
  }
}
