import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';
import 'package:passage/services/firestore_chats_service.dart';
import 'package:passage/services/firebase_auth_service.dart';
import 'package:passage/models/chat_message.dart';
import 'package:passage/services/local_hidden_messages_store.dart';

class ChatThreadScreen extends StatefulWidget {
  // When opening from a list, we already have chatId.
  final String? chatId;
  // When starting a fresh chat from a product page, we provide seller + product.
  final String? productId;
  final String? sellerId;
  // Optional UI metadata for header rendering.
  final String? productName;
  final String? productImageUrl;
  // Optional: when provided, this message will be sent automatically after
  // the chat is ensured/opened (only once).
  final String? initialMessage;

  const ChatThreadScreen({
    super.key,
    this.chatId,
    this.productId,
    this.sellerId,
    this.productName,
    this.productImageUrl,
    this.initialMessage,
  }) : assert(
          // Either we have chatId, or we have the pieces to create one.
          chatId != null || (productId != null && sellerId != null),
          'Provide chatId or (productId & sellerId) to open a chat',
        );

  @override
  State<ChatThreadScreen> createState() => _ChatThreadScreenState();
}

class _ChatThreadScreenState extends State<ChatThreadScreen> {
  final TextEditingController _textCtrl = TextEditingController();
  String? _conversationId;
  bool _initializing = true;
  String? _initError;
  Timer? _typingTimer;
  bool _initialMessageSent = false;
  Set<String> _hiddenForMe = <String>{};
  String? _headerProductName;

