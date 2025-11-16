import 'package:flutter/material.dart';
import 'package:passage/services/firebase_auth_service.dart';
import 'package:passage/services/firestore_chats_service.dart';
import 'package:passage/models/chat_conversation.dart';
import 'chat_thread_screen.dart';

class ConversationsListScreen extends StatelessWidget {
  const ConversationsListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuthService.currentUserId;
    final theme = Theme.of(context);
    if (uid == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Messages')),
        body: const Center(child: Text('Please sign in to view your messages.')),
      );
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Messages')),
      body: StreamBuilder<List<ChatConversation>>(
        stream: FirestoreChatsService.watchConversationsForUser(uid),
        builder: (context, snapshot) {
          final convos = snapshot.data ?? const <ChatConversation>[];
          if (convos.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.chat_bubble_outline_rounded, size: 48, color: theme.colorScheme.onSurface.withValues(alpha: 0.5)),
                  const SizedBox(height: 12),
                  Text('No conversations yet', style: theme.textTheme.titleMedium),
                  const SizedBox(height: 4),
                  Text('Start a chat from a product page', style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurface.withValues(alpha: 0.7))),
                ],
              ),
            );
          }
          return ListView.separated(
            itemCount: convos.length,
            separatorBuilder: (_, __) => Divider(height: 1, color: theme.colorScheme.onSurface.withValues(alpha: 0.06)),
            itemBuilder: (context, index) {
              final c = convos[index];
              return ListTile(
                leading: Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.shopping_bag_outlined, color: Colors.indigo),
                ),
                title: Text(c.productName, maxLines: 1, overflow: TextOverflow.ellipsis),
                subtitle: Text(c.lastMessage.isNotEmpty ? c.lastMessage : 'Tap to continue the conversation'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ChatThreadScreen(
                        chatId: c.id,
                        productName: c.productName,
                      ),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}
