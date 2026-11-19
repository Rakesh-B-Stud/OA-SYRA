import 'dart:async';
import 'dart:io';
import 'package:fllama/fllama.dart';
import 'package:fllama/fllama_type.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

enum LlmState { uninitialized, downloading, loading, ready, generating, error }

class OnDeviceLlmService {
  static const String primaryModelName = 'Llama-3.2-1B-Instruct-Q4_K_M.gguf';
  static const String primaryModelUrl =
      'https://huggingface.co/bartowski/Llama-3.2-1B-Instruct-GGUF/resolve/main/Llama-3.2-1B-Instruct-Q4_K_M.gguf';
  static const int primaryModelSizeBytes = 678000000; // ~678 MB

  static OnDeviceLlmService? _instance;
  LlmState _state = LlmState.uninitialized;
  double _downloadProgress = 0.0;
  String? _errorMessage;
  File? _modelFile;
  double? _contextId;
  bool _isCancelled = false;

  OnDeviceLlmService._internal();

  factory OnDeviceLlmService() {
    _instance ??= OnDeviceLlmService._internal();
    return _instance!;
  }

  LlmState get state => _state;
  double get downloadProgress => _downloadProgress;
  String? get errorMessage => _errorMessage;

  Future<File> get _localModelFile async {
    if (_modelFile != null) return _modelFile!;
    final dir = await getApplicationDocumentsDirectory();
    final modelsDir = Directory(p.join(dir.path, 'models'));
    if (!await modelsDir.exists()) {
      await modelsDir.create(recursive: true);
    }
    _modelFile = File(p.join(modelsDir.path, primaryModelName));
    return _modelFile!;
  }

  Future<bool> isModelDownloaded() async {
    try {
      final file = await _localModelFile;
      if (await file.exists()) {
        final length = await file.length();
        return length > 100 * 1024 * 1024;
      }
    } catch (_) {}
    return false;
  }

  Future<String?> computeModelChecksum() async {
    try {
      final file = await _localModelFile;
      if (await file.exists()) {
        final fllama = Fllama.instance();
        if (fllama != null) {
          return await fllama.getFileSHA256(file.path);
        }
      }
    } catch (_) {}
    return null;
  }

  Future<void> downloadModel({void Function(double progress)? onProgress}) async {
    try {
      _state = LlmState.downloading;
      _downloadProgress = 0.0;
      _errorMessage = null;

      final file = await _localModelFile;
      if (await file.exists()) {
        await file.delete();
      }

      final client = http.Client();
      final request = http.Request('GET', Uri.parse(primaryModelUrl));
      final response = await client.send(request);

      if (response.statusCode != 200) {
        throw Exception('Download failed with HTTP status ${response.statusCode}');
      }

      final contentLength = response.contentLength ?? primaryModelSizeBytes;
      int downloaded = 0;

      final sink = file.openWrite();
      await response.stream.forEach((chunk) {
        downloaded += chunk.length;
        sink.add(chunk);
        if (contentLength > 0) {
          _downloadProgress = downloaded / contentLength;
          if (onProgress != null) onProgress(_downloadProgress);
        }
      });

      await sink.flush();
      await sink.close();
      client.close();

      _state = LlmState.ready;
    } catch (e) {
      _state = LlmState.error;
      _errorMessage = 'Model download failed: $e';
      rethrow;
    }
  }

  Future<void> initializeModel() async {
    try {
      if (_contextId != null) {
        _state = LlmState.ready;
        return;
      }

      _state = LlmState.loading;
      _errorMessage = null;

      final isDownloaded = await isModelDownloaded();
      if (!isDownloaded) {
        throw Exception('Model file not found. Please download the model first.');
      }

      final file = await _localModelFile;
      final fllama = Fllama.instance();
      if (fllama == null) {
        throw Exception('Fllama native platform interface not available.');
      }

      final res = await fllama.initContext(
        file.path,
        nCtx: 2048,
        nThreads: 4,
      );

      if (res != null && res.containsKey('contextId')) {
        _contextId = (res['contextId'] as num).toDouble();
        _state = LlmState.ready;
      } else {
        throw Exception('Failed to initialize llama.cpp model context.');
      }
    } catch (e) {
      _state = LlmState.error;
      _errorMessage = 'Model initialization failed: $e';
      rethrow;
    }
  }

  Stream<String> generateTextStream({
    required String prompt,
    String? systemPrompt,
    int maxTokens = 512,
    double temperature = 0.7,
  }) async* {
    if (_contextId == null) {
      await initializeModel();
    }

    if (_contextId == null) {
      throw Exception('Model context is not initialized.');
    }

    _state = LlmState.generating;
    _isCancelled = false;

    final fllama = Fllama.instance();
    if (fllama == null) {
      throw Exception('Fllama instance missing.');
    }

    final messages = <RoleContent>[];
    if (systemPrompt != null && systemPrompt.isNotEmpty) {
      messages.add(RoleContent(role: 'system', content: systemPrompt));
    }
    messages.add(RoleContent(role: 'user', content: prompt));

    final formattedPrompt = await fllama.getFormattedChat(_contextId!, messages: messages) ?? prompt;

    final controller = StreamController<String>();

    StreamSubscription? tokenSub;
    tokenSub = fllama.onTokenStream?.listen((data) {
      if (_isCancelled) return;

      if (data.containsKey('token')) {
        final tokenStr = data['token'].toString();
        if (tokenStr.isNotEmpty) {
          controller.add(tokenStr);
        }
      }

      if (data.containsKey('isDone') && data['isDone'] == true) {
        controller.close();
      }
    });

    try {
      await fllama.completion(
        _contextId!,
        prompt: formattedPrompt,
        temperature: temperature,
        nPredict: maxTokens,
        emitRealtimeCompletion: true,
      );

      await for (final token in controller.stream) {
        if (_isCancelled) break;
        yield token;
      }
    } catch (e) {
      _state = LlmState.ready;
      rethrow;
    } finally {
      await tokenSub?.cancel();
      _state = LlmState.ready;
      if (!controller.isClosed) {
        await controller.close();
      }
    }
  }

  void cancelInference() {
    _isCancelled = true;
    if (_contextId != null) {
      try {
        Fllama.instance()?.stopCompletion(contextId: _contextId!);
      } catch (_) {}
    }
    _state = LlmState.ready;
  }

  Future<void> dispose() async {
    _isCancelled = true;
    if (_contextId != null) {
      try {
        await Fllama.instance()?.releaseContext(_contextId!);
      } catch (_) {}
      _contextId = null;
    }
    _state = LlmState.uninitialized;
  }
}