  String _statusLabel(String raw) {
    switch (raw) {
      case 'read':
        return 'Read';
      case 'delivered':
        return 'Delivered';
      case 'sent':
      default:
        return 'Sent';
    }
  }

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    final uid = FirebaseAuthService.currentUserId;
    if (uid == null || uid.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please sign in to start a chat')));
      Navigator.of(context).maybePop();
      return;
    }
    try {
      final String convoId;
      if (widget.chatId != null && widget.chatId!.isNotEmpty) {
        // Opening existing thread
        convoId = widget.chatId!;
      } else {
        // Starting/ensuring a chat from product context
        convoId = await FirestoreChatsService.ensureChatWithUser(
          otherUid: widget.sellerId!,
          listingId: widget.productId,
          productName: widget.productName,
          productImageUrl: widget.productImageUrl,
        );
      }
      if (!mounted) return;
      setState(() {
        _conversationId = convoId;
        _initializing = false;
        _initError = null;
      });
      // Fetch chat doc to enrich header (product info / other user in future)
      try {
        final snap = await FirebaseFirestore.instance.collection('chats').doc(convoId).get();
        final data = snap.data();
        if (data != null) {
          final pn = (data['productName'] ?? '') as String;
          if (pn.isNotEmpty && mounted) {
            setState(() {
              _headerProductName = pn;
            });
          }
        }
      } catch (_) {
        // Non-fatal if chat doc cannot be read
      }
      // Load locally hidden messages for this chat
      final hidden = await LocalHiddenMessagesStore.loadHidden(uid, convoId);
      if (mounted) {
        setState(() {
          _hiddenForMe = hidden;
        });
      }
      // Mark as read on open
      unawaited(FirestoreChatsService.markRead(chatId: convoId, meUid: uid));

      // If an initial message was provided, send it once now.
      final initialText = widget.initialMessage?.trim();
      if (!_initialMessageSent && initialText != null && initialText.isNotEmpty) {
        try {
          await FirestoreChatsService.sendMessage(
            chatId: convoId,
            senderId: uid,
            text: initialText,
          );
          _initialMessageSent = true;
        } catch (e) {
          // Surface non-fatal error; keep the chat open
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Could not send message: '+e.toString())),
            );
          }
        }
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _initializing = false;
        _initError = e.toString();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not start chat: '+e.toString())),
      );
    }
  }

  @override
  void dispose() {
    _textCtrl.dispose();
    _typingTimer?.cancel();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _textCtrl.text.trim();
    if (text.isEmpty || _conversationId == null) return;
    final uid = FirebaseAuthService.currentUserId;
    if (uid == null) return;
    _textCtrl.clear();
    await FirestoreChatsService.sendMessage(chatId: _conversationId!, senderId: uid, text: text);
    // After send, mark read for myself (resets own unread in case of race)
    unawaited(FirestoreChatsService.markRead(chatId: _conversationId!, meUid: uid));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.shopping_bag_outlined, color: Colors.indigo, size: 20),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Chat about', style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurface.withValues(alpha: 0.7))),
                  Text(_headerProductName ?? widget.productName ?? 'Conversation', maxLines: 1, overflow: TextOverflow.ellipsis, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                ],
              ),
            ),
          ],
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: _initializing
                  ? const Center(child: CircularProgressIndicator())
                  : (_conversationId == null)
                      ? _ErrorView(message: _initError ?? 'Unable to open chat. Permission denied or network issue.', onRetry: _bootstrap)
                      : StreamBuilder<List<ChatMessage>>(
                      stream: FirestoreChatsService.watchMessages(_conversationId!),
                      builder: (context, snapshot) {
                        if (snapshot.hasError) {
                          // Log detailed error to help diagnose rules/query issues.
                          debugPrint('watchMessages error for chatId=${_conversationId}: ${snapshot.error}');
                          return _ErrorView(
                            message: 'Can\'t load messages: '+snapshot.error.toString(),
                            onRetry: () => setState(() {}),
                          );
                        }
                        final msgs = snapshot.data ?? const <ChatMessage>[];
                        final uid = FirebaseAuthService.currentUserId;
                        // Mark read whenever messages stream updates
                        if (_conversationId != null && uid != null) {
                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            FirestoreChatsService.markRead(chatId: _conversationId!, meUid: uid);
                              // Additionally, promote other user's messages to "read".
                              FirestoreChatsService.markOtherMessagesRead(chatId: _conversationId!, meUid: uid);
                              // And mark newly received "sent" messages as delivered.
                              final toDeliver = msgs
                                  .where((m) => m.senderId != uid && m.status == 'sent')
                                  .map((m) => m.id)
                                  .toList();
                              if (toDeliver.isNotEmpty) {
                                FirestoreChatsService.markMessagesDelivered(
                                  chatId: _conversationId!,
                                  messageIds: toDeliver,
                                );
                              }
                          });
                        }
                        return ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                          itemCount: msgs.length,
                          itemBuilder: (context, index) {
                            final m = msgs[index];
                            final mine = m.senderId == uid;
                            // Hide messages deleted-for-me (local only)
                            if (uid != null && _hiddenForMe.contains(m.id)) {
                              return const SizedBox.shrink();
                            }
                            final isDeleted = m.isDeletedForEveryone();
                              return Align(
                              alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
                              child: GestureDetector(
                                onLongPress: () => _onLongPressMessage(context, message: m, mine: mine),
                                child: Container(
                                  margin: const EdgeInsets.symmetric(vertical: 4),
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: mine ? theme.colorScheme.primary : theme.colorScheme.surface,
                                    borderRadius: BorderRadius.circular(14),
                                    border: mine
                                        ? null
                                        : Border.all(color: theme.colorScheme.onSurface.withValues(alpha: 0.08)),
                                  ),
                                    child: Column(
                                      crossAxisAlignment: mine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                                      children: [
                                        isDeleted
                                            ? Text(
                                                'Message deleted',
                                                style: theme.textTheme.bodySmall?.copyWith(
                                                  fontStyle: FontStyle.italic,
                                                  color: mine
                                                      ? theme.colorScheme.onPrimary.withValues(alpha: 0.8)
                                                      : theme.colorScheme.onSurface.withValues(alpha: 0.6),
                                                ),
                                              )
                                            : Text(
                                                m.text,
                                                style: mine
                                                    ? theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onPrimary)
                                                    : theme.textTheme.bodyMedium,
                                              ),
                                        if (mine)
                                          Padding(
                                            padding: const EdgeInsets.only(top: 2),
                                            child: Text(
                                              _statusLabel(m.status),
                                              style: theme.textTheme.labelSmall?.copyWith(
                                                color: theme.colorScheme.onPrimary.withValues(alpha: 0.8),
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                ),
                              ),
                            );
                          },
                        );
                      },
                    ),
            ),
            SafeArea(
              top: false,
              child: Container(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface,
                  border: Border(top: BorderSide(color: theme.colorScheme.onSurface.withValues(alpha: 0.06))),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _textCtrl,
                        minLines: 1,
                        maxLines: 4,
                        onChanged: (_) {
                          final meUid = FirebaseAuthService.currentUserId;
                          if (_conversationId == null || meUid == null) return;
                          // Set typing true immediately
                          FirestoreChatsService.setTyping(chatId: _conversationId!, meUid: meUid, isTyping: true);
                          // Debounce to false after 2s idle
                          _typingTimer?.cancel();
                          _typingTimer = Timer(const Duration(seconds: 2), () {
                            FirestoreChatsService.setTyping(chatId: _conversationId!, meUid: meUid, isTyping: false);
                          });
                        },
                        decoration: InputDecoration(
                          hintText: 'Type a message...',
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          // Explicit borders to avoid CanvasKit null paint issues
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: theme.colorScheme.onSurface.withValues(alpha: 0.20), width: 1),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: theme.colorScheme.onSurface.withValues(alpha: 0.20), width: 1),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: theme.colorScheme.primary, width: 1.2),
                          ),
                          disabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: theme.colorScheme.onSurface.withValues(alpha: 0.10), width: 1),
                          ),
                          errorBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: theme.colorScheme.error, width: 1),
                          ),
                          focusedErrorBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: theme.colorScheme.error, width: 1.2),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    FilledButton.icon(
                      onPressed: _send,
                      icon: const Icon(Icons.send_rounded, color: Colors.white),
                      label: const Text('Send'),
                    )
                  ],
                ),
              ),
            )
          ],
        ),
      ),
    );
  }

  Future<void> _onLongPressMessage(BuildContext context, {required ChatMessage message, required bool mine}) async {
    final theme = Theme.of(context);
    final meUid = FirebaseAuthService.currentUserId;
    final chatId = _conversationId;
    if (meUid == null || chatId == null) return;

    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      backgroundColor: theme.colorScheme.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.visibility_off_rounded),
                title: const Text('Delete for me'),
                onTap: () async {
                  Navigator.of(ctx).pop();
                  try {
                    await LocalHiddenMessagesStore.hide(meUid, chatId, message.id);
                    if (mounted) {
                      setState(() {
                        _hiddenForMe = <String>{..._hiddenForMe, message.id};
                      });
                    }
                  } catch (e) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Could not delete for me: '+e.toString())),
                      );
                    }
                  }
                },
              ),
              if (mine)
                ListTile(
                  leading: const Icon(Icons.delete_forever_rounded),
                  title: const Text('Delete for everyone'),
                  onTap: () async {
                    Navigator.of(ctx).pop();
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (dctx) {
                        return AlertDialog(
                          title: const Text('Delete message for everyone?'),
                          content: const Text('This will delete the message for all participants.'),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.of(dctx).pop(false),
                              child: const Text('Cancel'),
                            ),
                            FilledButton(
                              onPressed: () => Navigator.of(dctx).pop(true),
                              child: const Text('Delete'),
                            ),
                          ],
                        );
                      },
                    );
                    if (confirm != true) return;
                    try {
                      await FirestoreChatsService.deleteMessageForEveryone(
                        chatId: chatId,
                        messageId: message.id,
                        imageUrl: message.imageUrl ?? '',
                      );
                    } catch (e) {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Could not delete for everyone: '+e.toString())),
                        );
                      }
                    }
                  },
                ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String message; final VoidCallback onRetry;
  const _ErrorView({required this.message, required this.onRetry});
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.lock_outline_rounded, color: theme.colorScheme.primary),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Text(message, textAlign: TextAlign.center, style: theme.textTheme.bodyMedium),
          ),
            const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Retry'),
          )
        ],
      ),
    );
  }
}
