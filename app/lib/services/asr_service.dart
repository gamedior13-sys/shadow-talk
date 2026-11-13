import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sherpa_onnx/sherpa_onnx.dart' as sherpa;

import '../scoring/scoring.dart';

/// Nhận dạng giọng offline 100% (không cần mạng khi dùng):
/// moonshine-tiny-en quantized 28MB, tải 1 lần, decode bằng sherpa-onnx.
class AsrService {
  static const _modelUrl =
      'https://github.com/k2-fsa/sherpa-onnx/releases/download/asr-models/sherpa-onnx-moonshine-tiny-en-quantized-2026-02-27.tar.bz2';
  static const _modelName = 'sherpa-onnx-moonshine-tiny-en-quantized-2026-02-27';

  sherpa.OfflineRecognizer? _recognizer;
  bool _bindingsReady = false;

  Directory? _modelDir;

  Future<Directory> modelDir() async {
    if (_modelDir != null) return _modelDir!;
    final docs = await getApplicationDocumentsDirectory();
    return _modelDir = Directory('${docs.path}/models/$_modelName');
  }

  Future<bool> isModelReady() async {
    final d = await modelDir();
    return File('${d.path}/encoder_model.ort').existsSync() &&
        File('${d.path}/tokens.txt').existsSync();
  }

  /// Tải + giải nén model (chỉ lấy 3 file cần thiết, bỏ test_wavs).
  Future<void> downloadModel({
    void Function(int done, int total)? onDownload,
  }) async {
    final docs = await getApplicationDocumentsDirectory();
    final dir = await modelDir();
    await dir.create(recursive: true);
    final tarFile = File('${docs.path}/model.tar.bz2');

    final client = HttpClient();
    try {
      final req = await client.getUrl(Uri.parse(_modelUrl));
      final resp = await req.close();
      if (resp.statusCode != 200) {
        throw Exception('HTTP ${resp.statusCode} khi tải model');
      }
      final total = resp.contentLength;
      final sink = tarFile.openWrite();
      var done = 0;
      await for (final chunk in resp) {
        done += chunk.length;
        sink.add(chunk);
        onDownload?.call(done, total);
      }
      await sink.flush();
      await sink.close();

      final bz2 = await tarFile.readAsBytes();
      final tar = BZip2Decoder().decodeBytes(bz2);
      final archive = TarDecoder().decodeBytes(tar);
      for (final entry in archive) {
        final base = entry.name.split('/').last;
        if (base == 'encoder_model.ort' ||
            base == 'decoder_model_merged.ort' ||
            base == 'tokens.txt') {
          await File('${dir.path}/$base')
              .writeAsBytes(entry.content as List<int>, flush: true);
        }
      }
      await tarFile.delete();
    } finally {
      client.close();
    }
  }

  Future<void> ensureLoaded() async {
    if (_recognizer != null) return;
    if (!_bindingsReady) {
      await sherpa.initBindingsAsync();
      _bindingsReady = true;
    }
    final d = await modelDir();
    final moonshine = sherpa.OfflineMoonshineModelConfig(
      encoder: '${d.path}/encoder_model.ort',
      mergedDecoder: '${d.path}/decoder_model_merged.ort',
    );
    final modelConfig = sherpa.OfflineModelConfig(
      moonshine: moonshine,
      tokens: '${d.path}/tokens.txt',
      debug: false,
      numThreads: 1,
    );
    final config = sherpa.OfflineRecognizerConfig(model: modelConfig);
    _recognizer = sherpa.OfflineRecognizer(config);
  }

  /// PCM 16 kHz mono int16 → text. Trả null nếu lỗi/chưa sẵn sàng.
  Future<String?> transcribe(List<int> pcm) async {
    if (_recognizer == null) return null;
    if (pcm.isEmpty) return '';
    final samples = Float32List(pcm.length);
    for (var i = 0; i < pcm.length; i++) {
      samples[i] = pcm[i] / 32768.0;
    }
    final stream = _recognizer!.createStream();
    try {
      stream.acceptWaveform(samples: samples, sampleRate: 16000);
      _recognizer!.decode(stream);
      final result = _recognizer!.getResult(stream);
      return normalizeWords(result.text).join(' ');
    } catch (_) {
      return null;
    } finally {
      stream.free();
    }
  }
}
