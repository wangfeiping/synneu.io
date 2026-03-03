import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/news_provider.dart';
import '../widgets/site_tile.dart';
import 'webview_screen.dart';

class SitesScreen extends StatelessWidget {
  const SitesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<NewsProvider>(
      builder: (context, provider, _) {
        final p0 = provider.sites.where((s) => s.phase == 'p0').toList();
        final p1 = provider.sites.where((s) => s.phase == 'p1').toList();

        return Scaffold(
          appBar: AppBar(
            title: const Text('网站管理'),
          ),
          body: ListView(
            children: [
              _SectionHeader(
                title: '第一阶段（核心财经）',
                count: p0.length,
              ),
              ...p0.map(
                (site) => SiteTile(
                  site: site,
                  onToggle: (_) => provider.toggleSiteEnabled(site.id),
                  onLogin: () => _openLoginPage(context, provider, site.id,
                      site.loginUrl ?? site.baseUrl),
                  onCollect: () => provider.collectFromSite(site.id),
                ),
              ),
              _SectionHeader(
                title: '第二阶段（扩展媒体）',
                count: p1.length,
              ),
              ...p1.map(
                (site) => SiteTile(
                  site: site,
                  onToggle: (_) => provider.toggleSiteEnabled(site.id),
                  onLogin: () => _openLoginPage(context, provider, site.id,
                      site.loginUrl ?? site.baseUrl),
                  onCollect: () => provider.collectFromSite(site.id),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        );
      },
    );
  }

  Future<void> _openLoginPage(
    BuildContext context,
    NewsProvider provider,
    String siteId,
    String loginUrl,
  ) async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => WebViewScreen(
          url: loginUrl,
          siteId: siteId,
          isLoginMode: true,
        ),
      ),
    );
    if (result == true) {
      provider.updateSiteLoginStatus(siteId, true);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('登录信息已保存')),
        );
      }
    }
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final int count;

  const _SectionHeader({required this.title, required this.count});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Row(
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: Theme.of(context).colorScheme.primary,
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              '$count',
              style: TextStyle(
                fontSize: 11,
                color: Theme.of(context).colorScheme.onPrimaryContainer,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
