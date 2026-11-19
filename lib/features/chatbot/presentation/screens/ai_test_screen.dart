import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_ai/firebase_ai.dart';
import '../../../../core/config/ai_config.dart';
import '../../../../shared/widgets/premium_components.dart';
import '../../../../core/theme/oasyra_colors.dart';

class AITestScreen extends StatefulWidget {
  const AITestScreen({super.key});

  @override
  State<AITestScreen> createState() => _AITestScreenState();
}

class _AITestScreenState extends State<AITestScreen> {
  String _status = 'Idle';
  String _response = '';
  bool _isLoading = false;

  Future<void> _runTest() async {
    setState(() {
      _isLoading = true;
      _status = 'Starting...';
      _response = '';
    });

    try {
      // 1. Firebase Check
      final app = Firebase.app();
      print('TEST: Firebase initialized (App: ${app.name})');

      // 2. App Check Check
      print('TEST: Attempting App Check token acquisition...');
      final token = await FirebaseAppCheck.instance.getToken().timeout(
        const Duration(seconds: 10),
        onTimeout: () => 'TOKEN_TIMEOUT',
      );
      if (token == 'TOKEN_TIMEOUT') {
        print('TEST: App Check token acquisition TIMED OUT');
      } else {
        print('TEST: App Check initialization completed');
      }

      // 3. AI Client
      final aiClient = FirebaseAI.googleAI();
      print('TEST: AI client initialized');

      // 4. Model
      final model = aiClient.generativeModel(
        model: AIConfig.geminiModel,
      );
      print('TEST: Model initialized (${AIConfig.geminiModel})');

      // 5. Generate
      print('TEST: BEFORE generateContent');
      final prompt = [Content.text('Reply with exactly: OASYRA CONNECTIVITY SUCCESS')];
      
      print('TEST: generateContent future created');
      final future = model.generateContent(prompt);
      
      print('TEST: AWAITING response...');
      final response = await future.timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          print('TEST: generateContent TIMEOUT REACHED (SDK HANG)');
          throw TimeoutException('SDK Future never resolved. Verify "Firebase AI Logic" and "Gemini Developer API" are enabled in console.');
        },
      );

      print('TEST: RESPONSE RECEIVED');
      final text = response.text;
      print('TEST: RESPONSE TEXT = $text');

      setState(() {
        _status = 'Success';
        _response = text ?? 'Empty response';
      });
    } catch (e, stack) {
      print('TEST: ERROR TYPE = ${e.runtimeType}');
      print('TEST: ERROR MESSAGE = $e');
      print('TEST: STACK TRACE = $stack');
      
      setState(() {
        _status = 'Failed';
        _response = 'Error: $e\n\nType: ${e.runtimeType}';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: OasyraColors.background,
      body: Column(
        children: [
          const PremiumPageHeader(
            title: 'AI Connectivity Test',
            subtitle: 'Final Runtime Diagnosis',
            showBackButton: true,
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('Status: $_status', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: OasyraColors.border),
                    ),
                    child: Text(
                      _response.isEmpty ? 'Logs will appear here...' : _response,
                      style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                    ),
                  ),
                  const SizedBox(height: 32),
                  ElevatedButton(
                    onPressed: _isLoading ? null : _runTest,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: OasyraColors.primary,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(double.infinity, 56),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    child: _isLoading 
                      ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) 
                      : const Text('Run Minimal connectivity Test'),
                  ),
                  if (_response.contains('TimeoutException')) ...[
                    const SizedBox(height: 24),
                    const Text(
                      'DIAGNOSTIC HINT:\nIf you see a timeout, ensure "Firebase AI Logic" is enabled in the Firebase Console and that your phone has active internet access.',
                      style: TextStyle(color: Colors.red, fontSize: 11, fontWeight: FontWeight.bold),
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
