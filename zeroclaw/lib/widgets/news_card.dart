import 'package:flutter/material.dart';
import '../models/news.dart';

class NewsCard extends StatelessWidget {
  final NewsItem news;
  final VoidCallback? onTap;
  final VoidCallback? onMarkRead;

  const NewsCard({
    super.key,
    required this.news,
    this.onTap,
    this.onMarkRead,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      elevation: news.isRead ? 0 : 1,
      color: news.isRead
          ? theme.colorScheme.surfaceContainerLowest
          : theme.colorScheme.surface,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _SiteChip(siteId: news.siteId, siteName: news.siteName),
                  const Spacer(),
                  if (news.formattedTime.isNotEmpty)
                    Text(
                      news.formattedTime,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                news.title,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight:
                      news.isRead ? FontWeight.normal : FontWeight.w600,
                  color: news.isRead
                      ? theme.colorScheme.onSurfaceVariant
                      : theme.colorScheme.onSurface,
                ),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
              if (news.summary.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  news.summary,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _SiteChip extends StatelessWidget {
  final String siteId;
  final String siteName;

  const _SiteChip({required this.siteId, required this.siteName});

  Color _color() {
    const palette = {
      'ft': Color(0xFFFF5F00),
      'reuters': Color(0xFFE86100),
      'bloomberg': Color(0xFF1A1A1A),
      'cnbc': Color(0xFF002B5B),
      'wsj': Color(0xFF111111),
      'bbc': Color(0xFFBB1919),
      'guardian': Color(0xFF005689),
      'caixin': Color(0xFFD0021B),
      'ftchinese': Color(0xFFFF5F00),
    };
    return palette[siteId] ?? const Color(0xFF607D8B);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: _color().withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        siteName.length > 12 ? siteId.toUpperCase() : siteName,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: _color(),
        ),
      ),
    );
  }
}
