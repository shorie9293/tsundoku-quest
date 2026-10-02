import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../data/reading_notes_provider.dart';

/// 読書感想カード（検索画面・一覧共通）
class ReadingNoteCard extends StatelessWidget {
  final ReadingNoteItem note;
  const ReadingNoteCard({super.key, required this.note});

  @override
  Widget build(BuildContext context) {
    final title = note.bookTitle ?? '不明な本';
    final date = note.createdAt.length >= 10
        ? note.createdAt.substring(0, 10)
        : note.createdAt;

    return Container(
      key: Key('card_reading_note_${note.id}'),
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.cardBackground,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.border.withAlpha(100)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(title,
                    style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textPrimary)),
              ),
              Text(date,
                  style: const TextStyle(
                      fontSize: 11, color: AppTheme.textSecondary)),
            ],
          ),
          const SizedBox(height: 8),
          ...note.learnings
              .where((l) => l.isNotEmpty)
              .map((learning) => Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('💡 ', style: TextStyle(fontSize: 12)),
                        Expanded(
                          child: Text(learning,
                              style: const TextStyle(
                                  fontSize: 12,
                                  color: AppTheme.textPrimary)),
                        ),
                      ],
                    ),
                  )),
          if (note.action.isNotEmpty) ...[
            const SizedBox(height: 4),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('🎯 ', style: TextStyle(fontSize: 12)),
                Expanded(
                  child: Text(note.action,
                      style: const TextStyle(
                          fontSize: 12, color: AppTheme.textPrimary)),
                ),
              ],
            ),
          ],
          if (note.favoriteQuote != null &&
              note.favoriteQuote!.isNotEmpty) ...[
            const SizedBox(height: 4),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('💬 ', style: TextStyle(fontSize: 12)),
                Expanded(
                  child: Text('「${note.favoriteQuote}」',
                      style: const TextStyle(
                          fontSize: 12,
                          fontStyle: FontStyle.italic,
                          color: AppTheme.textSecondary)),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
