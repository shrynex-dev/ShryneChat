import 'package:flutter/material.dart';

enum MessageRole { user, assistant, system }

enum MessageFormat { plainText, markdown }

enum MessageStatus { sent, delivering }

class ConversationSummary {
  const ConversationSummary({
    required this.id,
    required this.title,
    required this.createdAt,
    required this.updatedAt,
    required this.lastMessagePreview,
    required this.isPinned,
    required this.isArchived,
  });

  final String id;
  final String title;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String lastMessagePreview;
  final bool isPinned;
  final bool isArchived;
}

class ChatMessageModel {
  const ChatMessageModel({
    required this.id,
    required this.conversationId,
    required this.role,
    required this.body,
    required this.format,
    required this.createdAt,
    required this.sequence,
    required this.status,
  });

  final String id;
  final String conversationId;
  final MessageRole role;
  final String body;
  final MessageFormat format;
  final DateTime createdAt;
  final int sequence;
  final MessageStatus status;

  bool get isAssistant => role == MessageRole.assistant;
}

class AppSettingsModel {
  const AppSettingsModel({
    required this.themeMode,
    required this.useDynamicColor,
    required this.fontScale,
    required this.showLineNumbers,
    required this.animationsEnabled,
  });

  final ThemeMode themeMode;
  final bool useDynamicColor;
  final double fontScale;
  final bool showLineNumbers;
  final bool animationsEnabled;

  AppSettingsModel copyWith({
    ThemeMode? themeMode,
    bool? useDynamicColor,
    double? fontScale,
    bool? showLineNumbers,
    bool? animationsEnabled,
  }) {
    return AppSettingsModel(
      themeMode: themeMode ?? this.themeMode,
      useDynamicColor: useDynamicColor ?? this.useDynamicColor,
      fontScale: fontScale ?? this.fontScale,
      showLineNumbers: showLineNumbers ?? this.showLineNumbers,
      animationsEnabled: animationsEnabled ?? this.animationsEnabled,
    );
  }

  static const defaults = AppSettingsModel(
    themeMode: ThemeMode.system,
    useDynamicColor: true,
    fontScale: 1,
    showLineNumbers: true,
    animationsEnabled: true,
  );
}
