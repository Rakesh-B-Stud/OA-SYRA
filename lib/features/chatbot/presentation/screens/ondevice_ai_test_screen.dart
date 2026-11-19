import 'dart:async';
import 'package:flutter/material.dart';
import '../../../../core/services/ondevice_llm_service.dart';
import '../../../../core/theme/oasyra_colors.dart';
import '../../../../shared/widgets/premium_components.dart';

class OnDeviceAiTestScreen extends StatefulWidget {
  const OnDeviceAiTestScreen({super.key});

  @override
  State<OnDeviceAiTestScreen> createState() => _OnDeviceAiTestScreenState();
}

class _OnDeviceAiTestScreenState extends State<OnDeviceAiTestScreen> {
  final OnDeviceLlmService _llmService = OnDeviceLlmService();
  final TextEditingController _promptController = TextEditingController(
    text: 'Suggest a healthy high-protein Indian breakfast for weight management.',
  );

  bool _isDownloaded = false;
  bool _isDownloading = false;
  double _downloadProgress = 0.0;
  bool _isGenerating = false;
  String _generatedText = '';
  String? _errorMessage;

  int _tokenCount = 0;
  int _inferenceDurationMs = 0;
  double _tokensPerSecond = 0.0;
  Stopwatch? _stopwatch;

  @override
  void initState() {
    super.initState();
    _checkModelStatus();
  }

  @override
  void dispose() {
    _promptController.dispose();
    super.dispose();
  }

  Future<void> _checkModelStatus() async {
    final downloaded = await _llmService.isModelDownloaded();
    if (mounted) {
      setState(() {
        _isDownloaded = downloaded;
      });
    }
  }

  Future<void> _startDownload() async {
    setState(() {
      _isDownloading = true;
      _downloadProgress = 0.0;
      _errorMessage = null;
    });

    try {
      await _llmService.downloadModel(onProgress: (progress) {
        if (mounted) {
          setState(() => _downloadProgress = progress);
        }
      });
      await _checkModelStatus();
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
        });
      }
    } finally {
      if (mounted) {
        setState(() => _isDownloading = false);
      }
    }
  }

  Future<void> _generateResponse() async {
    final prompt = _promptController.text.trim();
    if (prompt.isEmpty) return;

    setState(() {
      _isGenerating = true;
      _generatedText = '';
      _errorMessage = null;
      _tokenCount = 0;
      _inferenceDurationMs = 0;
      _tokensPerSecond = 0.0;
    });

    _stopwatch = Stopwatch()..start();

    try {
      await _llmService.initializeModel();

      final stream = _llmService.generateTextStream(
        prompt: prompt,
        systemPrompt: 'You are OASYRA AI Virtual Dietitian. Provide concise, evidence-based nutrition advice.',
        maxTokens: 512,
      );

      await for (final token in stream) {
        if (!mounted) break;
        setState(() {
          _generatedText += token;
          _tokenCount++;
          _inferenceDurationMs = _stopwatch?.elapsedMilliseconds ?? 1;
          if (_inferenceDurationMs > 0) {
            _tokensPerSecond = (_tokenCount / (_inferenceDurationMs / 1000.0));
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _errorMessage = e.toString());
      }
    } finally {
      _stopwatch?.stop();
      if (mounted) {
        setState(() => _isGenerating = false);
      }
    }
  }

  void _cancelGeneration() {
    _llmService.cancelInference();
    _stopwatch?.stop();
    setState(() => _isGenerating = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: OasyraColors.background,
      body: Column(
        children: [
          const PremiumPageHeader(
            title: 'On-Device LLM Test',
            subtitle: 'llama.cpp GGUF Offline Inference Prototype',
            showBackButton: true,
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const PremiumSectionHeader(
                    title: 'Model Status & Download',
                    subtitle: 'Llama 3.2 1B Instruct GGUF',
                  ),
                  const SizedBox(height: 16),
                  OasyraCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              _isDownloaded ? Icons.check_circle_rounded : Icons.file_download_outlined,
                              color: _isDownloaded ? OasyraColors.success : OasyraColors.primary,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                _isDownloaded ? 'Model Ready (Llama-3.2-1B Q4_K_M)' : 'Model Not Downloaded (~678 MB)',
                                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                              ),
                            ),
                          ],
                        ),
                        if (_isDownloading) ...[
                          const SizedBox(height: 16),
                          LinearProgressIndicator(
                            value: _downloadProgress,
                            backgroundColor: OasyraColors.primarySoft,
                            color: OasyraColors.primary,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Downloading: ${(_downloadProgress * 100).toStringAsFixed(1)}%',
                            style: const TextStyle(fontSize: 12, color: OasyraColors.textTertiary),
                          ),
                        ],
                        if (!_isDownloaded && !_isDownloading) ...[
                          const SizedBox(height: 16),
                          ElevatedButton.icon(
                            onPressed: _startDownload,
                            icon: const Icon(Icons.download_rounded),
                            label: const Text('Download GGUF Model'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: OasyraColors.primary,
                              foregroundColor: Colors.white,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),

                  const SizedBox(height: 28),

                  const PremiumSectionHeader(
                    title: 'Offline Inference Prompt',
                    subtitle: 'Test on-device text generation',
                  ),
                  const SizedBox(height: 16),
                  OasyraCard(
                    child: Column(
                      children: [
                        TextField(
                          controller: _promptController,
                          maxLines: 3,
                          decoration: const InputDecoration(
                            hintText: 'Enter prompt...',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: (_isGenerating || !_isDownloaded) ? null : _generateResponse,
                                icon: const Icon(Icons.play_arrow_rounded),
                                label: Text(_isGenerating ? 'Generating...' : 'Generate Response'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: OasyraColors.primary,
                                  foregroundColor: Colors.white,
                                ),
                              ),
                            ),
                            if (_isGenerating) ...[
                              const SizedBox(width: 12),
                              OutlinedButton.icon(
                                onPressed: _cancelGeneration,
                                icon: const Icon(Icons.stop_rounded, color: OasyraColors.error),
                                label: const Text('Cancel', style: TextStyle(color: OasyraColors.error)),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),

                  if (_errorMessage != null) ...[
                    const SizedBox(height: 20),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: OasyraColors.errorLight,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text(_errorMessage!, style: const TextStyle(color: OasyraColors.error, fontSize: 13)),
                    ),
                  ],

                  const SizedBox(height: 28),

                  if (_tokenCount > 0 || _generatedText.isNotEmpty) ...[
                    const PremiumSectionHeader(
                      title: 'Performance Metrics',
                      subtitle: 'On-device CPU inference stats',
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: PremiumMetricCard(
                            label: 'Tokens Generated',
                            value: _tokenCount.toString(),
                            icon: Icons.onetwothree_rounded,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: PremiumMetricCard(
                            label: 'Generation Speed',
                            value: _tokensPerSecond.toStringAsFixed(1),
                            unit: 'tok/s',
                            icon: Icons.speed_rounded,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    OasyraCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Generated Output:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                          const SizedBox(height: 12),
                          SelectableText(
                            _generatedText.isEmpty ? '...' : _generatedText,
                            style: const TextStyle(fontSize: 14, height: 1.5, color: OasyraColors.textPrimary),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
