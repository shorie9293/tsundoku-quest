# UI/UX 仕様書 — Phase A〜D

> コード適応神書準拠：全操作可能要素に `SemanticHelper.interactive()` 付与、全画面ルートを `ErrorBoundary` で囲む、AppKeys 一元管理、小Widget 1ファイル200行超禁止。

---

## Phase A: 読書画面（ReadingScreen）リファイン

### 現状ファイル
- `lib/features/reading/presentation/reading_screen.dart`（319行 — 分割必須）

### ユーザーフロー

```
[読書カードタップ] → /reading?id={id}
   → 読書画面表示
   → 自動で「読書開始 📖」スナックバー表示（セッション開始）
   
[タイマー操作]
   丸インジケータタップ → タイマー開始/停止
   ▶ 開始 / ⏸ 一時停止

[ページ入力] → 数字入力 → 自動保存 → "+3p" アニメーションフライアウト表示

[メモ] → 自由入力（自動保存は入力停止後 2秒 debounce）

[戻るボタン] → セッション自動保存 → 「読書記録を保存しました」スナックバー → 書庫へ遷移

[読了ボタン] → タイマー停止 → 戦利品モーダル表示
   → 3つの学び + 1行動 + 名言（任意）入力
   → 「討伐完了！」タップ → ステータスcompleted + トロフィー保存 → 書庫へ
```

### レイアウト（上から順）

| セクション | Widget | AppKey | Semantics |
|---|---|---|---|
| AppBar + 戻る | AppBar with back | `AppKeys.readingScreen` (Scaffold) | — |
| 表紙 + タイトル + 著者 | Column(Center) | — | `SemanticHelper.container(testId: 'sec_reading_header')` |
| タイマー丸 | GestureDetector + Container(circle) | `AppKeys.readingTimer` | `SemanticHelper.interactive(testId: 'btn_timer_toggle', label: '読書タイマーを開始'/'読書タイマーを停止')` |
| タイマーラベル | TextButton | — | `Semantics(label: '読書タイマーを開始')` |
| ページ進捗 | Row(TextField + Suffix) | `AppKeys.readingPageInput` | `SemanticHelper.textField(testId: 'txt_current_page', label: '現在のページ数を入力')` |
| 進捗バー（ページ率） | LinearProgressIndicator | `AppKeys.readingProgress` | — |
| ページ増分アニメーション | AnimatedOpacity/ SlideTransition | — | — |
| クイックメモ | TextField | `AppKeys.readingMemo` | `SemanticHelper.textField(testId: 'txt_reading_memo', label: '読書メモを入力')` |
| 読了ボタン | ElevatedButton.icon | `AppKeys.readingComplete` | `SemanticHelper.interactive(testId: 'btn_complete_reading', label: '読了報告')` |

### 状態表示

