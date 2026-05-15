# 月読命 — Phase A〜D テスト戦略書

> **対象現世**: tsundoku-quest-flutter
> **前提**: TDD（RED-GREEN-REFACTOR）、`flutter test --no-pub` 検証
> **現状**: 全139テスト通過（20ファイル）

---

## 0. 現状アーキテクチャ総覧

### 主要データフロー
```
UserBookRepository (abstract)
  └ MockUserBookRepository (in-memory, test/mocks/)
  └ SupabaseUserBookRepository (実装済)

ReadingSessionRepository (abstract) ← 定義済、実装未
  └ MockReadingSessionRepository (未作成)
  └ SupabaseReadingSessionRepository (未作成)

BookDataNotifier (StateNotifier) — 中央インメモリストア
  ├ UserBook操作: add/update/remove (透過的にSupabase同期)
  ├ Book操作: add/get (インメモリのみ)
  └ WarTrophy操作: add/get (インメモリのみ)

AdventurerNotifier (StateNotifier)
  ├ XP操作: addXp
  ├ カウント: incrementBooksRegistered/Completed
  ├ 読書統計: updateReadingStats({minutes, pages})
  └ ストリーク: updateStreak({current, longest})
```

### テストパターン（既存）
| パターン | 使用例 | 特徴 |
|---------|--------|------|
| 直接インスタンス化 | `BookDataNotifier()` | Repositoryなし、純粋ユニットテスト |
| ProviderContainer | `_copyNotifierState()` | Provider経由の状態検証 |
| ProviderScope + MaterialApp | `testBookshelfScreen()` | ウィジェットテスト用 |
| UncontrolledProviderScope | `testReadingScreen()` | 事前シードしたウィジェットテスト |
| Fake HTTP Client | `FakeClient` (route map) | API通信テスト |
| mocktail (未使用だが利用可能) | `pubspec.yaml` に依存 | 今後のモック戦略の選択肢 |

### 既存のギャップ
- `AdventurerStats` に `readingDates` フィールドがない
- `SupabaseReadingSessionRepository` が未実装
- `EditBookModal` / `ReadingCalendarWidget` が未実装
- `BookCard.onEdit` が `() {}` の空実装
- 削除機能のUI（確認ダイアログ・スナックバー）が未実装

---

## 1. Phase A — 読書セッション基盤

### 1.1 必要な新規ファイル

| ファイル | 分類 | テスト数 |
|---------|------|---------|
| `test/mocks/mock_reading_session_repository.dart` | モック | — |
| `test/features/reading/data/supabase_reading_session_repository_test.dart` | ユニット | 6〜8 |
| `test/features/reading/reading_screen_test.dart` 追記 | ウィジェット | +4 |
| `test/shared/providers/adventurer_provider_test.dart` 追記 | ユニット | +3 |

### 1.2 MockReadingSessionRepository

**実装方針**: `MockUserBookRepository` と同様のインメモリ方式。seed/reset/shouldThrow を持つ。

```dart
class MockReadingSessionRepository implements ReadingSessionRepository {
  final List<ReadingSession> _store = [];
  bool shouldThrow = false;

  void seed(List<ReadingSession> sessions) => _store.addAll(sessions);
  void reset() => _store.clear();

  @override
  Future<ReadingSession> startSession(String userBookId, int startPage) async {
    if (shouldThrow) throw Exception('Mock error');
    final session = ReadingSession(
      id: 'session-${DateTime.now().millisecondsSinceEpoch}',
      userBookId: userBookId,
      startedAt: DateTime.now().toUtc().toIso8601String(),
      startPage: startPage,
      createdAt: DateTime.now().toUtc().toIso8601String(),
    );
    _store.add(session);
    return session;
  }

  @override
  Future<ReadingSession> endSession(String sessionId, int endPage, int durationMinutes) async {
    if (shouldThrow) throw Exception('Mock error');
    final idx = _store.indexWhere((s) => s.id == sessionId);
    if (idx < 0) throw Exception('Session not found');
    final old = _store[idx];
    final updated = ReadingSession(
      id: old.id, userBookId: old.userBookId,
      startedAt: old.startedAt,
      endedAt: DateTime.now().toUtc().toIso8601String(),
      startPage: old.startPage, endPage: endPage,
      durationMinutes: durationMinutes,
      createdAt: old.createdAt,
    );
    _store[idx] = updated;
    return updated;
  }

  // getByUserBook, getRecentSessions も同様に
}
```

### 1.3 SupabaseReadingSessionRepository ユニットテスト

