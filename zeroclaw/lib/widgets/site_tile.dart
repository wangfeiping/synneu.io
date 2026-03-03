import 'package:flutter/material.dart';
import '../models/site.dart';

class SiteTile extends StatelessWidget {
  final NewsSite site;
  final VoidCallback? onLogin;
  final VoidCallback? onCollect;
  final ValueChanged<bool>? onToggle;

  const SiteTile({
    super.key,
    required this.site,
    this.onLogin,
    this.onCollect,
    this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: site.isLoggedIn
            ? theme.colorScheme.primaryContainer
            : theme.colorScheme.surfaceContainerHighest,
        child: Text(
          site.name.substring(0, 1).toUpperCase(),
          style: TextStyle(
            color: site.isLoggedIn
                ? theme.colorScheme.primary
                : theme.colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      title: Text(site.name),
      subtitle: Row(
        children: [
          _StatusBadge(
            label: site.isLoggedIn ? '已登录' : '未登录',
            color: site.isLoggedIn ? Colors.green : Colors.orange,
          ),
          const SizedBox(width: 8),
          _StatusBadge(
            label: 'P${site.phase.toUpperCase()}',
            color: Colors.blue,
          ),
        ],
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Switch(
            value: site.isEnabled,
            onChanged: onToggle,
          ),
          if (site.isEnabled) ...[
            IconButton(
              icon: const Icon(Icons.login, size: 20),
              tooltip: '登录',
              onPressed: onLogin,
            ),
            IconButton(
              icon: const Icon(Icons.download, size: 20),
              tooltip: '采集',
              onPressed: site.isLoggedIn ? onCollect : null,
            ),
          ],
        ],
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String label;
  final Color color;

  const _StatusBadge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
