import 'dart:async';
import 'dart:developer' as dev;
import 'dart:io';
import 'dart:typed_data';
import 'package:archive/archive.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sherpa_onnx/sherpa_onnx.dart' as sherpa;

void _log(String msg, {bool warn = false}) {
  debugPrint('[TTS] $msg'); // 出现在 flutter run 终端
  dev.log(msg, name: 'TtsRepository', level: warn ? 900 : 0);
}

// ── 顶层函数：在 compute isolate 中执行 TTS 合成 ─────────────────────────────
Map<String, dynamic> _generateAudioInBackground(Map<String, String> args) {
  sherpa.initBindings();
  final config = sherpa.OfflineTtsConfig(
    model: sherpa.OfflineTtsModelConfig(
      vits: sherpa.OfflineTtsVitsModelConfig(
        model: args['modelPath']!,
        lexicon: args['lexiconPath']!,
        tokens: args['tokensPath']!,
      ),
      numThreads: 2,
      debug: false,
      provider: 'cpu',
    ),
    maxNumSenetences: 100,
  );
  final tts = sherpa.OfflineTts(config);
  final audio = tts.generate(text: args['text']!, sid: 0, speed: 1.0);
  final samples = Float32List.fromList(audio.samples); // 独立拷贝，free 后仍有效
  final sampleRate = audio.sampleRate;
  tts.free();
  return {'samples': samples, 'sampleRate': sampleRate};
}

// ── 顶层函数：在 compute isolate 中执行 BZip2 解压 + tar 解包 ──────────────
List<String> _extractTarBz2InBackground(Map<String, String> args) {
  final archivePath = args['archivePath']!;
  final outputDir = args['outputDir']!;

  final bytes = File(archivePath).readAsBytesSync();
  final tarBytes = BZip2Decoder().decodeBytes(bytes);
  final archive = TarDecoder().decodeBytes(tarBytes);

  final extracted = <String>[];
  for (final file in archive) {
    if (!file.isFile || file.size == 0) continue;
    final outPath = p.join(outputDir, file.name);
    Directory(p.dirname(outPath)).createSync(recursive: true);
    File(outPath).writeAsBytesSync(file.content as List<int>);
    extracted.add(file.name);
  }
  return extracted;
}

// ─────────────────────────────────────────────────────────────────────────────

class TtsRepository {
  static const _modelName = 'vits-zh-aishell3';
  static const _downloadUrl =
      'https://github.com/k2-fsa/sherpa-onnx/releases/download/'
      'tts-models/$_modelName.tar.bz2';

  // model.onnx 至少 10 MB，小于此值视为损坏
  static const _minModelBytes = 10 * 1024 * 1024;

  sherpa.OfflineTts? _tts;
  final _player = AudioPlayer();
  StreamSubscription? _completeSub;
  bool _initialized = false;
  bool _cancelled = false;

  Future<String> get _modelDirPath async {
    final base = await getApplicationDocumentsDirectory();
    return p.join(base.path, 'sherpa_tts', _modelName);
  }

  bool get isReady => _initialized && _tts != null;

  Future<bool> isModelDownloaded() async {
    final dir = await _modelDirPath;
    final modelFile = File(p.join(dir, 'vits-aishell3.onnx'));
    final tokensFile = File(p.join(dir, 'tokens.txt'));
    return modelFile.existsSync() &&
        modelFile.lengthSync() >= _minModelBytes &&
        tokensFile.existsSync() &&
        tokensFile.lengthSync() > 0;
  }

  Future<void> deleteModelFiles() async {
    try {
      final dir = Directory(await _modelDirPath);
      if (dir.existsSync()) await dir.delete(recursive: true);
      _log('已清除旧模型文件');
    } catch (e) {
      _log('清除模型文件失败: $e', warn: true);
    }
  }

