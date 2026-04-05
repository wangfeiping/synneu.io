import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../domain/chat_session.dart';
import '../openclaw_provider.dart';

class ChatListPage extends ConsumerWidget {
  const ChatListPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessionsAsync = ref.watch(sessionListProvider);

    return sessionsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => _ErrorView(
        message: '加载失败：$e',
        onRetry: () => ref.invalidate(sessionListProvider),
      ),
      data: (sessions) => _SessionList(sessions: sessions),
    );
  }
}

class _SessionList extends ConsumerWidget {
  final List<ChatSession> sessions;
  const _SessionList({required this.sessions});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: sessions.isEmpty
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.chat_bubble_outline, size: 64, color: Colors.grey),
                  const SizedBox(height: 16),
                  const Text('暂无会话'),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: () => _createSession(context, ref),
                    icon: const Icon(Icons.add),
                    label: const Text('开始新会话'),
                  ),
                ],
              ),
            )
          : RefreshIndicator(
              onRefresh: () => ref.read(sessionListProvider.notifier).refresh(),
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(vertical: 8),
                itemCount: sessions.length,
                separatorBuilder: (_, __) => const Divider(height: 1, indent: 16),
                itemBuilder: (context, i) {
                  final s = sessions[i];
                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor:
                          Theme.of(context).colorScheme.primaryContainer,
                      child: Text(
                        s.displayTitle.isNotEmpty
                            ? s.displayTitle[0].toUpperCase()
                            : 'A',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onPrimaryContainer,
                        ),
                      ),
                    ),
                    title: Text(
                      s.displayTitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: s.lastMessage != null
                        ? Text(
                            s.lastMessage!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 12),
                          )
                        : null,
                    trailing: s.lastActivity != null
                        ? Text(
                            _formatTime(s.lastActivity!),
                            style: const TextStyle(
                                fontSize: 11, color: Colors.grey),
                          )
                        : null,
                    onTap: () => context.push('/openclaw/chat/${Uri.encodeComponent(s.key)}'),
                    onLongPress: () => _showMenu(context, ref, s),
                  );
                },
              ),
            ),
      floatingActionButton: sessions.isNotEmpty
          ? FloatingActionButton(
              onPressed: () => _createSession(context, ref),
              child: const Icon(Icons.add),
            )
          : null,
    );
  }

  Future<void> _createSession(BuildContext context, WidgetRef ref) async {
    try {
      final session =
          await ref.read(sessionListProvider.notifier).createSession();
      if (context.mounted) {
        context.push('/openclaw/chat/${Uri.encodeComponent(session.key)}');
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('创建会话失败：$e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showMenu(BuildContext context, WidgetRef ref, ChatSession session) {
    showModalBottomSheet(
      context: context,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.delete_outline, color: Colors.red),
              title: const Text('删除会话', style: TextStyle(color: Colors.red)),
              onTap: () {
                Navigator.pop(context);
                ref.read(sessionListProvider.notifier).deleteSession(session.key);
              },
            ),
          ],
        ),
      ),
    );
  }

  String _formatTime(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 60) return '${diff.inMinutes}分钟前';
    if (diff.inHours < 24) return '${diff.inHours}小时前';
    return '${diff.inDays}天前';
  }
}

class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorView({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(message),
            const SizedBox(height: 12),
            OutlinedButton(onPressed: onRetry, child: const Text('重试')),
          ],
        ),
      );
}
