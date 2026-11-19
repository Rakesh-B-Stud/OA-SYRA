import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';
import 'package:intl/intl.dart';
import '../../../../core/config/ai_config.dart';
import '../../../../core/services/grounding_service.dart';
import '../../../../core/utils/time_utils.dart';
import '../../../onboarding/presentation/providers/onboarding_provider.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../health/presentation/providers/health_providers.dart';
import '../../data/repositories/local_chatbot_repository.dart';
import '../../domain/models/chat_models.dart';
import '../../domain/repositories/chatbot_repository.dart';
import '../../domain/services/curated_grounding_service.dart';

final chatbotRepositoryProvider = Provider<ChatbotRepository>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return LocalChatbotRepository(prefs);
});

final groundingServiceProvider = Provider<GroundingService>((ref) {
  return CuratedGroundingService();
});

final chatbotConversationsProvider = FutureProvider<List<ChatConversation>>((ref) async {
  final repository = ref.watch(chatbotRepositoryProvider);
  final userId = ref.watch(authProvider.select((s) => s.email));
  if (userId == null) return [];
  return repository.getConversations(userId);
});

final currentConversationProvider = StateProvider<ChatConversation?>((ref) => null);

class ChatbotNotifier extends StateNotifier<AsyncValue<void>> {
  final ChatbotRepository _repository;
  final GroundingService _groundingService;
  final String _userId;
  final Ref _ref;

  ChatbotNotifier({
    required ChatbotRepository repository,
    required GroundingService groundingService,
    required String userId,
    required Ref ref,
  })  : _repository = repository,
        _groundingService = groundingService,
        _userId = userId,
        _ref = ref,
        super(const AsyncValue.data(null));

