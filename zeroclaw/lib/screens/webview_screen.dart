import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../services/webview_service.dart';
import '../services/cookie_service.dart';
import '../services/news_provider.dart';
import '../models/news.dart';

class WebViewScreen extends StatefulWidget {
  final String url;
  final String? siteId;
  final bool isLoginMode;

  const WebViewScreen({
    super.key,
    required this.url,
    this.siteId,
    this.isLoginMode = false,
  });

  @override
  State<WebViewScreen> createState() => _WebViewScreenState();
}

class _WebViewScreenState extends State<WebViewScreen> {
  late WebViewController _controller;
  late WebViewService _webViewService;
  int _loadingProgress = 0;
  String _currentUrl = '';
  bool _isCollecting = false;

  @override
  void initState() {
    super.initState();
    final cookieService = CookieService();
    _webViewService = WebViewService(cookieService);
    _currentUrl = widget.url;
    _initController();
  }

  void _initController() {
    _controller = _webViewService.createController(
      onPageFinished: (url) async {
        setState(() => _currentUrl = url);
        await _webViewService.injectStealthScript(_controller);
        if (widget.isLoginMode && widget.siteId != null) {
          await _webViewService.saveSession(
            _controller,
            widget.siteId!,
            Uri.parse(url).host,
          );
        }
      },
      onProgress: (progress) {
        setState(() => _loadingProgress = progress);
      },
    );
    _controller.loadRequest(Uri.parse(widget.url));
  }

  Future<void> _collectNews() async {
    if (widget.siteId == null) return;
    setState(() => _isCollecting = true);

    try {
      List<NewsItem> items;
      switch (widget.siteId) {
        case 'ft':
          items = await _webViewService.extractFtNews(_controller);
        case 'reuters':
          items = await _webViewService.extractReutersNews(_controller);
        default:
          items = await _webViewService.extractGenericNews(
            _controller,
            widget.siteId!,
            widget.siteId!.toUpperCase(),
            Uri.parse(widget.url).origin,
          );
      }

      if (mounted) {
        final provider = context.read<NewsProvider>();
        await provider.addLocalNews(items);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('已采集 ${items.length} 条新闻')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('采集失败: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isCollecting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          Uri.tryParse(_currentUrl)?.host ?? _currentUrl,
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          if (widget.isLoginMode)
            TextButton.icon(
              icon: const Icon(Icons.check),
              label: const Text('保存登录'),
              onPressed: () {
                Navigator.pop(context, true);
              },
            )
          else if (widget.siteId != null)
            IconButton(
              icon: _isCollecting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.download),
              tooltip: '采集此页新闻',
              onPressed: _isCollecting ? null : _collectNews,
            ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => _controller.reload(),
          ),
        ],
        bottom: _loadingProgress < 100
            ? PreferredSize(
                preferredSize: const Size.fromHeight(2),
                child: LinearProgressIndicator(
                  value: _loadingProgress / 100,
                ),
              )
            : null,
      ),
      body: WebViewWidget(controller: _controller),
    );
  }
}
