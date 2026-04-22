enum TtsStatus { idle, downloading, ready, generating, speaking, error }

class TtsState {
  final TtsStatus status;
  final double downloadProgress;
  final String? errorMessage;

  const TtsState({
    this.status = TtsStatus.idle,
    this.downloadProgress = 0.0,
    this.errorMessage,
  });

  bool get modelReady =>
      status == TtsStatus.ready ||
      status == TtsStatus.generating ||
      status == TtsStatus.speaking;

  bool get isSpeaking => status == TtsStatus.speaking;
  bool get isGenerating => status == TtsStatus.generating;
  bool get isDownloading => status == TtsStatus.downloading;

  TtsState copyWith({
    TtsStatus? status,
    double? downloadProgress,
    String? errorMessage,
  }) =>
      TtsState(
        status: status ?? this.status,
        downloadProgress: downloadProgress ?? this.downloadProgress,
        errorMessage: errorMessage,
      );
}