  Future<void> sendMessage(String text) async {
    debugPrint("[OASYRA_CHAT] sendMessage() called with prompt: '$text'");
    var currentConv = _ref.read(currentConversationProvider);
    
    if (currentConv == null) {
      debugPrint("[OASYRA_CHAT] currentConv is null, starting new conversation...");
      await startNewConversation();
      currentConv = _ref.read(currentConversationProvider);
    }
    
    if (currentConv == null) {
      debugPrint("[OASYRA_CHAT] ERROR: currentConv remains null after startNewConversation!");
      return;
    }

    debugPrint("[OASYRA_CHAT] Active conv ID: ${currentConv.id}, initial msg count: ${currentConv.messages.length}");

    final userMessage = ChatMessage(
      text: text,
      role: ChatRole.user,
      timestamp: DateTime.now(),
    );

    final updatedMessages = [...currentConv.messages, userMessage];

    final assistantMessage = ChatMessage(
      text: '',
      role: ChatRole.assistant,
      timestamp: DateTime.now(),
    );

    final streamMessages = [...updatedMessages, assistantMessage];

    final updatedConv = currentConv.copyWith(
      messages: streamMessages,
      lastUpdated: DateTime.now(),
    );

    debugPrint("[OASYRA_CHAT] Setting placeholder assistant state. Provider identity: ${identityHashCode(currentConversationProvider)}");
    _ref.read(currentConversationProvider.notifier).state = updatedConv;
    state = const AsyncValue.loading();

    try {
      final domain = _determineDomain(text);
      final curatedContext = await _groundingService.getCuratedContext(domain);
      
      final nowTime = DateTime.now();
      final timeStr = DateFormat('h:mm a').format(nowTime);
      final greeting = getGreeting(nowTime);

      final profile = _ref.read(healthProfileProvider);
      final healthContext = profile != null 
          ? "User Profile: ${profile.name}, BMI ${profile.bmi.toStringAsFixed(1)}, Weight ${profile.currentWeightKg}kg, Goals: ${profile.healthGoals.join(', ')}.\nLocal Time: $timeStr ($greeting).\nMedical Context: $curatedContext"
          : "User Profile: Profile incomplete.\nLocal Time: $timeStr ($greeting).\nMedical Context: $curatedContext";

      final List<Map<String, String>> historyPayload = [];
      final recentMessages = updatedMessages.length > 8 
          ? updatedMessages.sublist(updatedMessages.length - 8) 
          : updatedMessages;

      for (var msg in recentMessages) {
        historyPayload.add({
          "role": msg.role == ChatRole.user ? "user" : "assistant",
          "content": msg.text,
        });
      }

      debugPrint("[OASYRA_CHAT] Sending HTTP POST request to ${AIConfig.backendBaseUrl}/chat/stream ...");
      final client = http.Client();
      final request = http.Request('POST', Uri.parse('${AIConfig.backendBaseUrl}/chat/stream'))
        ..headers['Content-Type'] = 'application/json'
        ..body = jsonEncode({
          'message': text,
          'history': historyPayload,
          'context': healthContext,
        });

      final response = await client.send(request).timeout(const Duration(seconds: 60));
      debugPrint("[OASYRA_CHAT] HTTP Response status: ${response.statusCode}");

      if (response.statusCode == 200) {
        String accumulatedText = '';
        int chunkCount = 0;
        final stream = response.stream.transform(utf8.decoder).transform(const LineSplitter());

        await for (final line in stream) {
          final trimmed = line.trim();
          if (trimmed.isEmpty) continue;
          if (trimmed.startsWith('data: ')) {
            final dataStr = trimmed.substring(6).trim();
            if (dataStr == '[DONE]') {
              debugPrint("[OASYRA_CHAT] Received SSE [DONE]");
              break;
            }
            try {
              final jsonMap = jsonDecode(dataStr);
              if (jsonMap.containsKey('chunk')) {
                final chunk = jsonMap['chunk'] as String;
                accumulatedText += chunk;
                chunkCount++;

                if (chunkCount == 1) {
                  debugPrint("[OASYRA_CHAT] FIRST CHUNK RECEIVED: '$chunk'");
                }

                final currentMessages = List<ChatMessage>.from(
                  _ref.read(currentConversationProvider)?.messages ?? streamMessages,
                );

                if (currentMessages.isNotEmpty && currentMessages.last.role == ChatRole.assistant) {
                  final now = DateTime.now();
                  currentMessages[currentMessages.length - 1] = ChatMessage(
                    text: accumulatedText,
                    role: ChatRole.assistant,
                    timestamp: now,
                  );

                  _ref.read(currentConversationProvider.notifier).state = updatedConv.copyWith(
                    messages: currentMessages,
                    lastUpdated: now,
                  );

                  if (chunkCount % 15 == 0) {
                    debugPrint("[OASYRA_CHAT] Chunk #$chunkCount accumulated length: ${accumulatedText.length}");
                  }
                }
              }
            } catch (err) {
              debugPrint("[OASYRA_CHAT] SSE JSON Decode Error: $err");
            }
          }
        }

        client.close();

        final finalReplyText = accumulatedText.isNotEmpty
            ? _sanitizeClientTables(accumulatedText)
            : "I am here to help with your health and nutrition queries.";

        final finalAssistantMessage = ChatMessage(
          text: finalReplyText,
          role: ChatRole.assistant,
          timestamp: DateTime.now(),
        );

        final finalConv = updatedConv.copyWith(
          messages: [...updatedMessages, finalAssistantMessage],
          title: updatedConv.title == 'New Conversation' && text.length > 3 
              ? text.substring(0, min(text.length, 30)) + (text.length > 30 ? '...' : '')
              : updatedConv.title,
          lastUpdated: DateTime.now(),
        );

        debugPrint("[OASYRA_CHAT] Stream finished. Total chunks: $chunkCount, Total text length: ${finalReplyText.length}. Updating state & saving to local repository...");
        _ref.read(currentConversationProvider.notifier).state = finalConv;
        try {
          await _repository.saveConversation(finalConv);
          debugPrint("[OASYRA_CHAT] Saved final conversation to local repository. ID: ${finalConv.id}");
        } catch (e) {
          debugPrint("[OASYRA_CHAT] Save conversation non-fatal warning: $e");
        }
        _ref.invalidate(chatbotConversationsProvider);
      } else {
        client.close();
        debugPrint("[OASYRA_CHAT] Stream returned HTTP ${response.statusCode}. Falling back to POST /chat...");
        final fallbackResp = await http.post(
          Uri.parse('${AIConfig.backendBaseUrl}/chat'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'message': text,
            'history': historyPayload,
            'context': healthContext,
          }),
        ).timeout(const Duration(seconds: 60));

        if (fallbackResp.statusCode == 200) {
          final data = jsonDecode(fallbackResp.body);
          final replyText = data['reply'] as String? ?? "I am here to help with your health and nutrition queries.";
          
          final finalAssistantMessage = ChatMessage(
            text: replyText,
            role: ChatRole.assistant,
            timestamp: DateTime.now(),
          );

          final finalConv = updatedConv.copyWith(
            messages: [...updatedMessages, finalAssistantMessage],
            title: updatedConv.title == 'New Conversation' && text.length > 3 
                ? text.substring(0, min(text.length, 30)) + (text.length > 30 ? '...' : '')
                : updatedConv.title,
            lastUpdated: DateTime.now(),
          );

          await _repository.saveConversation(finalConv);
          _ref.read(currentConversationProvider.notifier).state = finalConv;
          _ref.invalidate(chatbotConversationsProvider);
        } else {
          throw Exception("Service is taking longer than expected. Please try again in a moment.");
        }
      }
    } on TimeoutException catch (e) {
      debugPrint("[OASYRA_CHAT] TimeoutException encountered: $e");
      final errorAssistantMessage = ChatMessage(
        text: "The AI Guide server is starting up or taking longer to respond. Please try again in a moment.",
        role: ChatRole.assistant,
        timestamp: DateTime.now(),
      );

      final errorConv = updatedConv.copyWith(
        messages: [...updatedMessages, errorAssistantMessage],
        lastUpdated: DateTime.now(),
      );
      _ref.read(currentConversationProvider.notifier).state = errorConv;
    } catch (e, stack) {
      debugPrint("[OASYRA_CHAT] General Exception caught: $e");
      final errorMessage = e.toString().replaceFirst('Exception: ', '');
      final errorAssistantMessage = ChatMessage(
        text: "Notice: $errorMessage",
        role: ChatRole.assistant,
        timestamp: DateTime.now(),
      );

      final errorConv = updatedConv.copyWith(
        messages: [...updatedMessages, errorAssistantMessage],
        lastUpdated: DateTime.now(),
      );
      _ref.read(currentConversationProvider.notifier).state = errorConv;
      state = AsyncValue.error(e, stack);
    } finally {
      state = const AsyncValue.data(null);
    }
  }

  Future<void> sendImageMessage(String imagePath, String promptText) async {
    var currentConv = _ref.read(currentConversationProvider);

    if (currentConv == null) {
      await startNewConversation();
      currentConv = _ref.read(currentConversationProvider);
    }

    if (currentConv == null) return;

    final userMessage = ChatMessage(
      text: promptText.isNotEmpty ? promptText : 'Attached Image Analysis',
      role: ChatRole.user,
      timestamp: DateTime.now(),
      imagePath: imagePath,
    );

    final updatedMessages = [...currentConv.messages, userMessage];

    final assistantMessage = ChatMessage(
      text: '',
      role: ChatRole.assistant,
      timestamp: DateTime.now(),
    );

    final streamMessages = [...updatedMessages, assistantMessage];

    final updatedConv = currentConv.copyWith(
      messages: streamMessages,
      lastUpdated: DateTime.now(),
    );

    _ref.read(currentConversationProvider.notifier).state = updatedConv;
    state = const AsyncValue.loading();

    try {
      final domain = _determineDomain(promptText);
      final curatedContext = await _groundingService.getCuratedContext(domain);

      final profile = _ref.read(healthProfileProvider);
      final healthContext = profile != null
          ? "User Profile: ${profile.name}, BMI ${profile.bmi.toStringAsFixed(1)}, Weight ${profile.currentWeightKg}kg, Goals: ${profile.healthGoals.join(', ')}.\nMedical Context: $curatedContext"
          : "User Profile: Profile incomplete.\nMedical Context: $curatedContext";

      final request = http.MultipartRequest('POST', Uri.parse('${AIConfig.backendBaseUrl}/chat/vision'));
      request.files.add(await http.MultipartFile.fromPath('file', imagePath));
      if (promptText.isNotEmpty) {
        request.fields['message'] = promptText;
      }
      request.fields['context'] = healthContext;

      final streamedResponse = await request.send().timeout(const Duration(seconds: 60));
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final replyText = data['reply'] as String? ?? "Image analysis complete.";

        final finalAssistantMessage = ChatMessage(
          text: replyText,
          role: ChatRole.assistant,
          timestamp: DateTime.now(),
        );

        final finalConv = updatedConv.copyWith(
          messages: [...updatedMessages, finalAssistantMessage],
          title: updatedConv.title == 'New Conversation' ? 'Image Analysis' : updatedConv.title,
          lastUpdated: DateTime.now(),
        );

        _ref.read(currentConversationProvider.notifier).state = finalConv;
        try {
          await _repository.saveConversation(finalConv);
        } catch (_) {}
        _ref.invalidate(chatbotConversationsProvider);
      } else {
        throw Exception("Failed to analyze image (HTTP ${response.statusCode})");
      }
    } catch (e, stack) {
      final errorMessage = e.toString().replaceFirst('Exception: ', '');
      final errorAssistantMessage = ChatMessage(
        text: "Notice: $errorMessage",
        role: ChatRole.assistant,
        timestamp: DateTime.now(),
      );

      final errorConv = updatedConv.copyWith(
        messages: [...updatedMessages, errorAssistantMessage],
        lastUpdated: DateTime.now(),
      );
      _ref.read(currentConversationProvider.notifier).state = errorConv;
      state = AsyncValue.error(e, stack);
    } finally {
      state = const AsyncValue.data(null);
    }
  }

  String _sanitizeClientTables(String text) {
    if (!text.contains('|')) return text;
    final lines = text.split('\n');
    final cleanLines = <String>[];
    for (var line in lines) {
      final trimmed = line.trim();
      if (trimmed.startsWith('|') && trimmed.endsWith('|')) {
        final cells = trimmed.split('|').map((c) => c.trim()).where((c) => c.isNotEmpty).toList();
        if (cells.every((c) => RegExp(r'^-+$').hasMatch(c))) continue;
        cleanLines.add('- ${cells.join(": ")}');
      } else {
        cleanLines.add(line);
      }
    }
    return cleanLines.join('\n');
  }

  String _determineDomain(String text) {
    final lower = text.toLowerCase();
    if (lower.contains('obese') || lower.contains('weight') || lower.contains('bmi') || lower.contains('health score')) {
      return 'obesity';
    }
    return 'nutrition';
  }

  Future<void> startNewConversation() async {
    final newConv = ChatConversation(
      id: const Uuid().v4(),
      userId: _userId,
      title: 'New Conversation',
      messages: const [],
      lastUpdated: DateTime.now(),
    );
    debugPrint("[OASYRA_CHAT] startNewConversation() generated new ID: ${newConv.id}");
    _ref.read(currentConversationProvider.notifier).state = newConv;
  }

  Future<void> resumeLastConversation() async {
    final conversations = await _ref.read(chatbotConversationsProvider.future);
    if (conversations.isNotEmpty) {
      final sorted = [...conversations]..sort((a, b) => b.lastUpdated.compareTo(a.lastUpdated));
      debugPrint("[OASYRA_CHAT] resumeLastConversation() loaded existing ID: ${sorted.first.id}");
      _ref.read(currentConversationProvider.notifier).state = sorted.first;
    } else {
      await startNewConversation();
    }
  }

  Future<void> openConversation(ChatConversation conversation) async {
    debugPrint("[OASYRA_CHAT] openConversation() switched to ID: ${conversation.id}");
    _ref.read(currentConversationProvider.notifier).state = conversation;
  }

  Future<void> deleteConversation(String conversationId) async {
    await _repository.deleteConversation(_userId, conversationId);
    final currentConv = _ref.read(currentConversationProvider);
    if (currentConv?.id == conversationId) {
      _ref.read(currentConversationProvider.notifier).state = null;
    }
    _ref.invalidate(chatbotConversationsProvider);
  }
}

final chatbotNotifierProvider = StateNotifierProvider<ChatbotNotifier, AsyncValue<void>>((ref) {
  final repository = ref.watch(chatbotRepositoryProvider);
  final groundingService = ref.watch(groundingServiceProvider);
  final userId = ref.watch(authProvider.select((s) => s.email));
  
  return ChatbotNotifier(
    repository: repository,
    groundingService: groundingService,
    userId: userId ?? 'anonymous',
    ref: ref,
  );
});
