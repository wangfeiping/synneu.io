import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../domain/voice_record.dart';
import 'voice_provider.dart';

class VoiceInputWidget extends ConsumerWidget {
  final void Function(String text) onTextReady;

  const VoiceInputWidget({super.key, required this.onTextReady});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final voice = ref.watch(voiceProvider);
    final isRecording = voice.status == VoiceRecordStatus.recording;

    ref.listen(voiceProvider, (prev, next) {
      if (next.status == VoiceRecordStatus.done &&
          (next.finalText?.isNotEmpty ?? false)) {
        onTextReady(next.finalText!);
        ref.read(voiceProvider.notifier).reset();
      }
      if (next.status == VoiceRecordStatus.error &&
          next.errorMessage != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(next.errorMessage!)),
        );
        ref.read(voiceProvider.notifier).reset();
      }
    });

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        border: Border(
          top: BorderSide(color: Theme.of(context).dividerColor),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: isRecording
                ? _LiveText(text: voice.liveText)
                : Text(
                    '按住麦克风录音，松开自动转文字',
                    style: TextStyle(
                      color: Theme.of(context).hintColor,
                      fontSize: 13,
                    ),
                  ),
          ),
          const SizedBox(width: 12),
          GestureDetector(
            onLongPressStart: (_) async {
              await ref.read(voiceProvider.notifier).startListening();
            },
            onLongPressEnd: (_) async {
              await ref.read(voiceProvider.notifier).stopListening();
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isRecording
                    ? Colors.red
                    : Theme.of(context).colorScheme.primary,
              ),
              child: Icon(
                isRecording ? Icons.stop : Icons.mic,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LiveText extends StatelessWidget {
  final String text;
  const _LiveText({required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const _PulsingDot(),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text.isEmpty ? '正在聆听...' : text,
            style: TextStyle(
              color: text.isEmpty
                  ? Theme.of(context).hintColor
                  : Theme.of(context).textTheme.bodyMedium?.color,
              fontSize: 13,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

class _PulsingDot extends StatefulWidget {
  const _PulsingDot();

  @override
  State<_PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<_PulsingDot>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _ctrl,
      child: Container(
        width: 8,
        height: 8,
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.red,
        ),
      ),
    );
  }
}