**テストケース一覧**:

| # | ケース名 | RED条件 | GREEN条件 |
|---|---------|---------|----------|
| 1 | `startSession: creates session with correct fields` | `expect(session.userBookId, 'ub-1')` | `SupabaseClient.from('reading_sessions').insert()` を呼ぶ実装 |
| 2 | `startSession: returns session with non-null startedAt` | `expect(session.startedAt, isNotNull)` | 同上 |
| 3 | `endSession: updates endedAt, endPage, durationMinutes` | `expect(updated.endedAt, isNotNull)` | `SupabaseClient.from('reading_sessions').update()` を呼ぶ |
| 4 | `endSession: preserves original startedAt and startPage` | `expect(updated.startPage, old.startPage)` | 破壊的更新を防ぐコピー |
| 5 | `getByUserBook: returns sessions for given userBookId` | `expect(sessions.length, 2)` | `select().eq('userBookId', id)` |
| 6 | `getRecentSessions: returns limited sessions ordered by createdAt` | `expect(sessions.length, <= limit)` | `select().order('createdAt', ascending: false).limit(limit)` |
| 7 | `getByUserBook: empty list when no sessions` | `expect(sessions, isEmpty)` | 空リスト返却 |

**モック戦略**: `supabaseClientProvider` を `ProviderScope.overrides` で差し替え。
SupabaseClientの`from()` が返す `PostgrestQueryBuilder` をモックするか、
Repositoryクラス自体に `client` をコンストラクタ注入して単体テスト可能にする。

**推奨**: コンストラクタ注入方式（既存の `SupabaseUserBookRepository` パターンに準拠）

### 1.4 ReadingScreen 追加テストケース

| # | ケース名 | アサーション | 注入方法 |
|---|---------|------------|---------|
| 1 | 読書セッション開始時に `startSession` が呼ばれる | `verify(() => mockRepo.startSession(any(), any()))` | `readingSessionRepositoryProvider` override |
| 2 | 画面離脱時に `endSession` が呼ばれる | `verify(() => mockRepo.endSession(any(), any(), any()))` | `WidgetsBindingObserver.didChangeAppLifecycleState` をトリガー |
| 3 | `endSession` 時に `AdventurerNotifier.updateReadingStats` が呼ばれる | `expect(adventurer.totalReadingMinutes, > 0)` | ProviderContainer で状態確認 |
| 4 | 読了時にセッション終了 | `verify(() => mockRepo.endSession(any(), any(), any()))` | 完了ボタンタップ後 |

**既存影響**: `testReadingScreen()` 関数は `ProviderScope` を使っていないため、
`ReadingSessionRepository` の注入経路を追加する必要がある。
→ `ProviderScope.overrides` を使う形にリファクタ推奨。

### 1.5 AdventurerProvider 追加テストケース

| # | ケース名 | 期待値 |
|---|---------|--------|
| 1 | `updateReadingStats` で `totalReadingMinutes` が加算される | `30 + 45 = 75` |
| 2 | `updateReadingStats` で `totalPagesRead` が加算される | `15 + 20 = 35` |
| 3 | `readingDates` が追加される（新フィールド） | 今日の日付が含まれる |

**既存影響**: `AdventurerStats` に `readingDates` フィールド追加必須。
`AdventurerStats.beginner()` で空リスト `const []` で初期化。
全既存テストは `readingDates` を無視するため変更不要（copyWith で対応）。

### 1.6 エッジケース（Phase A）

| エッジケース | テスト方法 | 期待動作 |
|------------|-----------|---------|
| 読書時間0分のセッション（開始→即終了） | `durationMinutes: 0` で `endSession` | 正常終了、統計は加算0でよい |
| ページ数が前回より減った場合 | `currentPage` が減少する更新 | 0でクランプ（要バリデーション追加） |
| Supabase未接続時 | `shouldThrow = true` | エラーログ出力、UIはインメモリで継続 |

---

## 2. Phase B — 読書カレンダー

### 2.1 必要な新規ファイル

| ファイル | 分類 | テスト数 |
|---------|------|---------|
| `lib/features/history/presentation/widgets/reading_calendar_widget.dart` | プロダクション | — |
| `test/features/history/widgets/reading_calendar_widget_test.dart` | ウィジェット | 4〜6 |
| `test/features/history/history_screen_test.dart` | ウィジェット | 3 |

### 2.2 ReadingCalendarWidget 仕様

**Props**:
```dart
class ReadingCalendarWidget extends StatelessWidget {
  final List<DateTime> readingDates; // 読書した日付のリスト
  final int displayDays; // 表示日数（デフォルト30）
}
```