  Future<void> downloadModel({
    required void Function(double progress) onProgress,
  }) async {
    await deleteModelFiles();

    final base = await getApplicationDocumentsDirectory();
    final cacheDir = Directory(p.join(base.path, 'sherpa_tts', 'cache'));
    await cacheDir.create(recursive: true);
    final archivePath = p.join(cacheDir.path, '$_modelName.tar.bz2');

    // ── 步骤 1：下载 ─────────────────────────────────────────────────────────
    _log('=== 开始下载 TTS 模型 ===');
    _log('URL: $_downloadUrl');
    _log('保存路径: $archivePath');
    onProgress(0.0);

    final client = http.Client();
    try {
      final request = http.Request('GET', Uri.parse(_downloadUrl));
      final response = await client
          .send(request)
          .timeout(const Duration(seconds: 60),
              onTimeout: () => throw Exception('连接超时（60s），请检查网络'));

      _log('HTTP ${response.statusCode}, '
          'Content-Length: ${response.contentLength ?? "unknown"}');

      if (response.statusCode != 200) {
        throw Exception('HTTP ${response.statusCode}：下载失败');
      }

      final total = response.contentLength ?? 0;
      int received = 0;
      final sink = File(archivePath).openWrite();
      await for (final chunk in response.stream) {
        sink.add(chunk);
        received += chunk.length;
        if (total > 0) {
          final pct = received / total * 80;
          if (received % (1024 * 1024) < chunk.length) {
            // 每 MB 打印一次进度
            _log('下载中: ${(received / 1024 / 1024).toStringAsFixed(1)} / '
                '${(total / 1024 / 1024).toStringAsFixed(1)} MB');
          }
          onProgress(pct / 100);
        }
      }
      await sink.close();
    } finally {
      client.close();
    }

    // ── 解压前：诊断日志 ─────────────────────────────────────────────────────
    final archiveFile = File(archivePath);
    final archiveExists = archiveFile.existsSync();
    final archiveSize = archiveExists ? archiveFile.lengthSync() : 0;

    _log('=== 解压前检查 ===');
    _log('文件路径: $archivePath');
    _log('文件存在: $archiveExists');
    _log('文件大小: ${(archiveSize / 1024 / 1024).toStringAsFixed(2)} MB ($archiveSize bytes)');

    if (!archiveExists || archiveSize < 1024 * 1024) {
      if (archiveExists && archiveSize > 0) {
        // 打印内容预览（可能是 HTML 错误页）
        final preview = archiveFile.readAsBytesSync();
        final text = String.fromCharCodes(
            preview.sublist(0, preview.length.clamp(0, 300)));
        _log('内容预览(异常): $text', warn: true);
      }
      throw Exception('下载文件异常（$archiveSize bytes），可能网络错误或下载地址失效');
    }

    // 检查 bzip2 magic bytes（BZh = 0x42 0x5A 0x68）
    final raf = archiveFile.openSync();
    final magic = List<int>.filled(4, 0);
    raf.readIntoSync(magic);
    raf.closeSync();
    final magicHex = magic
        .map((b) => '0x${b.toRadixString(16).padLeft(2, "0")}')
        .join(' ');
    _log('Magic bytes: $magicHex  (bzip2 应为 0x42 0x5a 0x68)');

    if (magic[0] != 0x42 || magic[1] != 0x5a || magic[2] != 0x68) {
      final preview = archiveFile.readAsBytesSync();
      final text = String.fromCharCodes(
          preview.sublist(0, preview.length.clamp(0, 500)));
      _log('非 bzip2 内容预览: $text', warn: true);
      throw Exception('下载内容不是合法的 bzip2 压缩包，Magic 错误（$magicHex）');
    }

    _log('Magic 验证通过，开始解压（后台 isolate）…');
    onProgress(0.82);

    // ── 步骤 2：后台解压 ─────────────────────────────────────────────────────
    final extractedFiles = await compute(_extractTarBz2InBackground, {
      'archivePath': archivePath,
      'outputDir': p.join(base.path, 'sherpa_tts'),
    });

    _log('解压完成，共 ${extractedFiles.length} 个文件:');
    for (final f in extractedFiles) {
      _log('  $f');
    }

    // ── 步骤 3：验证关键文件 ─────────────────────────────────────────────────
    final dir = await _modelDirPath;
    final modelFile = File(p.join(dir, 'vits-aishell3.onnx'));
    final modelSize = modelFile.existsSync() ? modelFile.lengthSync() : 0;
    _log('vits-aishell3.onnx 大小: ${(modelSize / 1024 / 1024).toStringAsFixed(2)} MB');

    if (!await isModelDownloaded()) {
      await deleteModelFiles();
      throw Exception(
          'model.onnx 验证失败（${(modelSize / 1024).toStringAsFixed(0)} KB），'
          '解压可能失败，请重试');
    }

    onProgress(1.0);
    _log('=== 模型文件验证通过 ===');

    try {
      await File(archivePath).delete();
    } catch (_) {}
  }

