class ChatParticipantModel {
  final String id;
  final String fullName;
  final String? avatarUrl;
  final String role;
  final String? department;

  const ChatParticipantModel({
    required this.id,
    required this.fullName,
    this.avatarUrl,
    required this.role,
    this.department,
  });

  factory ChatParticipantModel.fromJson(Map<String, dynamic> json) {
    return ChatParticipantModel(
      id: (json['id'] ?? '').toString(),
      fullName: (json['fullName'] ?? json['full_name'] ?? 'Colleague').toString(),
      avatarUrl: json['avatarUrl'] ?? json['avatar_url'],
      role: (json['role'] ?? 'member').toString(),
      department: json['department']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'fullName': fullName,
      'avatarUrl': avatarUrl,
      'role': role,
      'department': department,
    };
  }
}

class ChatMessageSummaryModel {
  final String id;
  final String content;
  final String? imageUrl;
  final String senderId;
  final String senderName;
  final DateTime createdAt;
  final String? projectId;

  const ChatMessageSummaryModel({
    required this.id,
    required this.content,
    this.imageUrl,
    required this.senderId,
    required this.senderName,
    required this.createdAt,
    this.projectId,
  });

  factory ChatMessageSummaryModel.fromJson(Map<String, dynamic> json) {
    return ChatMessageSummaryModel(
      id: (json['id'] ?? '').toString(),
      content: (json['content'] ?? '').toString(),
      imageUrl: json['imageUrl'] ?? json['image_url'],
      senderId: (json['senderId'] ?? json['sender_id'] ?? '').toString(),
      senderName: (json['senderName'] ?? json['sender_name'] ?? '').toString(),
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
      projectId: json['projectId'] ?? json['project_id'],
    );
  }
}

class ChatChannelModel {
  final String id;
  final String type; // 'direct' or 'project'
  final String? name;
  final String? projectId;
  final String? projectName;
  final String? projectCode;
  final String? projectStatus;
  final int unreadCount;
  final DateTime updatedAt;
  final ChatParticipantModel? otherUser;
  final ChatMessageSummaryModel? lastMessage;

  const ChatChannelModel({
    required this.id,
    required this.type,
    this.name,
    this.projectId,
    this.projectName,
    this.projectCode,
    this.projectStatus,
    this.unreadCount = 0,
    required this.updatedAt,
    this.otherUser,
    this.lastMessage,
  });

  bool get isDirect => type == 'direct';
  bool get isProject => type == 'project';

  String get title {
    if (isProject) {
      return projectName ?? name ?? 'Project Team';
    }
    return otherUser?.fullName ?? 'Direct Message';
  }

  String get subtitle {
    if (lastMessage != null) {
      if (lastMessage!.imageUrl != null && lastMessage!.imageUrl!.isNotEmpty) {
        return lastMessage!.content.isNotEmpty ? '📷 ${lastMessage!.content}' : '📷 Photo';
      }
      if (lastMessage!.content.isNotEmpty) {
        return lastMessage!.content;
      }
      if (lastMessage!.projectId != null) {
        return '📁 Project Reference';
      }
    }
    return isProject ? 'Project group discussion' : 'Start a conversation';
  }

  factory ChatChannelModel.fromJson(Map<String, dynamic> json) {
    return ChatChannelModel(
      id: (json['id'] ?? '').toString(),
      type: (json['type'] ?? 'direct').toString(),
      name: json['name']?.toString(),
      projectId: json['projectId'] ?? json['project_id'],
      projectName: json['projectName'] ?? json['project_name'],
      projectCode: json['projectCode'] ?? json['project_code'],
      projectStatus: json['projectStatus'] ?? json['project_status'],
      unreadCount: (json['unreadCount'] ?? json['unread_count']) is num
          ? ((json['unreadCount'] ?? json['unread_count']) as num).toInt()
          : int.tryParse((json['unreadCount'] ?? json['unread_count'])?.toString() ?? '0') ?? 0,
      updatedAt: json['updatedAt'] != null || json['updated_at'] != null
          ? DateTime.tryParse((json['updatedAt'] ?? json['updated_at']).toString()) ?? DateTime.now()
          : DateTime.now(),
      otherUser: (json['otherUser'] ?? json['other_user']) != null
          ? ChatParticipantModel.fromJson(Map<String, dynamic>.from(json['otherUser'] ?? json['other_user']))
          : null,
      lastMessage: (json['lastMessage'] ?? json['last_message']) != null
          ? ChatMessageSummaryModel.fromJson(Map<String, dynamic>.from(json['lastMessage'] ?? json['last_message']))
          : null,
    );
  }
}

class ChatMessageModel {
  final String id;
  final String channelId;
  final String senderId;
  final String senderName;
  final String? senderAvatarUrl;
  final String? senderRole;
  final String content;
  final String? imageUrl;
  final String? projectId;
  final String? projectName;
  final String? projectCode;
  final String? projectStatus;
  final double? projectBudget;
  final double? projectSpent;
  final String? replyToId;
  final DateTime createdAt;
  final bool isMe;

  const ChatMessageModel({
    required this.id,
    required this.channelId,
    required this.senderId,
    required this.senderName,
    this.senderAvatarUrl,
    this.senderRole,
    required this.content,
    this.imageUrl,
    this.projectId,
    this.projectName,
    this.projectCode,
    this.projectStatus,
    this.projectBudget,
    this.projectSpent,
    this.replyToId,
    required this.createdAt,
    this.isMe = false,
  });

  bool get hasImage => imageUrl != null && imageUrl!.isNotEmpty;
  bool get hasProject => projectId != null && projectId!.isNotEmpty;

  factory ChatMessageModel.fromJson(Map<String, dynamic> json, {String? currentUserId}) {
    final sender = (json['senderId'] ?? json['sender_id'] ?? '').toString();
    final bool me = json['isMe'] == true || (currentUserId != null && sender == currentUserId);

    return ChatMessageModel(
      id: (json['id'] ?? '').toString(),
      channelId: (json['channelId'] ?? json['channel_id'] ?? '').toString(),
      senderId: sender,
      senderName: (json['senderName'] ?? json['sender_name'] ?? 'Colleague').toString(),
      senderAvatarUrl: json['senderAvatarUrl'] ?? json['sender_avatar_url'],
      senderRole: json['senderRole'] ?? json['sender_role'],
      content: (json['content'] ?? '').toString(),
      imageUrl: json['imageUrl'] ?? json['image_url'],
      projectId: json['projectId'] ?? json['project_id'],
      projectName: json['projectName'] ?? json['project_name'],
      projectCode: json['projectCode'] ?? json['project_code'],
      projectStatus: json['projectStatus'] ?? json['project_status'],
      projectBudget: json['projectBudget'] != null ? (json['projectBudget'] as num).toDouble() : null,
      projectSpent: json['projectSpent'] != null ? (json['projectSpent'] as num).toDouble() : null,
      replyToId: json['replyToId'] ?? json['reply_to_id'],
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
      isMe: me,
    );
  }
}