**内部状態不要**: pure function → StatelessWidget で十分。

### 2.3 ReadingCalendarWidget テストケース

| # | テスト名 | セットアップ | 期待アサーション |
|---|---------|------------|----------------|
| 1 | 30日分のセルが表示される | `readingDates: [today]` | `find.byType(Container)` 30個 |
| 2 | 読書あり日が緑色 | `readingDates: [today.sub(3.days)]` | 該当セルの色 `Colors.green` |
| 3 | 今日が橙色 | `readingDates: []` | 今日のセル色 `Colors.orange` |
| 4 | 空の `readingDates` で全セルがグレー | `readingDates: []` | 全セルの色 `Colors.grey` |
| 5 | 連続読書日が正しくハイライト | `readingDates: [d1, d2, d3]` | 3日連続緑 |
| 6 | 先月の日付も正しく表示 | `displayDays: 60` | タイトルに月名表示 |

**エッジケース**:
- `readingDates` に未来の日付が含まれる → 未来日は無視
- `readingDates` に重複日付 → 重複除去して表示
- `displayDays` が0以下 → 空ウィジェット or 1日にフォールバック

### 2.4 HistoryScreen 追加テスト

| # | テスト名 | アサーション |
|---|---------|------------|
| 1 | ReadingCalendarWidget が表示される | `find.byType(ReadingCalendarWidget)` |
| 2 | 読書カレンダーのプレースホルダーが置き換わる | 「カレンダー機能は今後実装予定」が非表示に |
| 3 | readingDates が空の場合もカレンダーが崩れない | 全セルグレーでレイアウト維持 |

**適応パターン**: `AdventurerStats.readingDates` からカレンダーにデータ供給。
`history_screen_test.dart` では `ProviderScope.overrides` で `adventurerProvider` を差し替え。

---

## 3. Phase C — 蔵書編集モーダル

### 3.1 必要な新規ファイル

| ファイル | 分類 | テスト数 |
|---------|------|---------|
| `lib/features/bookshelf/presentation/widgets/edit_book_modal.dart` | プロダクション | — |
| `test/features/bookshelf/widgets/edit_book_modal_test.dart` | ウィジェット | 4〜5 |
| `test/features/bookshelf/bookshelf_screen_test.dart` 追記 | ウィジェット | +1 |

### 3.2 EditBookModal 仕様

```dart
class EditBookModal extends ConsumerStatefulWidget {
  final UserBook userBook;
  const EditBookModal({super.key, required this.userBook});
}
```

**編集項目**:
- 媒体選択（BookMedium → SegmentedButton）
  - physical / ebook / audiobook
- 評価（星タップ 1〜5）
- 保存ボタン → `bookDataProvider.notifier.updateUserBook`
- キャンセルボタン → `Navigator.pop`

### 3.3 EditBookModal テストケース

| # | テスト名 | 操作 | 期待 |
|---|---------|------|------|
| 1 | 媒体選択SegmentedButtonが表示される | 初期描画 | `find.byType(SegmentedButton<BookMedium>)` が `findsOneWidget` |
| 2 | 評価タップで正しい値が選択される | 3つ目の星タップ | 選択された評価が3 |
| 3 | 保存ボタンで `updateUserBook` が呼ばれる | 保存タップ | `bookDataProvider.state` が更新される |
| 4 | キャンセルでモーダルが閉じる | キャンセルタップ | `Navigator.pop` 相当、モーダルが非表示に |
| 5 | 媒体変更後保存で新しい値が反映される | ebook選択→保存 | `state.userBook.medium == BookMedium.ebook` |

**エッジケース**:
- 評価範囲外（0や6）→ SegmentedButtonは範囲内のみ選択可能、バリデーション追加
- 未実施 → 評価nullのまま保存可能

### 3.4 BookshelfScreen 追加テスト

| # | テスト名 | 操作 | 期待 |
|---|---------|------|------|
| 1 | onEditタップでEditBookModalが表示される | `find.byIcon(Icons.more_vert)` タップ | `find.byType(EditBookModal)` が表示 |

**既存影響**:
- `BookCard.onEdit: () {}` → `BookCard.onEdit: () => _showEditModal(book)` に変更
- BookshelfScreenがEditBookModalをインポート

---

## 4. Phase D — 蔵書削除機能

### 4.1 必要な変更

