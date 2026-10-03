import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/testing/widget_keys.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../domain/models/reading_session.dart';
import '../../../../domain/models/user_book.dart';
import '../../../../domain/repositories/reading_session_repository.dart';
import '../../../../shared/providers/book_data_provider.dart';
import '../../reading/data/reading_session_repository_provider.dart';
import '../../reading/domain/reading_session_editor_service.dart';

/// 読書セッションの記録・修正・削除画面
class ReadingSessionLogScreen extends ConsumerStatefulWidget {
  final ReadingSessionRepository? repositoryOverride;
  final List<UserBook>? booksOverride;
  final DateTime Function()? nowOverride;

  /// テスト用初期値（null なら repo から読み込む）
  final List<ReadingSession>? sessionsOverride;

  const ReadingSessionLogScreen({
    super.key,
    this.repositoryOverride,
    this.booksOverride,
    this.nowOverride,
    this.sessionsOverride,
  });

  @override
  ConsumerState<ReadingSessionLogScreen> createState() =>
      _ReadingSessionLogScreenState();
}

class _ReadingSessionLogScreenState
    extends ConsumerState<ReadingSessionLogScreen> {
  List<ReadingSession> _sessions = const [];

  // widget の値は late final で固めず getter で毎回読む（State 再利用対策）
  ReadingSessionRepository get _repo =>
      widget.repositoryOverride ?? ref.read(readingSessionRepositoryProvider);

  List<UserBook> get _books =>
      widget.booksOverride ?? ref.watch(bookDataProvider).userBooks;

  DateTime get _now => widget.nowOverride?.call() ?? DateTime.now();

  @override
  void initState() {
    super.initState();
    final override = widget.sessionsOverride;
    if (override != null) {
      _sessions = List.of(override);
    } else {
      _reload();
    }
  }

  Future<void> _reload() async {
    final list = await _repo.getRecentSessions(limit: 100);
    if (!mounted) return;
    setState(() => _sessions = list);
  }

  String _bookTitle(String userBookId) {
    for (final ub in _books) {
      if (ub.id == userBookId) return ub.book?.title ?? '(無題)';
    }
    return '(不明な本)';
  }

  Future<void> _openForm({ReadingSession? existing}) async {
    await showDialog<void>(
      context: context,
      builder: (_) => _SessionFormDialog(
        books: _books,
        now: _now,
        existing: existing,
        onSave: (session, {required bool isEdit}) async {
          if (isEdit) {
            await _repo.updateSession(session);
          } else {
            await _repo.createSession(session);
          }
          await _reload();
        },
      ),
    );
  }

  Future<void> _confirmDelete(ReadingSession session) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('記録を削除'),
        content: const Text('この読書記録を削除しますか？'),
        actions: [
          TextButton(
            key: AppKeys.readingSessionFormCancel,
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('キャンセル'),
          ),
          TextButton(
            key: AppKeys.readingSessionDeleteConfirm,
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('削除'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await _repo.deleteSession(session.id);
      await _reload();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: AppKeys.readingSessionLogScreen,
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('📝 読書記録'),
        actions: [
          IconButton(
            key: AppKeys.readingSessionAddButton,
            icon: const Icon(Icons.add),
            tooltip: '手動で記録',
            onPressed: () => _openForm(),
          ),
        ],
      ),
      body: _sessions.isEmpty
          ? Container(
              key: AppKeys.readingSessionLogEmpty,
              alignment: Alignment.center,
              child: const Text('読書記録がありません'),
            )
          : ListView.builder(
              key: AppKeys.readingSessionLogList,
              itemCount: _sessions.length,
              itemBuilder: (context, index) {
                final s = _sessions[index];
                final started =
                    DateTime.parse(s.startedAt).toLocal();
                return Card(
                  color: AppTheme.cardBackground,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 8),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _bookTitle(s.userBookId),
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                ReadingSessionEditorService.dateOnly(started),
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AppTheme.textSecondary,
                                ),
                              ),
                              Text(
                                ReadingSessionEditorService.formatDuration(
                                    s.durationMinutes ?? 0),
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AppTheme.textSecondary,
                                ),
                              ),
                              Text(
                                'p.${s.startPage}${s.endPage != null ? '〜${s.endPage}' : ''}',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AppTheme.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          key: AppKeys.readingSessionEditButton(s.id),
                          icon: const Icon(Icons.edit, size: 20),
                          tooltip: '編集',
                          onPressed: () => _openForm(existing: s),
                        ),
                        IconButton(
                          key: AppKeys.readingSessionDeleteButton(s.id),
                          icon: const Icon(Icons.delete_outline, size: 20),
                          tooltip: '削除',
                          onPressed: () => _confirmDelete(s),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}

/// 手動記録・編集フォーム（showDialog で開く）
class _SessionFormDialog extends StatefulWidget {
  final List<UserBook> books;
  final DateTime now;
  final ReadingSession? existing;
  final Future<void> Function(ReadingSession session, {required bool isEdit})
      onSave;

  const _SessionFormDialog({
    required this.books,
    required this.now,
    required this.existing,
    required this.onSave,
  });

  @override
  State<_SessionFormDialog> createState() => _SessionFormDialogState();
}

class _SessionFormDialogState extends State<_SessionFormDialog> {
  final _durationController = TextEditingController();
  final _startPageController = TextEditingController();
  final _endPageController = TextEditingController();
  late String? _selectedBookId;
  late DateTime _date;
  String? _errorText;

  @override
  void initState() {
    super.initState();
    final ex = widget.existing;
    if (ex != null) {
      _selectedBookId = ex.userBookId;
      _date = DateTime.parse(ex.startedAt).toLocal();
      _durationController.text = (ex.durationMinutes ?? 0).toString();
      _startPageController.text = ex.startPage.toString();
      _endPageController.text = ex.endPage?.toString() ?? '';
    } else {
      _selectedBookId =
          widget.books.isNotEmpty ? widget.books.first.id : null;
      _date = widget.now;
    }
  }

  @override
  void dispose() {
    _durationController.dispose();
    _startPageController.dispose();
    _endPageController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() => _date = DateTime(picked.year, picked.month, picked.day));
    }
  }

  Future<void> _save() async {
    final duration = int.tryParse(_durationController.text) ?? 0;
    final startPage = int.tryParse(_startPageController.text) ?? -1;
    final endPageText = _endPageController.text.trim();
    final endPage = endPageText.isEmpty ? null : int.tryParse(endPageText);
    final userBookId = _selectedBookId ?? '';

    final validation = ReadingSessionEditorService.validate(
      userBookId: userBookId,
      durationMinutes: duration,
      startPage: startPage,
      endPage: endPage,
    );
    if (!validation.isValid) {
      setState(() => _errorText = validation.message);
      return;
    }

    final startedAt = ReadingSessionEditorService.combineDateAndTime(
      ReadingSessionEditorService.dateOnly(_date),
      widget.now.hour,
      widget.now.minute,
    );
    if (startedAt == null) {
      setState(() => _errorText = '日付が不正です');
      return;
    }

    final session = ReadingSessionEditorService.buildManual(
      id: widget.existing?.id ?? const Uuid().v4(),
      userBookId: userBookId,
      startedAt: startedAt,
      durationMinutes: duration,
      startPage: startPage,
      endPage: endPage,
    );
    Navigator.of(context).pop();
    await widget.onSave(session, isEdit: widget.existing != null);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      key: AppKeys.readingSessionFormDialog,
      title: Text(widget.existing == null ? '読書を記録' : '記録を修正'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            DropdownButtonFormField<String>(
              key: AppKeys.readingSessionFormBook,
              initialValue: _selectedBookId,
              decoration: const InputDecoration(labelText: '本'),
              items: widget.books
                  .map((b) => DropdownMenuItem(
                        value: b.id,
                        child: Text(b.book?.title ?? '(無題)',
                            overflow: TextOverflow.ellipsis),
                      ))
                  .toList(),
              onChanged: (v) => setState(() => _selectedBookId = v),
            ),
            const SizedBox(height: 8),
            InkWell(
              key: AppKeys.readingSessionFormDate,
              onTap: _pickDate,
              child: InputDecorator(
                decoration: const InputDecoration(
                  labelText: '日付',
                  suffixIcon: Icon(Icons.calendar_today, size: 18),
                ),
                child: Text(ReadingSessionEditorService.dateOnly(_date)),
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              key: AppKeys.readingSessionFormDuration,
              controller: _durationController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: '読書時間（分）'),
            ),
            const SizedBox(height: 8),
            TextField(
              key: AppKeys.readingSessionFormStartPage,
              controller: _startPageController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: '開始ページ'),
            ),
            const SizedBox(height: 8),
            TextField(
              key: AppKeys.readingSessionFormEndPage,
              controller: _endPageController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: '終了ページ（任意）'),
            ),
            if (_errorText != null) ...[
              const SizedBox(height: 8),
              Text(
                _errorText!,
                key: const Key('txt_reading_session_form_error'),
                style: const TextStyle(color: Colors.red, fontSize: 12),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          key: AppKeys.readingSessionFormCancel,
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('キャンセル'),
        ),
        FilledButton(
          key: AppKeys.readingSessionFormSave,
          onPressed: _save,
          child: const Text('保存'),
        ),
      ],
    );
  }
}
