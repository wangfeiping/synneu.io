import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/news_provider.dart';
import '../widgets/news_card.dart';
import 'webview_screen.dart';

class NewsScreen extends StatelessWidget {
  const NewsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<NewsProvider>(
      builder: (context, provider, _) {
        return Scaffold(
          appBar: AppBar(
            title: const Text('ZeroClaw 新闻'),
            actions: [
              // ZeroClaw 在线状态指示
              Padding(
                padding: const EdgeInsets.only(right: 4),
                child: Icon(
                  Icons.circle,
                  size: 10,
                  color: provider.zeroclawOnline
                      ? Colors.green
                      : Colors.grey,
                ),
              ),
              IconButton(
                icon: provider.status == CollectStatus.collecting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.refresh),
                onPressed: provider.status == CollectStatus.collecting
                    ? null
                    : () => provider.collectAll(),
                tooltip: '采集全部',
              ),
            ],
          ),
          body: Column(
            children: [
              // 网站过滤器
              _SiteFilterBar(provider: provider),
              // 错误提示
              if (provider.error != null)
                Container(
                  width: double.infinity,
                  color: Theme.of(context).colorScheme.errorContainer,
                  padding: const EdgeInsets.all(8),
                  child: Text(
                    provider.error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onErrorContainer,
                      fontSize: 12,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              // 新闻列表
              Expanded(
                child: provider.filteredNews.isEmpty
                    ? _EmptyState(provider: provider)
                    : RefreshIndicator(
                        onRefresh: provider.refresh,
                        child: ListView.builder(
                          padding: const EdgeInsets.only(top: 4, bottom: 16),
                          itemCount: provider.filteredNews.length,
                          itemBuilder: (context, index) {
                            final news = provider.filteredNews[index];
                            return NewsCard(
                              news: news,
                              onTap: () {
                                provider.markAsRead(news.id);
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        WebViewScreen(url: news.url),
                                  ),
                                );
                              },
                            );
                          },
                        ),
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _SiteFilterBar extends StatelessWidget {
  final NewsProvider provider;

  const _SiteFilterBar({required this.provider});

  @override
  Widget build(BuildContext context) {
    final sites = provider.enabledSites;
    if (sites.isEmpty) return const SizedBox.shrink();

    return SizedBox(
      height: 40,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        itemCount: sites.length + 1,
        itemBuilder: (context, index) {
          if (index == 0) {
            return Padding(
              padding: const EdgeInsets.only(right: 6),
              child: FilterChip(
                label: const Text('全部'),
                selected: provider.selectedSiteId == null,
                onSelected: (_) => provider.selectSite(null),
              ),
            );
          }
          final site = sites[index - 1];
          return Padding(
            padding: const EdgeInsets.only(right: 6),
            child: FilterChip(
              label: Text(site.name.length > 8
                  ? site.id.toUpperCase()
                  : site.name),
              selected: provider.selectedSiteId == site.id,
              onSelected: (_) => provider.selectSite(
                provider.selectedSiteId == site.id ? null : site.id,
              ),
            ),
          );
        },
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final NewsProvider provider;

  const _EmptyState({required this.provider});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.newspaper_outlined,
            size: 64,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          const SizedBox(height: 16),
          Text(
            '暂无新闻',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Text(
            provider.zeroclawOnline
                ? '点击右上角刷新按钮开始采集'
                : 'ZeroClaw 未连接，请在设置中配置',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          if (provider.zeroclawOnline)
            FilledButton.icon(
              icon: const Icon(Icons.download),
              label: const Text('立即采集'),
              onPressed: () => provider.collectAll(),
            ),
        ],
      ),
    );
  }
}