| ファイル | 変更内容 |
|---------|---------|
| `lib/features/bookshelf/presentation/widgets/book_card.dart` | `onDelete` コールバック追加（削除アイコン） |
| `lib/features/bookshelf/presentation/bookshelf_screen.dart` | 削除確認ダイアログ → `removeUserBook` → スナックバー |
| `test/features/bookshelf/bookshelf_screen_test.dart` 追記 | +4テスト |

### 4.2 BookCard の変更

```dart
class BookCard extends StatelessWidget {
  final UserBook book;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback? onDelete; // 追加

  // more_vert アイコンのポップアップメニューに「削除」を追加
}
```

**または**: `onEdit` をポップアップメニューに変更し、編集/削除を内包。

### 4.3 BookshelfScreen 追加テストケース

| # | テスト名 | 操作 | 期待 |
|---|---------|------|------|
| 1 | 削除アイコンタップで確認ダイアログ表示 | 削除アイコンタップ | `find.byKey(AppKeys.confirmDialog)` |
| 2 | 確認ダイアログ「削除する」で `removeUserBook` 呼出 | 確認ボタンタップ | 蔵書リストから当該IDが削除 |
| 3 | 削除後スナックバー表示 | 確認後 | `find.text('「本のタイトル」を削除しました')` |
| 4 | キャンセルで削除されない | キャンセルボタンタップ | 蔵書リストに当該IDが残存 |

**エッジケース**:
- 削除対象の本が存在しない → `removeUserBook` は単に何もしない（既にガード済）
- 削除後のSupabase同期失敗 → スナックバーにエラー表示（エラーハンドリング追加）
- 削除実行中に二度タップ → 最初の削除のみ有効（ガード推奨）

---

## 5. 既存テストへの影響 総括表

| 変更内容 | 影響ファイル | 変更の種類 | 影響度 |
|---------|------------|-----------|--------|
| `AdventurerStats.readingDates` 追加 | `test/shared/models/other_models_test.dart` | 既存テストにfield追加アサート？ → 非破壊 | **低** |
| `AdventurerStats.beginner()` に `readingDates: const []` | 同上 | factory修正 | **低**（全テストが `beginner()` を使うため自動反映） |
| `AdventurerNotifier.updateReadingStats` に `readingDates` 追加 | `test/shared/providers/adventurer_provider_test.dart` | 新テスト追加（既存は破壊しない） | **低** |
| `ReadingScreen` での `ReadingSessionRepository` 注入 | `test/features/reading/reading_screen_test.dart` | test helper 関数のリファクタ必須 | **中** |
| `HistoryScreen` での `ReadingCalendarWidget` 組み込み | `test/features/history/history_screen_test.dart`（新規） | 新規ファイル | **低** |
| `BookCard.onDelete` 追加 | 既存 `BookCard` テストがない | 新規テスト作成 | **低** |
| `BookshelfScreen` 編集/削除ロジック追加 | `test/features/bookshelf/bookshelf_screen_test.dart` | 既存テストに影響なし（新ケース追加のみ） | **低** |

### 5.1 ReadingScreen テストのリファクタ方針

**問題**: 現在の `testReadingScreen()` は `UncontrolledProviderScope` で独自に `ProviderContainer` を生成。
`readingSessionRepositoryProvider` の override 経路がない。

**解決策**: `ProviderScope.overrides` を使う形に統合。

```dart
// BEFORE (current)
Widget testReadingScreen({String? id}) {
  final container = ProviderContainer();
  // ... seed data ...
  return UncontrolledProviderScope(
    container: container,
    child: MaterialApp(home: ReadingScreen(id: id)),
  );
}

// AFTER (overrides-based)
Widget testReadingScreen({
  String? id,
  ReadingSessionRepository? sessionRepo,
}) {
  final container = ProviderContainer(
    overrides: [
      if (sessionRepo != null)
        readingSessionRepositoryProvider.overrideWithValue(sessionRepo),
    ],
  );
  // ... seed data via container.read(bookDataProvider.notifier) ...
  return UncontrolledProviderScope(
    container: container,
    child: MaterialApp(home: ReadingScreen(id: id)),
  );
}
```

---

## 6. TDD 実装順序（推奨）

### Phase A 実装順（RED→GREEN→REFACTOR のサイクル）

