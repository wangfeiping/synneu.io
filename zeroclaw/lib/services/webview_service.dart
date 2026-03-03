import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'cookie_service.dart';
import '../models/news.dart';
import '../models/site.dart';

/// 桌面 Chrome User-Agent（用于伪装）
const _desktopUserAgent =
    'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 '
    '(KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36';

/// WebView 控制服务
/// 负责创建/管理 WebViewController，执行 JS 注入，同步 Cookie
class WebViewService {
  final CookieService _cookieService;

  WebViewService(this._cookieService);

  /// 创建并配置 WebViewController
  WebViewController createController({
    ValueChanged<String>? onPageFinished,
    ValueChanged<int>? onProgress,
  }) {
    final controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setUserAgent(_desktopUserAgent)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (url) {
            onPageFinished?.call(url);
          },
          onProgress: (progress) {
            onProgress?.call(progress);
          },
        ),
      );

    // 注入反检测脚本
    controller.addJavaScriptChannel(
      'ZeroClawBridge',
      onMessageReceived: (message) {
        debugPrint('[ZeroClawBridge] ${message.message}');
      },
    );

    return controller;
  }

  /// 注入浏览器伪装脚本
  Future<void> injectStealthScript(WebViewController controller) async {
    const stealthScript = '''
      (function() {
        Object.defineProperty(navigator, 'webdriver', { get: () => false });
        Object.defineProperty(navigator, 'plugins', {
          get: () => [
            {name: "Chrome PDF Plugin"},
            {name: "Chrome PDF Viewer"},
            {name: "Native Client"}
          ]
        });
        if (!window.chrome) {
          window.chrome = { runtime: {} };
        }
      })();
    ''';
    await controller.runJavaScript(stealthScript);
  }

  /// 从 WebView 提取当前页面 Cookie（通过 JS）
  Future<List<CookieEntry>> extractCookies(
    WebViewController controller,
    String domain,
  ) async {
    final result = await controller.runJavaScriptReturningResult(
      'document.cookie',
    );
    final cookieStr = result.toString().replaceAll('"', '');
    final cookies = <CookieEntry>[];
    for (final part in cookieStr.split(';')) {
      final kv = part.trim().split('=');
      if (kv.length >= 2) {
        cookies.add(CookieEntry(
          name: kv[0].trim(),
          value: kv.sublist(1).join('=').trim(),
          domain: domain,
        ));
      }
    }
    return cookies;
  }

  /// 保存会话 Cookie
  Future<void> saveSession(
    WebViewController controller,
    String siteId,
    String domain,
  ) async {
    final cookies = await extractCookies(controller, domain);
    if (cookies.isNotEmpty) {
      await _cookieService.saveSession(siteId, cookies);
    }
  }

  /// 恢复会话 Cookie（通过 JS document.cookie）
  Future<void> restoreSession(
    WebViewController controller,
    String siteId,
  ) async {
    final session = await _cookieService.getSession(siteId);
    if (session == null) return;
    for (final cookie in session.cookies) {
      await controller.runJavaScript(
        'document.cookie = "${cookie.name}=${cookie.value}; path=${cookie.path}";',
      );
    }
  }

  /// 检查登录状态（FT）
  Future<bool> checkFtLogin(WebViewController controller) async {
    final result = await controller.runJavaScriptReturningResult('''
      (function() {
        return document.querySelector('.user-menu') !== null ||
               document.querySelector('[data-testid="my-account"]') !== null;
      })()
    ''');
    return result.toString() == 'true';
  }

  /// 检查登录状态（通用）
  Future<bool> checkLoginStatus(
    WebViewController controller,
    NewsSite site,
  ) async {
    switch (site.id) {
      case 'ft':
        return checkFtLogin(controller);
      case 'bloomberg':
        return _checkBloombergLogin(controller);
      case 'wsj':
        return _checkWsjLogin(controller);
      default:
        return _cookieService.isSessionValid(site.id);
    }
  }

  Future<bool> _checkBloombergLogin(WebViewController controller) async {
    final result = await controller.runJavaScriptReturningResult('''
      document.querySelector('[data-component="user-nav"]') !== null
    ''');
    return result.toString() == 'true';
  }

  Future<bool> _checkWsjLogin(WebViewController controller) async {
    final result = await controller.runJavaScriptReturningResult('''
      document.querySelector('.user-account-menu') !== null
    ''');
    return result.toString() == 'true';
  }

  /// 提取 FT 新闻列表
  Future<List<NewsItem>> extractFtNews(
    WebViewController controller,
  ) async {
    final result = await controller.runJavaScriptReturningResult('''
      (function() {
        var items = [];
        document.querySelectorAll('[data-testid="card-headline"]').forEach(function(el) {
          var link = el.closest('a');
          if (link) {
            items.push({
              title: el.innerText.trim(),
              url: link.href,
              summary: (link.querySelector('p') || {}).innerText || '',
              time: (document.querySelector('time') || {}).innerText || ''
            });
          }
        });
        return JSON.stringify(items);
      })()
    ''');

    final jsonStr = result.toString();
    if (jsonStr.isEmpty || jsonStr == 'null') return [];
    try {
      final list = jsonDecode(jsonStr) as List<dynamic>;
      return list.map((e) {
        final m = e as Map<String, dynamic>;
        return NewsItem(
          id: (m['url'] as String).hashCode.toString(),
          title: m['title'] as String? ?? '',
          url: m['url'] as String? ?? '',
          summary: m['summary'] as String? ?? '',
          siteId: 'ft',
          siteName: 'Financial Times',
        );
      }).toList();
    } catch (_) {
      return [];
    }
  }

  /// 提取 Reuters 新闻列表
  Future<List<NewsItem>> extractReutersNews(
    WebViewController controller,
  ) async {
    final result = await controller.runJavaScriptReturningResult('''
      (function() {
        var items = [];
        document.querySelectorAll('[class*="article-heading"]').forEach(function(el) {
          var link = el.closest('a') || el.querySelector('a');
          if (link) {
            items.push({
              title: el.innerText.trim(),
              url: link.href.startsWith('http') ? link.href : 'https://www.reuters.com' + link.getAttribute('href'),
              summary: ''
            });
          }
        });
        return JSON.stringify(items.slice(0, 20));
      })()
    ''');

    return _parseNewsJson(result.toString(), 'reuters', 'Reuters');
  }

  /// 提取通用新闻（fallback）
  Future<List<NewsItem>> extractGenericNews(
    WebViewController controller,
    String siteId,
    String siteName,
    String baseUrl,
  ) async {
    final result = await controller.runJavaScriptReturningResult('''
      (function() {
        var items = [];
        var headings = document.querySelectorAll('h2 a, h3 a, article a[href]');
        headings.forEach(function(el) {
          var href = el.href || el.getAttribute('href');
          if (href && el.innerText.trim().length > 10) {
            items.push({
              title: el.innerText.trim(),
              url: href.startsWith('http') ? href : '$baseUrl' + href,
              summary: ''
            });
          }
        });
        return JSON.stringify([...new Map(items.map(item => [item.url, item])).values()].slice(0, 20));
      })()
    ''');

    return _parseNewsJson(result.toString(), siteId, siteName);
  }

  List<NewsItem> _parseNewsJson(
    String jsonStr,
    String siteId,
    String siteName,
  ) {
    if (jsonStr.isEmpty || jsonStr == 'null') return [];
    try {
      final list = jsonDecode(jsonStr) as List<dynamic>;
      return list
          .map((e) {
            final m = e as Map<String, dynamic>;
            final url = m['url'] as String? ?? '';
            if (url.isEmpty) return null;
            return NewsItem(
              id: url.hashCode.toString(),
              title: m['title'] as String? ?? '',
              url: url,
              summary: m['summary'] as String? ?? '',
              siteId: siteId,
              siteName: siteName,
            );
          })
          .whereType<NewsItem>()
          .toList();
    } catch (_) {
      return [];
    }
  }
}
