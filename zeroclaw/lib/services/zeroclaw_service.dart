import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/news.dart';

/// ZeroClaw Agent 集成服务
/// 通过 HTTP 与本地 ZeroClaw daemon 通信
class ZeroClawService {
  static const _defaultHost = '127.0.0.1';
  static const _defaultPort = 3456;
  static const _prefKeyHost = 'zeroclaw_host';
  static const _prefKeyPort = 'zeroclaw_port';
  static const _prefKeyApiKey = 'zeroclaw_api_key';

  String _host = _defaultHost;
  int _port = _defaultPort;
  String? _apiKey;

  String get baseUrl => 'http://$_host:$_port';

  Future<void> loadConfig() async {
    final prefs = await SharedPreferences.getInstance();
    _host = prefs.getString(_prefKeyHost) ?? _defaultHost;
    _port = prefs.getInt(_prefKeyPort) ?? _defaultPort;
    _apiKey = prefs.getString(_prefKeyApiKey);
  }

  Future<void> saveConfig({
    required String host,
    required int port,
    String? apiKey,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefKeyHost, host);
    await prefs.setInt(_prefKeyPort, port);
    if (apiKey != null) {
      await prefs.setString(_prefKeyApiKey, apiKey);
    }
    _host = host;
    _port = port;
    _apiKey = apiKey;
  }

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        if (_apiKey != null) 'Authorization': 'Bearer $_apiKey',
      };

  /// 检查 ZeroClaw daemon 是否在线
  Future<bool> isOnline() async {
    try {
      final resp = await http
          .get(Uri.parse('$baseUrl/health'), headers: _headers)
          .timeout(const Duration(seconds: 3));
      return resp.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  /// 发送 Agent 指令采集新闻
  Future<List<NewsItem>> collectNews({
    required String siteId,
    String category = 'all',
    int limit = 20,
  }) async {
    try {
      final resp = await http
          .post(
            Uri.parse('$baseUrl/api/agent/run'),
            headers: _headers,
            body: jsonEncode({
              'tool': 'web_news_collect',
              'params': {
                'site': siteId,
                'category': category,
                'limit': limit,
              },
            }),
          )
          .timeout(const Duration(seconds: 60));

      if (resp.statusCode != 200) {
        throw Exception('ZeroClaw error: ${resp.statusCode}');
      }

      final data = jsonDecode(resp.body) as Map<String, dynamic>;
      final newsData = data['data']?['news'] as List<dynamic>? ?? [];
      return newsData
          .map((e) => NewsItem.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw Exception('Failed to collect news: $e');
    }
  }

  /// 发送对话消息
  Future<String> chat(String message) async {
    try {
      final resp = await http
          .post(
            Uri.parse('$baseUrl/api/chat'),
            headers: _headers,
            body: jsonEncode({'message': message}),
          )
          .timeout(const Duration(seconds: 30));

      if (resp.statusCode != 200) {
        throw Exception('ZeroClaw chat error: ${resp.statusCode}');
      }

      final data = jsonDecode(resp.body) as Map<String, dynamic>;
      return data['response'] as String? ?? '';
    } catch (e) {
      throw Exception('Chat failed: $e');
    }
  }

  /// 请求 AI 摘要
  Future<String> summarizeNews(List<NewsItem> news) async {
    final titles = news.take(10).map((n) => '- ${n.title}').join('\n');
    return chat('请对以下新闻进行简要摘要，突出重要信息：\n$titles');
  }
}
