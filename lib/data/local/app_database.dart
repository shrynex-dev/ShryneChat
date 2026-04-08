import 'dart:io';
import 'dart:math';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart' show ThemeMode;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../models/chat_models.dart';

part 'app_database.g.dart';

class Conversations extends Table {
  TextColumn get id => text()();
  TextColumn get title => text()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  TextColumn get lastMessagePreview => text().withDefault(const Constant(''))();
  TextColumn get remoteState => text().nullable()();
  BoolColumn get isPinned => boolean().withDefault(const Constant(false))();
  BoolColumn get isArchived => boolean().withDefault(const Constant(false))();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

class Messages extends Table {
  TextColumn get id => text()();
  TextColumn get conversationId => text().references(Conversations, #id)();
  TextColumn get role => text()();
  TextColumn get body => text()();
  TextColumn get transportData => text().nullable()();
  TextColumn get format => text()();
  DateTimeColumn get createdAt => dateTime()();
  IntColumn get sequence => integer()();
  TextColumn get status => text()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

class AppSettingsTable extends Table {
  IntColumn get id => integer().withDefault(const Constant(1))();
  TextColumn get themeMode => text().withDefault(const Constant('system'))();
  BoolColumn get useDynamicColor =>
      boolean().withDefault(const Constant(true))();
  RealColumn get fontScale => real().withDefault(const Constant(1.0))();
  BoolColumn get showLineNumbers =>
      boolean().withDefault(const Constant(true))();
  BoolColumn get animationsEnabled =>
      boolean().withDefault(const Constant(true))();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

@DriftDatabase(tables: [Conversations, Messages, AppSettingsTable])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  @override
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (migrator) async => migrator.createAll(),
    onUpgrade: (migrator, from, to) async {
      if (from < 2) {
        await migrator.addColumn(conversations, conversations.remoteState);
        await migrator.addColumn(messages, messages.transportData);
      }
    },
  );

  Future<void> ensureSeeded() async {
    final existing = await select(appSettingsTable).getSingleOrNull();
    if (existing == null) {
      await into(appSettingsTable).insert(AppSettingsTableCompanion.insert());
    }
  }

  Stream<List<ConversationSummary>> watchConversations() {
    final query = (select(conversations)
      ..where((tbl) => tbl.isArchived.equals(false))
      ..orderBy([
        (tbl) =>
            OrderingTerm(expression: tbl.isPinned, mode: OrderingMode.desc),
        (tbl) =>
            OrderingTerm(expression: tbl.updatedAt, mode: OrderingMode.desc),
      ]));

    return query.watch().map(
      (rows) => rows
          .map(
            (row) => ConversationSummary(
              id: row.id,
              title: row.title,
              createdAt: row.createdAt,
              updatedAt: row.updatedAt,
              lastMessagePreview: row.lastMessagePreview,
              isPinned: row.isPinned,
              isArchived: row.isArchived,
            ),
          )
          .toList(growable: false),
    );
  }

  Future<ConversationSummary?> getConversation(String id) async {
    final row = await (select(
      conversations,
    )..where((tbl) => tbl.id.equals(id))).getSingleOrNull();

    if (row == null) {
      return null;
    }

    return ConversationSummary(
      id: row.id,
      title: row.title,
      createdAt: row.createdAt,
      updatedAt: row.updatedAt,
      lastMessagePreview: row.lastMessagePreview,
      isPinned: row.isPinned,
      isArchived: row.isArchived,
    );
  }

  Stream<List<ChatMessageModel>> watchMessages(String conversationId) {
    final query = (select(messages)
      ..where((tbl) => tbl.conversationId.equals(conversationId))
      ..orderBy([
        (tbl) => OrderingTerm(expression: tbl.sequence, mode: OrderingMode.asc),
      ]));

    return query.watch().map(
      (rows) => rows.map(_mapMessage).toList(growable: false),
    );
  }

  Future<String> createConversation({
    required String title,
    required String preview,
  }) async {
    final now = DateTime.now();
    final id = _nextId();
    await into(conversations).insert(
      ConversationsCompanion.insert(
        id: id,
        title: title,
        createdAt: now,
        updatedAt: now,
        lastMessagePreview: Value(preview),
        remoteState: const Value.absent(),
      ),
    );
    return id;
  }

  Future<int> nextSequence(String conversationId) async {
    final expression = messages.sequence.max();
    final query = selectOnly(messages)
      ..addColumns([expression])
      ..where(messages.conversationId.equals(conversationId));
    final row = await query.getSingleOrNull();
    final current = row?.read(expression);
    return (current ?? 0) + 1;
  }

  Future<void> insertMessage({
    required String conversationId,
    required MessageRole role,
    required MessageFormat format,
    required MessageStatus status,
    required String body,
    String? transportData,
  }) async {
    final now = DateTime.now();
    final sequenceValue = await nextSequence(conversationId);
    await into(messages).insert(
      MessagesCompanion.insert(
        id: _nextId(),
        conversationId: conversationId,
        role: role.name,
        body: body,
        transportData: Value(transportData),
        format: format.name,
        createdAt: now,
        sequence: sequenceValue,
        status: status.name,
      ),
    );

    final conversation = await (select(
      conversations,
    )..where((tbl) => tbl.id.equals(conversationId))).getSingle();

    await (update(
      conversations,
    )..where((tbl) => tbl.id.equals(conversationId))).write(
      ConversationsCompanion(
        updatedAt: Value(now),
        lastMessagePreview: Value(_preview(body)),
        title: role == MessageRole.user && conversation.title == 'New chat'
            ? Value(_titleFromBody(body))
            : const Value.absent(),
      ),
    );
  }

  Future<String?> getConversationRemoteState(String conversationId) async {
    final row = await (select(
      conversations,
    )..where((tbl) => tbl.id.equals(conversationId))).getSingleOrNull();
    return row?.remoteState;
  }

  Future<void> updateConversationRemoteState(
    String conversationId,
    String? remoteState,
  ) {
    return (update(conversations)
          ..where((tbl) => tbl.id.equals(conversationId)))
        .write(ConversationsCompanion(remoteState: Value(remoteState)));
  }

  Stream<AppSettingsModel> watchSettings() {
    return select(appSettingsTable).watchSingle().map(_mapSettings);
  }

  Future<void> saveSettings(AppSettingsModel settings) {
    return into(appSettingsTable).insertOnConflictUpdate(
      AppSettingsTableCompanion(
        id: const Value(1),
        themeMode: Value(settings.themeMode.name),
        useDynamicColor: Value(settings.useDynamicColor),
        fontScale: Value(settings.fontScale),
        showLineNumbers: Value(settings.showLineNumbers),
        animationsEnabled: Value(settings.animationsEnabled),
      ),
    );
  }

  Future<void> clearChats() async {
    await transaction(() async {
      await delete(messages).go();
      await delete(conversations).go();
    });
  }

  ChatMessageModel _mapMessage(Message row) {
    return ChatMessageModel(
      id: row.id,
      conversationId: row.conversationId,
      role: MessageRole.values.byName(row.role),
      body: row.body,
      transportData: row.transportData,
      format: MessageFormat.values.byName(row.format),
      createdAt: row.createdAt,
      sequence: row.sequence,
      status: MessageStatus.values.byName(row.status),
    );
  }

  AppSettingsModel _mapSettings(AppSettingsTableData row) {
    return AppSettingsModel(
      themeMode: ThemeMode.values.byName(row.themeMode),
      useDynamicColor: row.useDynamicColor,
      fontScale: row.fontScale,
      showLineNumbers: row.showLineNumbers,
      animationsEnabled: row.animationsEnabled,
    );
  }

  String _titleFromBody(String body) {
    final trimmed = body
        .replaceAll(RegExp(r'\s+'), ' ')
        .replaceAll(RegExp(r'[#*_`>\-\[\]\|]'), '')
        .trim();
    if (trimmed.isEmpty) {
      return 'New chat';
    }
    return trimmed.length > 42 ? '${trimmed.substring(0, 42)}…' : trimmed;
  }

  String _preview(String body) {
    final preview = body.replaceAll(RegExp(r'\s+'), ' ').trim();
    return preview.length > 72 ? '${preview.substring(0, 72)}…' : preview;
  }
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final directory = await getApplicationDocumentsDirectory();
    final file = File(p.join(directory.path, 'shryne_chat.sqlite'));
    return NativeDatabase.createInBackground(file);
  });
}

final _random = Random();

String _nextId() {
  final now = DateTime.now().microsecondsSinceEpoch;
  final entropy = _random.nextInt(1 << 32).toRadixString(16).padLeft(8, '0');
  return '$now-$entropy';
}