  Future<void> initTts() async {
    if (_initialized) return;

    sherpa.initBindings();

    final dir = await _modelDirPath;
    _log('初始化 TTS，模型目录: $dir');

    final config = sherpa.OfflineTtsConfig(
      model: sherpa.OfflineTtsModelConfig(
        vits: sherpa.OfflineTtsVitsModelConfig(
          model: p.join(dir, 'vits-aishell3.onnx'),
          lexicon: p.join(dir, 'lexicon.txt'),
          tokens: p.join(dir, 'tokens.txt'),
        ),
        numThreads: 2,
        debug: false,
        provider: 'cpu',
      ),
      maxNumSenetences: 100,
    );

    try {
      _tts = sherpa.OfflineTts(config);
    } catch (e) {
      _log('initTts 失败: $e', warn: true);
      await deleteModelFiles();
      rethrow;
    }

    _initialized = true;
    _log('TTS 初始化成功，采样率: ${_tts!.sampleRate}');
  }

  void reset() {
    _tts?.free();
    _tts = null;
    _initialized = false;
  }

  Future<void> speak(
    String text, {
    required void Function() onComplete,
    required void Function(String error) onError,
  }) async {
    if (_tts == null) {
      onError('TTS 未初始化');
      return;
    }

    _cancelled = false;
    await _completeSub?.cancel();
    _completeSub = null;
    await _player.stop();

    try {
      final cleaned = _stripMarkdown(text);
      if (cleaned.trim().isEmpty) {
        onComplete();
        return;
      }

      _log('开始合成，文本长度: ${cleaned.length} 字（后台 isolate）');
      final dir = await _modelDirPath;
      final result = await compute(_generateAudioInBackground, {
        'modelPath': p.join(dir, 'vits-aishell3.onnx'),
        'lexiconPath': p.join(dir, 'lexicon.txt'),
        'tokensPath': p.join(dir, 'tokens.txt'),
        'text': cleaned,
      });
      final samples = result['samples'] as Float32List;
      final sampleRate = result['sampleRate'] as int;
      _log('合成完成，样本数: ${samples.length}, 采样率: $sampleRate');

      if (_cancelled) return;

      final base = await getApplicationDocumentsDirectory();
      final wavPath = p.join(base.path, 'sherpa_tts', 'output.wav');
      await Directory(p.dirname(wavPath)).create(recursive: true);

      sherpa.writeWave(
        filename: wavPath,
        samples: samples,
        sampleRate: sampleRate,
      );
      _log('WAV 写入完成: $wavPath');

      if (_cancelled) return;

      _completeSub = _player.onPlayerComplete.listen((_) {
        _completeSub = null;
        onComplete();
      });

      await _player.play(DeviceFileSource(wavPath));
      _log('开始播放');
    } catch (e) {
      _log('speak 失败: $e', warn: true);
      onError(e.toString());
    }
  }

  Future<void> stop() async {
    _cancelled = true;
    await _completeSub?.cancel();
    _completeSub = null;
    await _player.stop();
  }

  String _stripMarkdown(String text) {
    text = text.replaceAll(RegExp(r'^#{1,6}\s+', multiLine: true), '');
    text = text.replaceAll(RegExp(r'\*{1,3}([^*\n]+)\*{1,3}'), r'$1');
    text = text.replaceAll(RegExp(r'_{1,3}([^_\n]+)_{1,3}'), r'$1');
    text = text.replaceAll(RegExp(r'!\[[^\]]*\]\([^\)]+\)'), '');
    text = text.replaceAll(RegExp(r'\[([^\]]+)\]\([^\)]+\)'), r'$1');
    text = text.replaceAll(RegExp(r'```[\s\S]*?```'), '');
    text = text.replaceAll(RegExp(r'`([^`]+)`'), r'$1');
    text = text.replaceAll(RegExp(r'^[-*_]{3,}\s*$', multiLine: true), '');
    text = text.replaceAll(RegExp(r'^>\s+', multiLine: true), '');
    text = text.replaceAll(RegExp(r'^[-*+]\s+', multiLine: true), '');
    text = text.replaceAll(RegExp(r'^\d+\.\s+', multiLine: true), '');
    return text.trim();
  }

  void dispose() {
    _cancelled = true;
    _completeSub?.cancel();
    _player.dispose();
    _tts?.free();
    _tts = null;
    _initialized = false;
  }
}
