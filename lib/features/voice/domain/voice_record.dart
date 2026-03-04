enum VoiceRecordStatus { idle, recording, processing, done, error }

class VoiceRecord {
  final String id;
  final String audioFilePath;
  final String? transcribedText;
  final VoiceRecordStatus status;
  final DateTime createdAt;

  const VoiceRecord({
    required this.id,
    required this.audioFilePath,
    this.transcribedText,
    required this.status,
    required this.createdAt,
  });

  VoiceRecord copyWith({
    String? transcribedText,
    VoiceRecordStatus? status,
  }) {
    return VoiceRecord(
      id: id,
      audioFilePath: audioFilePath,
      transcribedText: transcribedText ?? this.transcribedText,
      status: status ?? this.status,
      createdAt: createdAt,
    );
  }
}
