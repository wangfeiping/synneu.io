import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../domain/tts_state.dart';
import 'tts_provider.dart';

/// AppBar 右上角朗读按钮。
/// [getText] 在用户点击播放时调用，返回要朗读的文本（标题 + 正文）。
class TtsButtonWidget extends ConsumerWidget {
  final String Function() getText;

  const TtsButtonWidget({super.key, required this.getText});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tts = ref.watch(ttsProvider);

    return switch (tts.status) {
      TtsStatus.idle => IconButton(
          icon: const Icon(Icons.volume_up_outlined),
          tooltip: '朗读（首次需下载模型）',
          onPressed: () => _showDownloadDialog(context, ref),
        ),
      TtsStatus.downloading => Tooltip(
          message: '正在下载语音模型…',
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                value: tts.downloadProgress > 0 ? tts.downloadProgress : null,
                strokeWidth: 2,
              ),
            ),
          ),
        ),
      TtsStatus.ready => IconButton(
          icon: const Icon(Icons.volume_up),
          tooltip: '朗读',
          onPressed: () => ref.read(ttsProvider.notifier).speak(getText()),
        ),
      TtsStatus.generating => Tooltip(
          message: '正在合成语音…',
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
        ),
      TtsStatus.speaking => IconButton(
          icon: const Icon(Icons.stop_circle_outlined),
          tooltip: '停止朗读',
          onPressed: () => ref.read(ttsProvider.notifier).stop(),
        ),
      TtsStatus.error => IconButton(
          icon: const Icon(Icons.volume_off_outlined),
          tooltip: tts.errorMessage ?? 'TTS 出错',
          color: Theme.of(context).colorScheme.error,
          onPressed: () => _showErrorDialog(context, ref, tts.errorMessage),
        ),
    };
  }

  void _showDownloadDialog(BuildContext context, WidgetRef ref) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('下载 TTS 语音模型'),
        content: const Text(
          '首次使用朗读功能需要下载约 70 MB 的中文神经网络语音合成模型（vits-zh-aishell3），下载后可完全离线使用。\n\n是否立即下载？',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              ref.read(ttsProvider.notifier).downloadAndInit();
            },
            child: const Text('下载'),
          ),
        ],
      ),
    );
  }

  void _showErrorDialog(
    BuildContext context,
    WidgetRef ref,
    String? message,
  ) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('TTS 错误'),
        content: Text(message ?? '未知错误'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('关闭'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              ref.read(ttsProvider.notifier).downloadAndInit();
            },
            child: const Text('重试'),
          ),
        ],
      ),
    );
  }
}
