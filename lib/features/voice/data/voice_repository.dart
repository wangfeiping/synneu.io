import 'dart:developer' as dev;
import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:uuid/uuid.dart';

class VoiceRepository {
  final _recorder = AudioRecorder();
  final _stt = SpeechToText();
  final _uuid = const Uuid();

  bool _sttInitialized = false;

  Future<String> get _voiceDir async {
    final appDir = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(appDir.path, 'synneu_voice'));
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir.path;
  }

  Future<bool> hasRecordPermission() => _recorder.hasPermission();

  Future<bool> initSpeechToText() async {
    if (_sttInitialized) return true;
    _sttInitialized = await _stt.initialize(
      onError: (error) {
        dev.log('STT 错误: $error', name: 'VoiceRepository', level: 900);
      },
      onStatus: (status) {
        dev.log('STT 状态: $status', name: 'VoiceRepository');
      },
    );
    return _sttInitialized;
  }

  Future<String> startRecording() async {
    final dir = await _voiceDir;
    final id = _uuid.v4();
    final filePath = p.join(dir, '$id.m4a');
    await _recorder.start(
      const RecordConfig(encoder: AudioEncoder.aacLc),
      path: filePath,
    );
    return filePath;
  }

  Future<String?> stopRecording() => _recorder.stop();

  Future<String> transcribeLive({
    required void Function(String partial) onPartial,
    required void Function(String final_) onFinal,
  }) async {
    if (!_sttInitialized) await initSpeechToText();
    if (!_sttInitialized) {
      throw Exception('语音识别初始化失败，请检查麦克风权限或设备是否支持语音识别');
    }

    final buffer = StringBuffer();

    await _stt.listen(
      onResult: (result) {
        if (result.finalResult) {
          buffer.write(result.recognizedWords);
          onFinal(buffer.toString());
        } else {
          onPartial(result.recognizedWords);
        }
      },
      listenFor: const Duration(seconds: 60),
      pauseFor: const Duration(seconds: 4),
      localeId: 'zh_CN',
      listenOptions: SpeechListenOptions(cancelOnError: false),
    );

    return buffer.toString();
  }

  Future<void> stopListening() => _stt.stop();

  void dispose() {
    _recorder.dispose();
  }
}
