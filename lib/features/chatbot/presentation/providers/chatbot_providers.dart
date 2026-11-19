import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';
import '../../../../core/config/ai_config.dart';
import '../../../../core/services/grounding_service.dart';
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
    var currentConv = _ref.read(currentConversationProvider);
    
    if (currentConv == null) {
      await startNewConversation();
      currentConv = _ref.read(currentConversationProvider);
    }
    
    if (currentConv == null) return;

    final userMessage = ChatMessage(
      text: text,
      role: ChatRole.user,
      timestamp: DateTime.now(),
    );

    final updatedMessages = [...currentConv.messages, userMessage];
    final updatedConv = currentConv.copyWith(
      messages: updatedMessages,
      lastUpdated: DateTime.now(),
    );

    _ref.read(currentConversationProvider.notifier).state = updatedConv;
    state = const AsyncValue.loading();

    try {
      final domain = _determineDomain(text);
      final curatedContext = await _groundingService.getCuratedContext(domain);
      
      final profile = _ref.read(healthProfileProvider);
      final healthContext = profile != null 
          ? "User Profile: ${profile.name}, BMI ${profile.bmi.toStringAsFixed(1)}, Weight ${profile.currentWeightKg}kg, Goals: ${profile.healthGoals.join(', ')}.\nMedical Context: $curatedContext"
          : "User Profile: Profile incomplete.\nMedical Context: $curatedContext";

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

      final response = await http.post(
        Uri.parse('${AIConfig.backendBaseUrl}/chat'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'message': text,
          'history': historyPayload,
          'context': healthContext,
        }),
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
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
        );

        await _repository.saveConversation(finalConv);
        _ref.read(currentConversationProvider.notifier).state = finalConv;
        _ref.invalidate(chatbotConversationsProvider);
        state = const AsyncValue.data(null);
      } else {
        final errBody = jsonDecode(response.body);
        final detail = errBody['detail'] ?? 'Backend service error (${response.statusCode})';
        throw Exception(detail);
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
      );
      _ref.read(currentConversationProvider.notifier).state = errorConv;
      state = AsyncValue.error(e, stack);
    }
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
    _ref.read(currentConversationProvider.notifier).state = newConv;
  }

  Future<void> resumeLastConversation() async {
    final conversations = await _ref.read(chatbotConversationsProvider.future);
    if (conversations.isNotEmpty) {
      final sorted = [...conversations]..sort((a, b) => b.lastUpdated.compareTo(a.lastUpdated));
      _ref.read(currentConversationProvider.notifier).state = sorted.first;
    } else {
      await startNewConversation();
    }
  }

  Future<void> openConversation(ChatConversation conversation) async {
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
