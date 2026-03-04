import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/voice_repository.dart';
import '../domain/voice_record.dart';

final voiceRepositoryProvider = Provider<VoiceRepository>(
  (ref) {
    final repo = VoiceRepository();
    ref.onDispose(repo.dispose);
    return repo;
  },
);

class VoiceState {
  final VoiceRecordStatus status;
  final String liveText;
  final String? finalText;
  final String? errorMessage;

  const VoiceState({
    this.status = VoiceRecordStatus.idle,
    this.liveText = '',
    this.finalText,
    this.errorMessage,
  });

  VoiceState copyWith({
    VoiceRecordStatus? status,
    String? liveText,
    String? finalText,
    String? errorMessage,
  }) {
    return VoiceState(
      status: status ?? this.status,
      liveText: liveText ?? this.liveText,
      finalText: finalText ?? this.finalText,
      errorMessage: errorMessage,
    );
  }
}

class VoiceNotifier extends Notifier<VoiceState> {
  @override
  VoiceState build() => const VoiceState();

  Future<bool> requestPermission() async {
    return ref.read(voiceRepositoryProvider).hasRecordPermission();
  }

  Future<void> startListening() async {
    final repo = ref.read(voiceRepositoryProvider);
    final hasPermission = await repo.hasRecordPermission();
    if (!hasPermission) {
      state = state.copyWith(
        status: VoiceRecordStatus.error,
        errorMessage: '麦克风权限未授权',
      );
      return;
    }

    state = state.copyWith(status: VoiceRecordStatus.recording, liveText: '');

    await repo.transcribeLive(
      onPartial: (text) {
        state = state.copyWith(liveText: text);
      },
      onFinal: (text) {
        state = state.copyWith(
          status: VoiceRecordStatus.done,
          liveText: text,
          finalText: text,
        );
      },
    );
  }

  Future<void> stopListening() async {
    await ref.read(voiceRepositoryProvider).stopListening();
    if (state.status == VoiceRecordStatus.recording) {
      state = state.copyWith(
        status: VoiceRecordStatus.done,
        finalText: state.liveText,
      );
    }
  }

  void reset() {
    state = const VoiceState();
  }
}

final voiceProvider = NotifierProvider<VoiceNotifier, VoiceState>(
  VoiceNotifier.new,
);
