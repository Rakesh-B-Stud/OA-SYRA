import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../../core/config/ai_config.dart';
import '../../../../core/theme/oasyra_colors.dart';
import '../../../../shared/widgets/premium_components.dart';
import '../providers/chatbot_providers.dart';
import '../../domain/models/chat_models.dart';

class ChatbotScreen extends ConsumerStatefulWidget {
  const ChatbotScreen({super.key});

  @override
  ConsumerState<ChatbotScreen> createState() => _ChatbotScreenState();
}

class _ChatbotScreenState extends ConsumerState<ChatbotScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  File? _selectedImage;

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _pickImage(ImageSource source) async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: source, imageQuality: 85);
    if (pickedFile != null) {
      setState(() {
        _selectedImage = File(pickedFile.path);
      });
    }
  }

  void _showImagePickerModal() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Attach Image', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 16),
              ListTile(
                leading: const Icon(Icons.camera_alt_rounded, color: OasyraColors.primary),
                title: const Text('Take Photo (Camera)'),
                onTap: () {
                  Navigator.pop(context);
                  _pickImage(ImageSource.camera);
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_library_rounded, color: OasyraColors.primary),
                title: const Text('Choose from Gallery'),
                onTap: () {
                  Navigator.pop(context);
                  _pickImage(ImageSource.gallery);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _handleSend() {
    final text = _messageController.text.trim();
    if (_selectedImage != null) {
      final imagePath = _selectedImage!.path;
      setState(() {
        _selectedImage = null;
      });
      ref.read(chatbotNotifierProvider.notifier).sendImageMessage(imagePath, text);
      _messageController.clear();
      _scrollToBottom();
    } else if (text.isNotEmpty) {
      ref.read(chatbotNotifierProvider.notifier).sendMessage(text);
      _messageController.clear();
      _scrollToBottom();
    }
  }

  void _onQuickAction(String text) {
    ref.read(chatbotNotifierProvider.notifier).sendMessage(text);
    _scrollToBottom();
  }

  void _confirmDeleteConversation(BuildContext context, ChatConversation conv) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Delete Conversation?', style: TextStyle(fontWeight: FontWeight.w600)),
        content: Text('Are you sure you want to delete "${conv.title}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: OasyraColors.textTertiary)),
          ),
          ElevatedButton(
            onPressed: () {
              ref.read(chatbotNotifierProvider.notifier).deleteConversation(conv.id);
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: OasyraColors.error,
              foregroundColor: Colors.white,
              elevation: 0,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentConversation = ref.watch(currentConversationProvider);
    final chatbotState = ref.watch(chatbotNotifierProvider);
    debugPrint("[OASYRA_CHAT_UI] ChatbotScreen.build() executed. Conv ID: ${currentConversation?.id}, Msg count: ${currentConversation?.messages.length}, isLoading: ${chatbotState.isLoading}");

    ref.listen(chatbotNotifierProvider, (previous, next) {
      next.maybeWhen(
        error: (e, _) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: ${e.toString()}')),
          );
        },
        orElse: () {},
      );
    });

    // Auto-scroll on new message
    ref.listen(currentConversationProvider, (prev, next) => _scrollToBottom());

    return Scaffold(
      backgroundColor: OasyraColors.background,
      drawer: _buildDrawer(),
      body: Column(
        children: [
          Builder(
            builder: (scaffoldContext) {
              return PremiumPageHeader(
                title: 'Virtual Dietitian',
                subtitle: 'AI Health & Nutrition Guide',
                showBackButton: true,
                actions: [
                  IconButton(
                    icon: const Icon(Icons.history_rounded, color: Colors.white),
                    tooltip: 'Recent Chats',
                    onPressed: () => Scaffold.of(scaffoldContext).openDrawer(),
                  ),
                  IconButton(
                    icon: const Icon(Icons.add_comment_rounded, color: Colors.white),
                    tooltip: 'New Chat',
                    onPressed: () => ref.read(chatbotNotifierProvider.notifier).startNewConversation(),
                  ),
                ],
              );
            },
          ),
          
          // Safety Disclaimer
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            color: OasyraColors.primarySoft.withValues(alpha: 0.5),
            child: Row(
              children: [
                const Icon(Icons.info_outline_rounded, size: 14, color: OasyraColors.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'OASYRA provides wellness guidance, not medical diagnosis. Consult a doctor for clinical concerns.',
                    style: TextStyle(fontSize: 10, color: OasyraColors.textSecondary, fontWeight: FontWeight.w500),
                  ),
                ),
              ],
            ),
          ),

          Expanded(
            child: currentConversation == null || currentConversation.messages.isEmpty
                ? _buildEmptyState()
                : _buildMessageList(currentConversation.messages, chatbotState.isLoading),
          ),

          if (currentConversation == null || currentConversation.messages.isEmpty)
            _buildQuickActions(),

          _buildInputArea(chatbotState.isLoading),
        ],
      ),
    );
  }

  Widget _buildDrawer() {
    final conversations = ref.watch(chatbotConversationsProvider);

    return Drawer(
      child: Column(
        children: [
          DrawerHeader(
            decoration: const BoxDecoration(gradient: OasyraColors.primaryGradient),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.psychology_outlined, size: 44, color: Colors.white),
                  const SizedBox(height: 12),
                  const Text(
                    'Recent Conversations',
                    style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.add_comment_rounded, color: OasyraColors.primary),
            title: const Text('New Conversation', style: TextStyle(fontWeight: FontWeight.bold)),
            onTap: () {
              ref.read(chatbotNotifierProvider.notifier).startNewConversation();
              Navigator.pop(context);
            },
          ),
          const Divider(),
          Expanded(
            child: conversations.when(
              data: (list) {
                if (list.isEmpty) {
                  return const Center(
                    child: Text('No previous conversations', style: TextStyle(color: OasyraColors.textTertiary, fontSize: 13)),
                  );
                }
                return ListView.builder(
                  padding: EdgeInsets.zero,
                  itemCount: list.length,
                  itemBuilder: (context, index) {
                    final conv = list[index];
                    return ListTile(
                      leading: const Icon(Icons.chat_bubble_outline_rounded, color: OasyraColors.primary),
                      title: Text(conv.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                      subtitle: Text(DateFormat('MMM dd, h:mm a').format(conv.lastUpdated), style: const TextStyle(fontSize: 11, color: OasyraColors.textTertiary)),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete_outline_rounded, color: OasyraColors.error, size: 20),
                        onPressed: () => _confirmDeleteConversation(context, conv),
                      ),
                      onTap: () {
                        ref.read(chatbotNotifierProvider.notifier).openConversation(conv);
                        Navigator.pop(context);
                      },
                    );
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Error loading history: $e')),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: OasyraColors.primarySoft,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.psychology_outlined, size: 48, color: OasyraColors.primary),
          ),
          const SizedBox(height: 24),
          const Text(
            'How can I help you today?',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: OasyraColors.textPrimary),
          ),
          const SizedBox(height: 8),
          const Text(
            'Ask me about your diet, weight, or health goals.',
            style: TextStyle(color: OasyraColors.textTertiary),
          ),
        ],
      ),
    ).animate().fadeIn();
  }

  Widget _buildMessageList(List<ChatMessage> messages, bool isLoading) {
    debugPrint("[OASYRA_CHAT_UI] _buildMessageList() rendering ${messages.length} messages. Last msg role: ${messages.isNotEmpty ? messages.last.role : 'none'}, text len: ${messages.isNotEmpty ? messages.last.text.length : 0}");
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.all(24),
      itemCount: messages.length,
      itemBuilder: (context, index) {
        final message = messages[index];
        return _buildMessageBubble(message);
      },
    );
  }

  Widget _buildMessageBubble(ChatMessage message) {
    final isUser = message.role == ChatRole.user;
    final isStreamingEmpty = !isUser && message.text.isEmpty;

    return Padding(
      key: ValueKey('${message.timestamp.millisecondsSinceEpoch}_${message.role.name}'),
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isUser) ...[
            _buildAvatar(Icons.smart_toy_outlined, OasyraColors.primary),
            const SizedBox(width: 12),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isUser ? OasyraColors.primary : Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(20),
                  topRight: const Radius.circular(20),
                  bottomLeft: Radius.circular(isUser ? 20 : 4),
                  bottomRight: Radius.circular(isUser ? 4 : 20),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.03),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (message.imagePath != null && File(message.imagePath!).existsSync()) ...[
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.file(
                        File(message.imagePath!),
                        width: 200,
                        height: 150,
                        fit: BoxFit.cover,
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                  if (isUser)
                    Text(
                      message.text,
                      style: const TextStyle(
                        color: Colors.white,
                        height: 1.5,
                        fontSize: 14,
                      ),
                    )
                  else if (isStreamingEmpty)
                    _buildTypingIndicator()
                  else
                    MarkdownBody(
                      data: message.text,
                      selectable: true,
                      styleSheet: MarkdownStyleSheet(
                        p: const TextStyle(color: OasyraColors.textPrimary, fontSize: 14, height: 1.5),
                        h1: const TextStyle(color: OasyraColors.primary, fontSize: 18, fontWeight: FontWeight.bold),
                        h2: const TextStyle(color: OasyraColors.primary, fontSize: 16, fontWeight: FontWeight.bold),
                        h3: const TextStyle(color: OasyraColors.primary, fontSize: 15, fontWeight: FontWeight.w600),
                        strong: const TextStyle(color: OasyraColors.textPrimary, fontWeight: FontWeight.bold),
                        listBullet: const TextStyle(color: OasyraColors.primary, fontSize: 14),
                        tableBody: const TextStyle(color: OasyraColors.textPrimary, fontSize: 13),
                        tableHead: const TextStyle(color: OasyraColors.primary, fontWeight: FontWeight.bold, fontSize: 13),
                        tableBorder: TableBorder.all(color: OasyraColors.border, width: 1),
                        tablePadding: const EdgeInsets.all(8),
                      ),
                    ),
                  const SizedBox(height: 4),
                  Text(
                    DateFormat('h:mm a').format(message.timestamp),
                    style: TextStyle(
                      fontSize: 9,
                      color: isUser ? Colors.white.withValues(alpha: 0.7) : OasyraColors.textTertiary,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (isUser) ...[
            const SizedBox(width: 12),
            _buildAvatar(Icons.person_outline_rounded, OasyraColors.textTertiary),
          ],
        ],
      ),
    );
  }

  Widget _buildAvatar(IconData icon, Color color) {
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        shape: BoxShape.circle,
      ),
      child: Icon(icon, size: 18, color: color),
    );
  }

  Widget _buildTypingIndicator() {
    return const _AnimatedThinkingIndicator();
  }

  Widget _buildQuickActions() {
    final actions = AIConfig.quickActions;

    return Container(
      height: 50,
      padding: const EdgeInsets.only(bottom: 8),
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        scrollDirection: Axis.horizontal,
        itemCount: actions.length,
        separatorBuilder: (context, index) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          return ActionChip(
            label: Text(actions[index], style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
            backgroundColor: Colors.white,
            side: const BorderSide(color: OasyraColors.border),
            onPressed: () => _onQuickAction(actions[index]),
          );
        },
      ),
    );
  }

  Widget _buildInputArea(bool isLoading) {
    return Container(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 16,
        bottom: MediaQuery.of(context).padding.bottom + 16,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(topLeft: Radius.circular(32), topRight: Radius.circular(32)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_selectedImage != null) ...[
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: OasyraColors.surfaceSoft,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.file(
                      _selectedImage!,
                      width: 50,
                      height: 50,
                      fit: BoxFit.cover,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text('Image attached', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                  ),
                  IconButton(
                    icon: const Icon(Icons.cancel_rounded, color: OasyraColors.error),
                    onPressed: () => setState(() => _selectedImage = null),
                  ),
                ],
              ),
            ),
          ],
          Row(
            children: [
              IconButton(
                onPressed: isLoading ? null : _showImagePickerModal,
                icon: const Icon(Icons.add_photo_alternate_outlined, color: OasyraColors.primary),
                tooltip: 'Attach image',
              ),
              const SizedBox(width: 4),
              Expanded(
                child: TextField(
                  controller: _messageController,
                  enabled: !isLoading,
                  style: const TextStyle(fontSize: 14),
                  decoration: InputDecoration(
                    hintText: _selectedImage != null ? 'Ask about this image...' : 'Type your question...',
                    hintStyle: const TextStyle(color: OasyraColors.textTertiary),
                    filled: true,
                    fillColor: OasyraColors.surfaceSoft,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  ),
                  onSubmitted: (_) => _handleSend(),
                ),
              ),
              const SizedBox(width: 12),
              IconButton.filled(
                onPressed: isLoading ? null : _handleSend,
                icon: const Icon(Icons.send_rounded),
                style: IconButton.styleFrom(
                  backgroundColor: OasyraColors.primary,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _AnimatedThinkingIndicator extends StatefulWidget {
  const _AnimatedThinkingIndicator();

  @override
  State<_AnimatedThinkingIndicator> createState() => _AnimatedThinkingIndicatorState();
}

class _AnimatedThinkingIndicatorState extends State<_AnimatedThinkingIndicator> {
  int _statusIndex = 0;
  Timer? _timer;

  static const List<String> _statuses = [
    'Understanding your question...',
    'Reviewing your nutrition context...',
    'Preparing your response...',
  ];

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(milliseconds: 2500), (timer) {
      if (mounted) {
        setState(() {
          _statusIndex = (_statusIndex + 1) % _statuses.length;
        });
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'OASYRA Virtual Dietitian',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: OasyraColors.primary,
          ),
        ),
        const SizedBox(height: 6),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              '...',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: OasyraColors.primary,
              ),
            ).animate(onPlay: (c) => c.repeat()).shimmer(duration: 1.seconds),
            const SizedBox(width: 8),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 400),
              child: Text(
                _statuses[_statusIndex],
                key: ValueKey<int>(_statusIndex),
                style: const TextStyle(
                  fontSize: 12,
                  fontStyle: FontStyle.italic,
                  color: OasyraColors.textTertiary,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
