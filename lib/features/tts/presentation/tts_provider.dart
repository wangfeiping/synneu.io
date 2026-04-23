import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/tts_repository.dart';
import '../domain/tts_state.dart';

final ttsRepositoryProvider = Provider<TtsRepository>((ref) {
  final repo = TtsRepository();
  ref.onDispose(repo.dispose);
  return repo;
});

class TtsNotifier extends Notifier<TtsState> {
  @override
  TtsState build() {
    _checkModelReady();
    return const TtsState();
  }

  Future<void> _checkModelReady() async {
    final repo = ref.read(ttsRepositoryProvider);
    if (!await repo.isModelDownloaded()) return;
    try {
      await repo.initTts();
      state = state.copyWith(status: TtsStatus.ready);
    } catch (e) {
      state = TtsState(
        status: TtsStatus.error,
        errorMessage: '模型初始化失败: $e',
      );
    }
  }

  Future<void> downloadAndInit() async {
    final repo = ref.read(ttsRepositoryProvider);
    // 重置旧的 TTS 实例，以便全新初始化
    repo.reset();
    state = const TtsState(status: TtsStatus.downloading);
    try {
      await repo.downloadModel(
        onProgress: (p) => state = state.copyWith(downloadProgress: p),
      );
      await repo.initTts();
      state = const TtsState(status: TtsStatus.ready);
    } catch (e) {
      state = TtsState(
        status: TtsStatus.error,
        errorMessage: '下载或初始化失败: $e',
      );
    }
  }

  Future<bool> hasCachedAudio(String text) =>
      ref.read(ttsRepositoryProvider).hasCachedAudio(text);

  Future<void> speak(String text, {bool forceRegenerate = false}) async {
    if (!state.modelReady) return;
    state = state.copyWith(status: TtsStatus.generating);

    await ref.read(ttsRepositoryProvider).speak(
      text,
      forceRegenerate: forceRegenerate,
      onComplete: () {
        if (state.isSpeaking) {
          state = state.copyWith(status: TtsStatus.ready);
        }
      },
      onError: (e) {
        state = TtsState(status: TtsStatus.error, errorMessage: e);
      },
    );

    if (state.isGenerating) {
      state = state.copyWith(status: TtsStatus.speaking);
    }
  }

  Future<void> stop() async {
    await ref.read(ttsRepositoryProvider).stop();
    if (state.isSpeaking || state.isGenerating) {
      state = state.copyWith(status: TtsStatus.ready);
    }
  }
}

final ttsProvider = NotifierProvider<TtsNotifier, TtsState>(TtsNotifier.new);