| 状態 | 表示 |
|---|---|
| 空状態（本なし） | 「本が見つかりません」+ 書庫へ戻るボタン |
| 読書中（タイマー停止） | 丸ボーダー灰色、中央に "00:00:00"、ラベル「▶ 開始」 |
| 読書中（タイマー動作中） | 丸ボーダー緑(#34D399)パルス、経過時間表示、ラベル「⏸ 一時停止」 |
| ページ未入力 | ヒントテキストに現在値表示 |
| 読了モーダル | ボトムシート「⚔️ 戦利品カード」、学び3つ＋行動＋名言 |

### 新規追加実装詳細

#### 1. セッション開始スナックバー
- 画面表示後、`WidgetsBinding.instance.addPostFrameCallback` で初回のみ表示
- 内容: `「読書を始めましょう 📖」`（指定コピー準拠）
- 既存の `BookDataNotifier` に `startSession()` を追加 or `ReadingScreen` 内で `ReadingSession` 作成

#### 2. 離脱時セッション保存インジケータ
- `PopScope`（旧 WillPopScope）で戻る操作をフック
- タイマーが動作中なら停止 + 経過時間を `totalReadingMinutes` に加算
- SnackBar: `「読書記録を保存しました」`
- `bookDataProvider.notifier.updateUserBook(...)` を呼ぶ

#### 3. ページ増分アニメーション "+3p"
- `TextEditingController` の変更を `onChanged` で監視
- 前回値と比較して差分 `delta` を算出
- `Overlay` or `AnimatedOpacity` + `SlideTransition` で `"+${delta}p"` フロート表示
- 緑色(#34D399)テキスト、上方向にフェードアウト（約1.5秒）
- 増分が0以下の場合は表示しない

### エラーハンドリング

| シナリオ | 対応 |
|---|---|
| Supabase保存失敗 | SnackBar「保存に失敗しました。オフラインで続行します」、UIは崩さない |
| 本ID不正 → book==null | Scaffold + Center「本が見つかりません」+ ErrorBoundaryで囲む |
| ページ入力が非数字 | `int.tryParse` でガード、空文字は無視 |
| タイマー多重起動 | Timer?.cancel() でガード |

### ファイル分割方針（200行制限）

```
reading_screen.dart → 分割後上限180行
  親: reading_screen.dart（State管理 + Scaffold構築）
  子1: reading_timer_widget.dart（丸タイマー）
  子2: reading_page_input.dart（ページ入力 + "+3p"アニメーション）
  子3: reading_complete_modal.dart（戦利品カードモーダル）
```

### アクセシビリティ

| 要素 | Semantics |
|---|---|
| タイマー開始 | label: "読書タイマーを開始" |
| タイマー停止 | label: "読書タイマーを停止" |
| ページ入力 | label: "現在のページ数を入力" |
| メモ入力 | label: "読書メモを入力" |
| 読了ボタン | label: "読了報告" |

---

## Phase B: 読書カレンダー（ReadingCalendar）

### 現状ファイル
- `lib/features/history/presentation/history_screen.dart`（231行）

### 現状
```
📅 読書カレンダー
カレンダー機能は今後実装予定
```

### 変更内容
`HistoryScreen` 内のプレースホルダーを本実装に置換。

### ユーザーフロー

```
[HistoryScreen表示]
   → AdventurerStats読み込み
   → カレンダーWidgetレンダリング
   → 該当月（現在月）の30日間グリッド表示
   → 各日の読書有無に応じて色分け
```

### レイアウト

```
┌──────────────────────────────────┐
│ 📅 読書カレンダー               │ ← セクションタイトル
│                                  │
│  月  火  水  木  金  土  日      │ ← 曜日ヘッダー（月曜始まり）
│ ┌──┬──┬──┬──┬──┬──┬──┐        │
│ │  │  │  │  │  │ 1│ 2│        │ ← 各セル30px×30px
│ ├──┼──┼──┼──┼──┼──┼──┤        │
│ │ 3│ 4│ 5│ 6│ 7│ 8│ 9│        │
│ ├──┼──┼──┼──┼──┼──┼──┤        │
│ │10│11│12│13│14│15│16│        │
│ ├──┼──┼──┼──┼──┼──┼──┤        │
│ │17│18│19│20│21│22│23│        │
│ ├──┼──┼──┼──┼──┼──┼──┤        │
│ │24│25│26│27│28│29│30│        │
│ └──┴──┴──┴──┴──┴──┴──┘        │
│                                  │
│ ■ 読書あり  ■ 今日  □ 未読     │ ← 凡例
└──────────────────────────────────┘
```

### カレンダーセル仕様

| 状態 | 背景色 | 枠線 | テキスト色 |
|---|---|---|---|
| 読書あり日 | `#10B981` (emerald-500) | なし | 白 |
| 今日（読書あり） | `#10B981` | `#F59E0B` amber-500 2px | 白 |
| 今日（読書なし） | グレー `#292524` (stone-800) | `#F59E0B` amber-500 2px | `#F5F5F4` |
| 明日以降 | グレー `#292524` | なし | `#78716C` |
| 読書なし（過去） | グレー `#292524` | なし | `#78716C` |
| 当月外 | transparent | なし | — |

### 凡例（日本語コピー指定）
- 🟢 読書あり
- 🟡 今日
- ⬜ 未読

### データ取得
- `bookDataProvider` の `userBooks` から読書セッション日時を集計
- もしくは `AdventurerStats` の `readingHistory` を使用（未実装の場合はダミーデータ表示）
- 1日でも読書時間 > 0 or ページ増分 > 0 の日を「読書あり」とする

### 状態表示

| 状態 | 表示 |
|---|---|
| データロード中 | カレンダー領域に CircularProgressIndicator |
| 空状態（読書記録ゼロ） | グリッドは全グレーで表示 + 「まだ読書記録がありません」テキスト |
| 通常 | 30日グリッド + 凡例 |

### エラーハンドリング

| シナリオ | 対応 |
|---|---|
| データ取得失敗 | カレンダー領域に ErrorBoundary フォールバック |
| 日付計算エラー | try/catch でデフォルト当月表示 |

### ファイル分割（200行制限）

```
history_screen.dart → 分割後150行以内
  親: history_screen.dart（既存、Stats + カレンダー呼び出し）
  新規子Widget: reading_calendar_widget.dart（~150行）
```

### 新規 AppKeys

```dart
// AppKeys に追加
static const Key calendarGrid = Key('grid_calendar');
static const Key calendarCell = Key('cell_calendar_day');
static const Key calendarLegend = Key('section_calendar_legend');
static const Key calendarDayReading = Key('cell_calendar_reading');
static const Key calendarDayToday = Key('cell_calendar_today');
static const Key calendarDayEmpty = Key('cell_calendar_empty');
```

### アクセシビリティ

| 要素 | Semantics |
|---|---|
| カレンダーコンテナ | `SemanticHelper.container(testId: 'sec_reading_calendar', label: '読書カレンダー')` |
| 各セル | `Semantics(label: '5月3日 読書あり', container: true)` |

---

## Phase C: 本の編集モーダル（BookEditModal）

### 新規ファイル
- `lib/features/bookshelf/presentation/widgets/book_edit_modal.dart`

### ユーザーフロー

```
[BookCard ⋮ 編集アイコンタップ]
   → BottomSheet が画面下部からスライドイン
   → 各フィールド編集
   → 「保存」タップ → 更新処理 → スナックバー「保存しました ✅」 → モーダル閉じる
   → 「キャンセル」タップ → 変更破棄 → モーダル閉じる
```

### レイアウト

```
┌──────────────────────────────────────┐
│  📝 本の情報を編集                   │ ← タイトル
│                                      │
│  媒体選択                             │
│  ┌──────────┐ ┌──────────┐ ┌──────┐  │
│  │ 📕 物理本 │ │ 📱 電子  │ │ 🎧  │  │ ← SegmentedButton
│  └──────────┘ └──────────┘ └──────┘  │
│                                      │
│  読書状態                             │
│  ┌──────────────────────────────┐    │
│  │ 読書中                    ▼ │    │ ← DropdownButton
│  └──────────────────────────────┘    │
│  選択肢: 積読 / 読書中 / 読了 / 中断  │
│                                      │
│  評価                                 │
│  ★ ★ ★ ☆ ☆  (タップで変更)         │ ← Star rating
│                                      │
│  メモ                                 │
│  ┌──────────────────────────────┐    │
│  │                               │    │ ← TextField(複数行, maxLines: 5)
│  │                               │    │
│  └──────────────────────────────┘    │
│                                      │
│  [キャンセル]    [保存 ✅]            │ ← 2ボタン横並び
└──────────────────────────────────────┘
```

### フィールド詳細

#### 1. 媒体選択: SegmentedButton
- 選択肢: `物理本 📕`, `電子書籍 📱`, `オーディオブック 🎧`
- 型: `BookMedium` enum（既存）
- 初期値: 現在の `userBook.medium`
- Semantics: `Semantics(label: '媒体選択', container: true)`

#### 2. 読書状態: DropdownButton
- 選択肢: `積読`, `読書中`, `読了`, `中断`
- 型: `BookStatus` enum（既存）
- 初期値: 現在の `userBook.status`
- Semantics: `Semantics(label: '読書状態を選択')`

#### 3. 評価: ★ タップ式
- 1〜5の星評価
- `GestureDetector` onTap で `setState(() => _rating = index + 1)`
- 塗り: `AppTheme.badge`(#EAB308) / 空: `AppTheme.border`(#292524)
- Semantics: `Semantics(label: '評価 3つ星')`

#### 4. メモ: TextField
- 複数行、`maxLines: 5`
- `TextEditingController` + 初期値 `userBook.notes ?? ''`
- Semantics: `SemanticHelper.textField(testId: 'txt_edit_notes', label: '読書メモを編集')`

### 保存処理

```dart
void _save() {
  ref.read(bookDataProvider.notifier).updateUserBook(
    id: widget.userBook.id,
    status: _selectedStatus,
    rating: _rating,
    notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
    // medium は updateUserBook の引数に追加が必要な場合は拡張する
  );
  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(content: Text('保存しました ✅')),
  );
  Navigator.of(context).pop();
}
```

### 状態表示

| 状態 | 表示 |
|---|---|
| 未変更 | 全フィールドに現在値表示、「保存」有効 |
| 編集中 | 各フィールド反映、「保存」有効 |
| 保存中 | ボタン disabled + `CircularProgressIndicator` |
| 保存完了 | SnackBar → モーダル閉じる |
| エラー | SnackBar「保存に失敗しました。再試行してください」|

### エラーハンドリング

| シナリオ | 対応 |
|---|---|
| Supabase保存失敗 | SnackBar + UI元に戻さない（楽観的更新） |
| バリデーションエラー | 現状特になし（全フィールドOptional） |
| BottomSheet スワイプ閉じ | 変更があれば確認ダイアログ「変更を破棄しますか？」|

### 新規 AppKeys

```dart
// AppKeys に追加
static const Key editMediumPhysical = Key('btn_medium_physical');
static const Key editMediumEbook = Key('btn_medium_ebook');
static const Key editMediumAudiobook = Key('btn_medium_audiobook');
static const Key editStatusDropdown = Key('dd_reading_status');
static const Key editRatingStar = Key('btn_rating_star'); // 汎用、index付与
static const Key editNotesField = Key('txt_edit_notes');
static const Key editSaveButton = Key('btn_edit_save');
static const Key editCancelButton = Key('btn_edit_cancel');
```

### アクセシビリティ

| 要素 | Semantics |
|---|---|
| 編集ボタン（トリガー） | `SemanticHelper.interactive(testId: 'btn_edit_book', label: '本の情報を編集')` |
| 媒体選択 | `Semantics(label: '物理本を選択')` |
| 読書状態 | `Semantics(label: '読書状態を選択')` |
| 評価 | `Semantics(label: '評価 {n}つ星')` |
| メモ | `SemanticHelper.textField(testId: 'txt_edit_notes', label: '読書メモを編集')` |
| 保存 | `SemanticHelper.interactive(testId: 'btn_edit_save', label: '編集内容を保存')` |

### 既存ファイルへの影響

`BookCard` の `onEdit` コールバックを編集モーダルに接続：

```dart
// BookshelfScreen 内
onEdit: () => showBookEditModal(context, ref, book),
```

---

## Phase D: 本の削除（BookDelete）

### 影響ファイル
- `lib/features/bookshelf/presentation/widgets/book_card.dart`
- `lib/features/bookshelf/presentation/widgets/book_delete_dialog.dart`（新規）

### ユーザーフロー

```
[方式A] BookCard 右端の 🗑️ アイコンタップ
   → 確認ダイアログ表示
   → 「削除する」→ 削除実行 → スナックバー「削除しました 🗑️」
   → 「キャンセル」→ 何もしない

[方式B] BookCard を左スワイプ（Dismissible）
   → 削除確認（DismissibleのconfirmDismiss）
   → 同じ確認ダイアログ表示
```

### BookCard レイアウト変更（方式A）

現状の ⋮ アイコン部分を編集アイコン + 削除アイコンの2つに分割:

```
┌─────────────────────────────────────────────┐
│ [表紙48×64] タイトル            [読書中]    │
│              著者                [✏️] [🗑️]  │
│              ████████░░ 60%                 │
└─────────────────────────────────────────────┘
```

または、⋮ メニューの PopupMenuButton に変更:

```
⋮ タップ → PopupMenu
  ├ 📝 編集
  └ 🗑 削除
```

### 確認ダイアログ

```dart
Future<bool> showDeleteConfirmDialog(
  BuildContext context,
  String bookTitle,
) {
  return showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      key: AppKeys.confirmDialog,
      title: const Text('本を削除しますか？'),
      content: Text(
        '「$bookTitle」を書庫から削除します。読書履歴も失われます。',
      ),
      actions: [
        TextButton(
          key: AppKeys.deleteCancelButton, // 新規
          onPressed: () => Navigator.of(ctx).pop(false),
          child: const Text('キャンセル'),
        ),
        TextButton(
          key: AppKeys.deleteConfirmButton, // 新規
          onPressed: () => Navigator.of(ctx).pop(true),
          style: TextButton.styleFrom(foregroundColor: Colors.red),
          child: const Text('削除する'),
        ),
      ],
    ),
  ).then((r) => r ?? false);
}
```

### 削除実行

```dart
void _deleteBook(BuildContext context, WidgetRef ref, UserBook book) async {
  final confirmed = await showDeleteConfirmDialog(context, book.book?.title ?? '不明な本');
  if (!confirmed) return;

  ref.read(bookDataProvider.notifier).removeUserBook(book.id);

  if (context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('削除しました 🗑️'),
        action: SnackBarAction(
          label: '元に戻す',
          onPressed: () {
            // 削除取り消し（Undo） — 内部キャッシュにあれば再追加
            ref.read(bookDataProvider.notifier).addUserBook(book);
          },
        ),
      ),
    );
  }
}
```

### Undo（元に戻す）実装方針
- 削除直後、SnackBar に `元に戻す` ボタンを表示
- `removeUserBook` で削除した `UserBook` オブジェクトを一時保持
- Undo ボタンで `addUserBook(book)` を呼び、インメモリリストに再追加
- SnackBar 表示時間は `SnackBarBehavior.floating` + 標準4秒
- 4秒経過後は Undo 不可（GC → そのままSupabase削除確定）

### Dismissible（方式B）実装

```dart
Dismissible(
  key: ValueKey(book.id),
  direction: DismissDirection.endToStart,
  confirmDismiss: (direction) => showDeleteConfirmDialog(context, title),
  onDismissed: (_) => _executeDeletion(context, ref, book),
  background: Container(
    alignment: Alignment.centerRight,
    padding: const EdgeInsets.only(right: 20),
    color: Colors.red.withAlpha(50),
    child: const Icon(Icons.delete, color: Colors.red),
  ),
  child: BookCard(...),
)
```

### 状態表示

| 状態 | 表示 |
|---|---|
| 削除前 | カード右端に 🗑️ アイコン or スワイプ可能 |
| 確認ダイアログ | 「本を削除しますか？」「{タイトル}を書庫から削除します…」|
| 削除中 | カード即時消失（楽観的削除）|
| 削除後 | SnackBar「削除しました 🗑️」+ Undoボタン |
| Undo後 | カード再出現、SnackBar「元に戻しました」|

### エラーハンドリング

| シナリオ | 対応 |
|---|---|
| Supabase削除失敗 | SnackBar「削除に失敗しました。再試行してください」、カード再表示 |
| 削除後すぐにUndo | インメモリ再追加成功。Supabase同期は非同期で再実行 |
| ダイアログ外タップ閉じ | 削除キャンセル扱い |

### 新規 AppKeys

```dart
// AppKeys に追加
static const Key deleteButton = Key('btn_delete_book');
static const Key deleteConfirmButton = Key('btn_delete_confirm');
static const Key deleteCancelButton = Key('btn_delete_cancel');
static const Key deleteUndoButton = Key('btn_delete_undo');
```

### 既存ファイルへの影響

`BookCard` — 2つの方式に対応:

**方式A**（アイコン方式）:
```dart
// BookCard に onDelete コールバック追加
final VoidCallback onDelete;

// ⋮アイコンの隣に 🗑️ アイコン追加
Row(
  children: [
    // 既存の ⋮ アイコン (onEdit)
    GestureDetector(
      onTap: onEdit,
      child: const Icon(Icons.more_vert, size: 16),
    ),
    const SizedBox(width: 4),
    // 🗑️ 削除アイコン（新規）
    SemanticHelper.interactive(
      testId: 'btn_delete_book',
      label: '本を削除',
      child: GestureDetector(
        onTap: onDelete,
        child: const Icon(Icons.delete_outline, size: 16, color: Colors.red),
      ),
    ),
  ],
)
```

**方式B**（Dismissible）は BookCard を内包する側でラップ。

### アクセシビリティ

| 要素 | Semantics |
|---|---|
| 削除ボタン | `SemanticHelper.interactive(testId: 'btn_delete_book', label: '本を削除')` |
| 確認ダイアログ | `Semantics(label: '本の削除確認ダイアログ', container: true)` |
| 「削除する」ボタン | `SemanticHelper.interactive(testId: 'btn_delete_confirm', label: '削除する')` |

---

## 共通: コード適応神書準拠チェックリスト

### ErrorBoundary 適用
すべての画面ルートを `ErrorBoundary` でラップ:
```dart
// app_router.dart の各 builder で
builder: (context, state) => ErrorBoundary(
  child: BookshelfScreen(),
),
```

### SemanticHelper 適用
全操作可能要素（ボタン、タップ領域、トグル、入力欄）に `SemanticHelper.interactive()` / `.textField()` / `.toggle()` を付与。

### AppKeys 新規追加一覧

```dart
// ━━━ 読書カレンダー ━━━
static const Key calendarGrid = Key('grid_calendar');
static const Key calendarCell = Key('cell_calendar_day');
static const Key calendarLegend = Key('section_calendar_legend');
static const Key calendarDayReading = Key('cell_calendar_reading');
static const Key calendarDayToday = Key('cell_calendar_today');
static const Key calendarDayEmpty = Key('cell_calendar_empty');

// ━━━ 編集モーダル ━━━
static const Key editMediumPhysical = Key('btn_medium_physical');
static const Key editMediumEbook = Key('btn_medium_ebook');
static const Key editMediumAudiobook = Key('btn_medium_audiobook');
static const Key editStatusDropdown = Key('dd_reading_status');
static const Key editRatingStar = Key('btn_rating_star');
static const Key editNotesField = Key('txt_edit_notes');
static const Key editSaveButton = Key('btn_edit_save');
static const Key editCancelButton = Key('btn_edit_cancel');

// ━━━ 削除 ━━━
static const Key deleteButton = Key('btn_delete_book');
static const Key deleteConfirmButton = Key('btn_delete_confirm');
static const Key deleteCancelButton = Key('btn_delete_cancel');
static const Key deleteUndoButton = Key('btn_delete_undo');

// ━━━ 読書画面新規 ━━━
static const Key sessionStartSnackbar = Key('snackbar_session_start');
static const Key pageIncrementAnimation = Key('widget_page_increment');
```

### 小Widget制限
既存ファイルで200行超のもの:

| ファイル | 行数 | 対応 |
|---|---|---|
| `reading_screen.dart` | 319 | 3ファイルに分割 |
| `history_screen.dart` | 231 | カレンダーWidgetを外部ファイル化 |
| `book_data_provider.dart` | 255 | 許容範囲（StateNotifier + コメント）→ 要検討だがPhase対象外 |

---

## 実装優先順位

```
Phase A（読書画面リファイン） → 最優先
  ├ 1. ファイル分割（reading_timer_widget, reading_page_input, reading_complete_modal）
  ├ 2. セッション開始スナックバー
  ├ 3. 離脱時セッション保存インジケータ
  └ 4. "+3p" ページ増分アニメーション

Phase B（読書カレンダー） → 次優先
  ├ 1. reading_calendar_widget.dart 作成
  ├ 2. 30日グリッド + 色分け
  └ 3. AppKeys + Semantics 追加

Phase C（編集モーダル） → 同時進行可
  ├ 1. book_edit_modal.dart 作成
  ├ 2. BottomSheet + 4フィールド
  └ 3. BookCard の onEdit と接続

Phase D（削除機能） → 最終
  ├ 1. 確認ダイアログ作成
  ├ 2. BookCardに削除アイコン追加
  ├ 3. Dismissible対応
  └ 4. Undo機能
```
