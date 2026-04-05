import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/chat_session.dart';
import '../../data/gateway_ws_service.dart';
import '../openclaw_provider.dart';

class ChatDetailPage extends ConsumerStatefulWidget {
  final String sessionKey;
  const ChatDetailPage({super.key, required this.sessionKey});

  @override
  ConsumerState<ChatDetailPage> createState() => _ChatDetailPageState();
}

class _ChatDetailPageState extends ConsumerState<ChatDetailPage> {
  final _inputCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  final List<ChatMessage> _messages = [];
  StreamSubscription<GatewayEvent>? _eventSub;

  bool _loading = true;
  bool _sending = false;
  bool _streaming = false;

  // 流式累积的当前助手消息
  String _streamBuffer = '';

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final repo = ref.read(gatewayRepositoryProvider);

    // 订阅会话消息
    try {
      await repo.subscribeSession(widget.sessionKey);
    } catch (_) {}

    // 加载历史消息
    try {
      final history = await repo.getChatHistory(widget.sessionKey, 50);
      final messages = history.map(_parseMessage).whereType<ChatMessage>().toList();
      if (mounted) {
        setState(() {
          _messages.addAll(messages);
          _loading = false;
        });
        _scrollToBottom();
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }

    // 监听流式事件
    _eventSub = ref.read(gatewayWsServiceProvider).events.listen(_onEvent);
  }