```
Cycle A-1: AdventurerStats.readingDates 追加
  [RED]   test: other_models_test で readingDates 確認テスト
  [GREEN] lib: AdventurerStats に field + beginner() 修正
  [REFACTOR] field 追加のみ、変更なし

Cycle A-2: AdventurerNotifier.readingDates 更新
  [RED]   test: adventurer_provider_test に readingDates テスト追加
  [GREEN] lib: updateReadingStats で readingDates 更新ロジック
  [REFACTOR] 同上

Cycle A-3: MockReadingSessionRepository
  [RED]   テスト兼モック → 直接作成（モックはテスト支援コード）
  [GREEN] test/mocks/mock_reading_session_repository.dart 作成
  [REFACTOR] 同上

Cycle A-4: SupabaseReadingSessionRepository のユニットテスト
  [RED]   supabase_reading_session_repository_test.dart 作成
  [GREEN] 該当Repository実装
  [REFACTOR] エラーハンドリング統一

Cycle A-5: ReadingScreen + セッション連携
  [RED]   reading_screen_test.dart にセッション系テスト追加（先にリファクタ）
  [GREEN] ReadingScreen で startSession/endSession 呼び出し
  [REFACTOR] clean up
```

### Phase B 実装順

```
Cycle B-1: ReadingCalendarWidget
  [RED]   reading_calendar_widget_test.dart 作成（4〜6ケース）
  [GREEN] reading_calendar_widget.dart 実装
  [REFACTOR] UI調整のみ

Cycle B-2: HistoryScreen + Calendar連携
  [RED]   history_screen_test.dart 作成（3ケース）
  [GREEN] HistoryScreen で ReadingCalendarWidget 組み込み
  [REFACTOR] プレースホルダー削除
```

### Phase C 実装順

```
Cycle C-1: EditBookModal
  [RED]   edit_book_modal_test.dart 作成（4〜5ケース）
  [GREEN] edit_book_modal.dart 実装
  [REFACTOR] UI/バリデーション調整

Cycle C-2: BookshelfScreen + EditBookModal連携
  [RED]   bookshelf_screen_test.dart に追記テスト
  [GREEN] BookshelfScreen で onEdit → EditBookModal 表示
  [REFACTOR] 同上
```

### Phase D 実装順

```
Cycle D-1: BookCard.onDelete 追加
  [RED]   book_card_test.dart があれば追記（なければskip）
  [GREEN] BookCard に削除アイコン追加
  [REFACTOR] 同上

Cycle D-2: BookshelfScreen 削除フロー
  [RED]   bookshelf_screen_test.dart に削除系テスト追加（4ケース）
  [GREEN] BookshelfScreen で確認ダイアログ + removeUserBook + スナックバー
  [REFACTOR] エラーハンドリング
```

---

## 7. 全テスト数見積もり

| Phase | 新規テスト | 既存修正テスト | 合計増加 |
|-------|-----------|---------------|---------|
| Phase A | 13〜15 | 1（reading_screen helper） | +13〜15 |
| Phase B | 7〜9 | 0 | +7〜9 |
| Phase C | 5〜6 | 0 | +5〜6 |
| Phase D | 4 | 0 | +4 |
| **合計** | **29〜34** | **1** | **+29〜34** |

**完了時予測**: 168〜173 テスト全通過（`flutter test --no-pub`）

---

## 8. リスクと注意点

### 8.1 リスク: `AdventurerStats.readingDates` の型設計

現在 `AdventurerStats` はプリミティブのみ。`readingDates` は `List<DateTime>` とするか、
`List<String>`（ISO8601文字列）とするか。

**推奨**: `List<DateTime>`（純粋Dart層なのでFlutter非依存でOK）。JSONシリアライズは
`toIso8601String()` で対応。`AdventurerStats` はJSONシリアライズを持たないので問題なし。

### 8.2 リスク: `ReadingScreen` のLifecycle管理

`endSession` を画面離脱時に呼ぶには `WidgetsBindingObserver` の
`didChangeAppLifecycleState` をハンドリングする必要がある。
`ConsumerState` で `dart:async` の `WidgetsBindingObserver` をミックスイン。

### 8.3 リスク: 既存テストへの副作用

`AdventurerStats.beginner()` ファクトリの修正は全テストに波及するが、
`readingDates: const []` の追加のみであり、既存アサーションには影響しない。
安全に追加可能。

### 8.4 注意: `mocktail` の活用判断

既存の `MockUserBookRepository` は手書きモック。`mocktail` パッケージが
`pubspec.yaml` の `dev_dependencies` にあるため、`MockReadingSessionRepository` は
`mocktail` の `Mock` クラスで生成する選択肢もある。

**推奨**: 一貫性のため手書きモック継続。MockUserBookRepository と同じパターンに従う。
macktail は複雑なスタブが必要になった場合のみ導入を検討。

---

以上、月読命からの奏上を終える。
