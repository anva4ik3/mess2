class Chat {
  final String id;
  final String type; // direct | group
  final String displayName;
  final String? displayAvatar;
  final String? lastMessage;
  final String? lastMessageType;
  final String? lastMessageSenderId;
  final DateTime? lastMessageAt;
  final int unreadCount;
  final String? otherUserId;
  final bool otherUserOnline;
  final bool isMuted;
  final String? pinnedMessageId;

  Chat({
    required this.id,
    required this.type,
    required this.displayName,
    this.displayAvatar,
    this.lastMessage,
    this.lastMessageType,
    this.lastMessageSenderId,
    this.lastMessageAt,
    this.unreadCount = 0,
    this.otherUserId,
    this.otherUserOnline = false,
    this.isMuted = false,
    this.pinnedMessageId,
  });

  factory Chat.fromJson(Map<String, dynamic> j) => Chat(
        id: j['id'],
        type: j['type'],
        displayName: j['display_name'] ?? 'Чат',
        displayAvatar: j['display_avatar'],
        lastMessage: j['last_message'],
        lastMessageType: j['last_message_type'],
        lastMessageSenderId: j['last_message_sender'],
        lastMessageAt: j['last_message_at'] != null ? DateTime.parse(j['last_message_at']) : null,
        unreadCount: int.tryParse(j['unread_count']?.toString() ?? '0') ?? 0,
        otherUserId: j['other_user_id'],
        otherUserOnline: j['other_user_online'] ?? false,
        isMuted: j['is_muted'] ?? false,
        pinnedMessageId: j['pinned_message_id'],
      );

  Chat copyWith({bool? otherUserOnline}) => Chat(
        id: id,
        type: type,
        displayName: displayName,
        displayAvatar: displayAvatar,
        lastMessage: lastMessage,
        lastMessageType: lastMessageType,
        lastMessageSenderId: lastMessageSenderId,
        lastMessageAt: lastMessageAt,
        unreadCount: unreadCount,
        otherUserId: otherUserId,
        otherUserOnline: otherUserOnline ?? this.otherUserOnline,
        isMuted: isMuted,
        pinnedMessageId: pinnedMessageId,
      );
}

class Reaction {
  final String emoji;
  final List<String> users;
  final int count;

  Reaction({required this.emoji, required this.users, required this.count});

  factory Reaction.fromJson(Map<String, dynamic> j) => Reaction(
        emoji: j['emoji'],
        users: (j['users'] as List?)?.map((e) => e.toString()).toList() ?? [],
        count: int.tryParse(j['count']?.toString() ?? '1') ?? 1,
      );
}

class Message {
  final String id;
  final String chatId;
  final String senderId;
  final String senderName;
  final String senderUsername;
  final String? senderAvatar;
  final String content;
  final String type; // text | image | ai | voice | file
  final String? replyTo;
  final String? replyContent;
  final String? replySender;
  final String? forwardFromUser;
  final String? mediaUrl;
  final DateTime createdAt;
  final DateTime? editedAt;
  final bool isDeleted;
  final bool isPinned;
  final List<Reaction> reactions;

  Message({
    required this.id,
    required this.chatId,
    required this.senderId,
    required this.senderName,
    required this.senderUsername,
    this.senderAvatar,
    required this.content,
    this.type = 'text',
    this.replyTo,
    this.replyContent,
    this.replySender,
    this.forwardFromUser,
    this.mediaUrl,
    required this.createdAt,
    this.editedAt,
    this.isDeleted = false,
    this.isPinned = false,
    this.reactions = const [],
  });

  factory Message.fromJson(Map<String, dynamic> j) => Message(
        id: j['id'],
        chatId: j['chat_id'] ?? '',
        senderId: j['sender_id'],
        senderName: j['display_name'] ?? j['username'] ?? 'Unknown',
        senderUsername: j['username'] ?? '',
        senderAvatar: j['avatar_url'],
        content: j['content'] ?? '',
        type: j['type'] ?? 'text',
        replyTo: j['reply_to'],
        replyContent: j['reply_content'],
        replySender: j['reply_sender'],
        forwardFromUser: j['forward_from_user'],
        mediaUrl: j['media_url'],
        createdAt: DateTime.parse(j['created_at']),
        editedAt: j['edited_at'] != null ? DateTime.parse(j['edited_at']) : null,
        isDeleted: j['deleted_at'] != null,
        isPinned: j['is_pinned'] ?? false,
        reactions: (j['reactions'] as List?)
                ?.where((r) => r != null && r is Map)
                .map((r) => Reaction.fromJson(r as Map<String, dynamic>))
                .toList() ??
            [],
      );

  Message copyWith({List<Reaction>? reactions, bool? isPinned, String? content, DateTime? editedAt}) => Message(
        id: id,
        chatId: chatId,
        senderId: senderId,
        senderName: senderName,
        senderUsername: senderUsername,
        senderAvatar: senderAvatar,
        content: content ?? this.content,
        type: type,
        replyTo: replyTo,
        replyContent: replyContent,
        replySender: replySender,
        forwardFromUser: forwardFromUser,
        mediaUrl: mediaUrl,
        createdAt: createdAt,
        editedAt: editedAt ?? this.editedAt,
        isDeleted: isDeleted,
        isPinned: isPinned ?? this.isPinned,
        reactions: reactions ?? this.reactions,
      );
}

class Channel {
  final String id;
  final String username;
  final String name;
  final String? description;
  final String? avatarUrl;
  final String ownerName;
  final int subscriberCount;
  final bool isPublic;
  final double monthlyPrice;
  final bool isSubscribed;
  final bool isOwner;
  final String? lastPost;

  Channel({
    required this.id,
    required this.username,
    required this.name,
    this.description,
    this.avatarUrl,
    required this.ownerName,
    this.subscriberCount = 0,
    this.isPublic = true,
    this.monthlyPrice = 0,
    this.isSubscribed = false,
    this.isOwner = false,
    this.lastPost,
  });

  factory Channel.fromJson(Map<String, dynamic> j) => Channel(
        id: j['id'],
        username: j['username'],
        name: j['name'],
        description: j['description'],
        avatarUrl: j['avatar_url'],
        ownerName: j['owner_name'] ?? '',
        subscriberCount: j['subscriber_count'] ?? 0,
        isPublic: j['is_public'] ?? true,
        monthlyPrice: double.tryParse(j['monthly_price']?.toString() ?? '0') ?? 0,
        isSubscribed: j['is_subscribed'] ?? false,
        isOwner: j['is_owner'] ?? false,
        lastPost: j['last_post'],
      );
}

class Contact {
  final String id;
  final String userId;
  final String username;
  final String displayName;
  final String? avatarUrl;
  final String? bio;
  final String? statusText;
  final bool isOnline;
  final DateTime? lastSeenAt;
  final String? nickname;

  Contact({
    required this.id,
    required this.userId,
    required this.username,
    required this.displayName,
    this.avatarUrl,
    this.bio,
    this.statusText,
    this.isOnline = false,
    this.lastSeenAt,
    this.nickname,
  });

  String get displayLabel => nickname ?? displayName;

  factory Contact.fromJson(Map<String, dynamic> j) => Contact(
        id: j['id'],
        userId: j['user_id'],
        username: j['username'],
        displayName: j['display_name'] ?? j['username'],
        avatarUrl: j['avatar_url'],
        bio: j['bio'],
        statusText: j['status_text'],
        isOnline: j['is_online'] ?? false,
        lastSeenAt: j['last_seen_at'] != null ? DateTime.parse(j['last_seen_at']) : null,
        nickname: j['nickname'],
      );
}