  ChatMessage? _parseMessage(Map<String, dynamic> m) {
    final role = m['role'] as String?;
    final content = m['content'] as String? ?? '';
    if (role == null) return null;
    return ChatMessage(
      role: role,
      content: content,
      createdAt: m['createdAt'] != null
          ? DateTime.tryParse(m['createdAt'] as String) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  void _onEvent(GatewayEvent event) {
    final payload = event.payload;
    final payloadSessionKey = payload['sessionKey'] as String? ??
        payload['key'] as String?;

    if (payloadSessionKey != widget.sessionKey) return;

    setState(() {
      if (event.event == 'chat.delta' || event.event == 'session.delta') {
        final delta = payload['delta'] as String? ?? payload['text'] as String? ?? '';
        _streamBuffer += delta;
        _streaming = true;
        // 更新或添加流式消息气泡
        if (_messages.isNotEmpty && _messages.last.isStreaming) {
          _messages[_messages.length - 1] =
              _messages.last.copyWith(content: _streamBuffer);
        } else {
          _messages.add(ChatMessage(
            role: 'assistant',
            content: _streamBuffer,
            createdAt: DateTime.now(),
            isStreaming: true,
          ));
        }
      } else if (event.event == 'chat.done' ||
          event.event == 'session.done' ||
          event.event == 'chat.complete') {
        // 流结束，将最后一条消息标记为完成
        if (_messages.isNotEmpty && _messages.last.isStreaming) {
          _messages[_messages.length - 1] =
              _messages.last.copyWith(isStreaming: false);
        }
        _streamBuffer = '';
        _streaming = false;
        _sending = false;
      } else if (event.event == 'chat.error' || event.event == 'session.error') {
        _streaming = false;
        _sending = false;
        _streamBuffer = '';
        if (_messages.isNotEmpty && _messages.last.isStreaming) {
          _messages.removeLast();
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('错误：${payload['error'] ?? '未知错误'}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    });

    if (_streaming) _scrollToBottom();
  }

  Future<void> _send() async {
    final text = _inputCtrl.text.trim();
    if (text.isEmpty || _sending) return;

    setState(() {
      _sending = true;
      _streamBuffer = '';
      _messages.add(ChatMessage(
        role: 'user',
        content: text,
        createdAt: DateTime.now(),
      ));
      _inputCtrl.clear();
    });
    _scrollToBottom();

    try {
      await ref
          .read(gatewayRepositoryProvider)
          .sendMessage(widget.sessionKey, text);
    } catch (e) {
      if (mounted) {
        setState(() => _sending = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('发送失败：$e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _abort() async {
    try {
      await ref.read(gatewayRepositoryProvider).abortSession(widget.sessionKey);
    } catch (_) {}
    if (mounted) {
      setState(() {
        _sending = false;
        _streaming = false;
        if (_messages.isNotEmpty && _messages.last.isStreaming) {
          _messages[_messages.length - 1] =
              _messages.last.copyWith(isStreaming: false);
        }
      });
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  void dispose() {
    _eventSub?.cancel();
    _inputCtrl.dispose();
    _scrollCtrl.dispose();
    // 取消订阅（忽略错误）
    ref.read(gatewayRepositoryProvider).unsubscribeSession(widget.sessionKey).ignore();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.sessionKey.length > 20
              ? '${widget.sessionKey.substring(0, 20)}…'
              : widget.sessionKey,
          style: const TextStyle(fontSize: 14),
        ),
        actions: [
          if (_sending || _streaming)
            TextButton(onPressed: _abort, child: const Text('停止'))
          else
            PopupMenuButton<String>(
              onSelected: (v) async {
                if (v == 'reset') {
                  await ref
                      .read(gatewayRepositoryProvider)
                      .resetSession(widget.sessionKey);
                  if (mounted) setState(() => _messages.clear());
                }
              },
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'reset', child: Text('重置会话')),
              ],
            ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _messages.isEmpty
                    ? const Center(
                        child: Text('发送消息开始对话',
                            style: TextStyle(color: Colors.grey)))
                    : ListView.builder(
                        controller: _scrollCtrl,
                        padding: const EdgeInsets.all(12),
                        itemCount: _messages.length,
                        itemBuilder: (_, i) =>
                            _MessageBubble(message: _messages[i]),
                      ),
          ),
          _InputBar(
            controller: _inputCtrl,
            sending: _sending,
            onSend: _send,
          ),
        ],
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  final ChatMessage message;
  const _MessageBubble({required this.message});

  @override
  Widget build(BuildContext context) {
    final isUser = message.role == 'user';
    final scheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment:
            isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isUser) ...[
            CircleAvatar(
              radius: 14,
              backgroundColor: scheme.primaryContainer,
              child: Icon(Icons.smart_toy_outlined,
                  size: 16, color: scheme.onPrimaryContainer),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: GestureDetector(
              onLongPress: () {
                Clipboard.setData(ClipboardData(text: message.content));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('已复制'), duration: Duration(seconds: 1)),
                );
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: isUser
                      ? scheme.primary
                      : scheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: isUser
                    ? Text(
                        message.content,
                        style: TextStyle(color: scheme.onPrimary),
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          MarkdownBody(
                            data: message.content,
                            styleSheet: MarkdownStyleSheet.fromTheme(
                                Theme.of(context)),
                          ),
                          if (message.isStreaming) ...[
                            const SizedBox(height: 4),
                            const SizedBox(
                              width: 20,
                              height: 12,
                              child: LinearProgressIndicator(),
                            ),
                          ],
                        ],
                      ),
              ),
            ),
          ),
          if (isUser) const SizedBox(width: 36),
        ],
      ),
    );
  }
}

class _InputBar extends StatelessWidget {
  final TextEditingController controller;
  final bool sending;
  final VoidCallback onSend;
  const _InputBar(
      {required this.controller,
      required this.sending,
      required this.onSend});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(
          12, 8, 8, 8 + MediaQuery.of(context).padding.bottom),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        boxShadow: const [BoxShadow(blurRadius: 4, color: Colors.black12)],
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              minLines: 1,
              maxLines: 5,
              decoration: const InputDecoration(
                hintText: '输入消息…',
                border: OutlineInputBorder(),
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                isDense: true,
              ),
              textInputAction: TextInputAction.newline,
              onSubmitted: (_) => onSend(),
            ),
          ),
          const SizedBox(width: 8),
          IconButton.filled(
            onPressed: sending ? null : onSend,
            icon: sending
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.send),
          ),
        ],
      ),
    );
  }
}
