# 月読命 — Supabase Phase 2-4 QA分析書

> **対象現世**: tsundoku-quest-flutter
> **前提**: TDD（RED-GREEN-REFACTOR）、`flutter test --no-pub` 検証
> **現状**: 全167試験通過（23ファイル）
> **現状ドキュメント**: `phase_a_d_test_strategy.md`（Phase A-Dの詳細計画）
> **作成日**: 令和八年皐月八日

---

## 目次

1. Phase 2-4のTDDフェーズ分け
2. Supabaseテストのモック戦略
3. RLSポリシーテストの方法
4. バーコードスキャンのE2Eテスト戦略
5. 回帰テストの自動化方針
6. エッジケース一覧
7. 品質ゲートの閾値設定

---

## 1. Phase 2-4のTDDフェーズ分け (RED→GREEN→REFACTOR計画)

### Phase 2: Supabase CRUD 基盤（全Repository完了）

Phase A-D（既存計画書）でカバー済の基盤に加え、不足Repositoryを補完する。

#### Sub-phase 2a: AuthRepository & AdventurerRepository（新規）

```
Cycle 2a-1: MockAuthRepository
  [RED]   test/mocks/mock_auth_repository.dart を作成（テスト支援コードのため直接GREEN）
  [GREEN] MockUserBookRepository と同じインメモリパターンで実装
  [REFACTOR] Interface変更時に追随

Cycle 2a-2: AuthRepository ユニットテスト（Supabase経由）
  [RED]   test/features/shared/data/supabase_auth_repository_test.dart を作成
           テストケース:
           - signInAnonymously: calls client.auth.signInAnonymously()
           - signOut: calls client.auth.signOut()
           - currentUser: returns correct user
           - authStateChanges: emits on auth state change
  [GREEN] 既存 SupabaseAuthRepository は完成済みだが、テストがないため追加
  [REFACTOR] エラーハンドリング確認

Cycle 2a-3: MockAdventurerRepository
  [RED]   test/mocks/mock_adventurer_repository.dart を作成
  [GREEN] インメモリ実装（stats, addXp, updateReadingStats, etc.）
  [REFACTOR] 同上

Cycle 2a-4: AdventurerRepository ユニットテスト
  [RED]   test/features/shared/data/supabase_adventurer_repository_test.dart
           テストケース:
           - stats: returns AdventurerStats correctly
           - addXp: updates xp value
           - updateReadingStats: aggregates minutes/pages
           - incrementBooksRegistered: increments counter
           - incrementBooksCompleted: increments counter
           - updateStreak: calculates streak correctly
  [GREEN] SupabaseAdventurerRepository 実装（新規）
  [REFACTOR] calculate_streak 関数との整合性確認
```

#### Sub-phase 2b: WarTrophyRepository（新規）

```
Cycle 2b-1: MockWarTrophyRepository
  [RED]   test/mocks/mock_war_trophy_repository.dart を作成
  [GREEN] インメモリ実装
  [REFACTOR] 同上

Cycle 2b-2: WarTrophyRepository ユニットテスト
  [RED]   test/features/shared/data/supabase_war_trophy_repository_test.dart
           テストケース:
           - getMyTrophies: returns user's trophies
           - createTrophy: inserts new trophy
           - updateTrophy: updates existing trophy
           - getMyTrophies: empty list when no trophies
  [GREEN] SupabaseWarTrophyRepository 実装（新規）
  [REFACTOR] エラーハンドリング
```

#### Sub-phase 2c: BookDataNotifier 透過型永続化テスト

```
Cycle 2c: 透過型永続化結合テスト
  [RED]   test/shared/providers/book_data_provider_test.dart に追記
           - addBook → Supabaseに同期される（MockRepository経由）
           - updateUserBook → Supabaseに同期される
           - removeUserBook → Supabaseから削除される
           - fetchBooks → Supabaseからロードされる
           - リポジトリなし（null）でもクラッシュしない
           - Supabaseエラー時もインメモリは維持される
  [GREEN] BookDataNotifier（既存実装）。テスト追加のみ
  [REFACTOR] エラーハンドリング統一
```

#### Sub-phase 2d: ReadingSessionRepository 完成（既存計画から継続）

```
Cycle 2d-1: MockReadingSessionRepository
  [RED]   テスト兼モック → 直接作成（モックはテスト支援コード）
  [GREEN] test/mocks/mock_reading_session_repository.dart 作成
  [REFACTOR] 同上

Cycle 2d-2: SupabaseReadingSessionRepository ユニットテスト
  [RED]   test/features/reading/data/supabase_reading_session_repository_test.dart
           - startSession: creates session with correct fields
           - startSession: returns session with non-null startedAt
           - endSession: updates endedAt, endPage, durationMinutes
           - endSession: preserves original startedAt and startPage
           - getByUserBook: returns sessions for given userBookId
           - getRecentSessions: returns limited sessions ordered by createdAt
           - getAllReadingDates: returns unique sorted dates
           - getTotalReadingMinutes: aggregates minutes
           - getByUserBook: empty list when no sessions
  [GREEN] SupabaseReadingSessionRepository（既存実装済 + getAllReadingDates）
  [REFACTOR] null安全チェック強化
```

### Phase 2 テスト数見積もり

| カテゴリ | 新規テスト | 追記テスト |
|---------|-----------|-----------|
| AuthRepository | 4 | 0 |
| AdventurerRepository | 6 | 0 |
| WarTrophyRepository | 4 | 0 |
| BookDataNotifier（透過型） | 0 | 6 |
| ReadingSessionRepository | 9 | 0 |
| **Phase 2 合計** | **23** | **6** |

---

### Phase 3: バーコードスキャン（カメラモック）

#### Sub-phase 3a: スキャン基盤（MobileScannerモック戦略確立）

```
Cycle 3a-1: スキャン画面のテスト基盤
  [RED]   既存 explore_screen_test.dart を分析。MobileScanner のモック方法を確立
  [GREEN] test/features/explore/explore_screen_scan_test.dart（新規）
          テストヘルパー:
          - FakeMobileScanner: MobileScanner をラップしたFakeWidget
          - BarcodeCapture の生成ヘルパー
          - onDetect コールバックの注入方法
  [REFACTOR] テストヘルパーの共通化
```

**MobileScanner モック戦略の詳細**:

`mobile_scanner` パッケージはプラットフォームネイティブコード（カメラ）に依存するため、
単体テスト環境では `MobileScanner` ウィジェットをレンダリングできない。

**推奨戦略（3案）:**

| # | 戦略 | メリット | デメリット | 選択 |
|---|------|---------|-----------|------|
| 1 | `MobileScanner` をラップした `BarcodeScannerWidget` を作成し、テスト時に差し替え | テスト容易性が高い | プロダクションコードに間接層が増える | ★推奨 |
| 2 | `ProviderScope.overrides` で Widget を差し替え | プロダクションコード変更不要 | Provider経由は Widget 差し替えに不向き | 非推奨 |
| 3 | `mobile_scanner` パッケージ自体を依存関係から条件付き除外 | クリーン | 複雑 | 非推奨 |

**採用: 戦略1 — BarcodeScannerWidget ラッパー**

```dart
// lib/features/explore/presentation/widgets/barcode_scanner_widget.dart
class BarcodeScannerWidget extends StatelessWidget {
  final Function(BarcodeCapture) onDetect;
  final MobileScannerController? controller;

  const BarcodeScannerWidget({
    super.key,
    required this.onDetect,
    this.controller,
  });

  @override
  Widget build(BuildContext context) {
    return MobileScanner(
      key: AppKeys.scanPreview,
      controller: controller,
      onDetect: onDetect,
    );
  }
}

// test/features/explore/widgets/fake_barcode_scanner_widget.dart
class FakeBarcodeScannerWidget extends StatelessWidget {
  final Function(BarcodeCapture) onDetect;
  final void Function(String? rawValue)? onBarcodeDetected;

  const FakeBarcodeScannerWidget({
    super.key,
    required this.onDetect,
    this.onBarcodeDetected,
  });

  @override
  Widget build(BuildContext context) {
    // Simplified widget for testing — just a container that fires onDetect
    return GestureDetector(
      onTap: () {
        final capture = BarcodeCapture(
          barcodes: [
            Barcode(rawValue: '9784000000000', format: BarcodeFormat.ean13),
          ],
          image: null,
        );
        onDetect(capture);
      },
      child: const SizedBox(width: 300, height: 200),
    );
  }
}
```

#### Sub-phase 3b: バーコード検出ハンドラーユニットテスト

```
Cycle 3b: _onBarcodeDetected ユニットテスト
  [RED]   test/features/explore/explore_screen_handler_test.dart
           テストケース:
           - null rawValue → 何もしない（_isScanning が false）
           - 空文字 rawValue → 何もしない
           - 有効ISBN → bookSearchService.lookupByIsbn が呼ばれる
           - 同一ISBNの重複検出（2500ms以内）→ 2回目は無視
           - 同一ISBNでも時間経過後（2500ms超）→ 再度検出可能
           - lookupByIsbn 成功 → addBook が呼ばれる
           - lookupByIsbn 失敗（null）→ SnackBar 表示
           - lookupByIsbn で例外 → SnackBar にエラー表示
  [GREEN] ExploreScreen._onBarcodeDetected（既存実装）。テスト追加のみ
  [REFACTOR] エラーメッセージの国際化対応
```

#### Sub-phase 3c: スキャンタブUIテスト

```
Cycle 3c: スキャンタブUIテスト
  [RED]   explore_screen_test.dart にスキャンタブテスト追記
           - スキャンタブ選択で FakeBarcodeScannerWidget が表示される
           - 選択中インジケーター（CircularProgressIndicator）表示
           - 通常時ガイドテキスト表示
  [GREEN] ExploreScreen（既存実装に BarcodeScannerWidget 組み込み）
  [REFACTOR] UI定数抽出
```

#### Sub-phase 3d: 手入力タブISBNテスト

```
Cycle 3d: 手入力ISBNテスト
  [RED]   explore_screen_test.dart に手入力テスト追記
           - ISBN入力→手動submit→UserBook作成
           - タイトル空欄→submitできない
           - 著者カンマ区切り→正しくパースされる
  [GREEN] ExploreScreen._onManualSubmit（既存実装）
  [REFACTOR] 同上
```

### Phase 3 テスト数見積もり

| カテゴリ | 新規テスト | 追記テスト |
|---------|-----------|-----------|
| BarcodeScannerWidget（プロダクションコード） | — | — |
| 検出ハンドラーユニット | 9 | 0 |
| スキャンタブUI | 0 | 4 |
| 手入力タブ | 0 | 3 |
| **Phase 3 合計** | **9** | **7** |

---

### Phase 4: 検索・推薦（APIモック）

#### Sub-phase 4a: 外部APIモック完成（一部既存）

既存Fake: `FakeRakutenApi`, `FakeOpenBDApi`, `FakeGoogleBooksApi`（`book_search_service_test.dart` に定義）

**APIクライアント自体の単体テスト（まだ未実施）:**

```
Cycle 4a-1: RakutenApi 単体テスト
  [RED]   test/shared/repositories/rakuten_api_test.dart を新規作成
           テストケース:
           - search: HTTP GET 呼び出し確認
           - lookupByIsbn: HTTP GET 呼び出し確認
           - search: レスポンスパース確認
           - search: APIエラー → 空リスト
           - lookupByIsbn: null response → null
           - search: 空クエリ → 空リスト
  [GREEN] RakutenApi（既存実装）
  [REFACTOR] エラーハンドリング

Cycle 4a-2: OpenBDApi 単体テスト
  [RED]   test/shared/repositories/openbd_api_test.dart を新規作成
           テストケース:
           - lookupByIsbn: HTTP GET 呼び出し
           - lookupByIsbn: レスポンスパース
           - lookupByIsbn: 該当なし → null
           - lookupByIsbn: ネットワークエラー → null
  [GREEN] OpenBDApi（既存実装）
  [REFACTOR] 同上

Cycle 4a-3: GoogleBooksApi 単体テスト
  [RED]   test/shared/repositories/google_books_api_test.dart を新規作成
           テストケース:
           - search: HTTP GET 呼び出し
           - lookupByIsbn: HTTP GET 呼び出し
           - search: レスポンスパース確認
           - search: API制限エラー → 空リスト
           - lookupByIsbn: null response → null
  [GREEN] GoogleBooksApi（既存実装）
  [REFACTOR] 同上
```

**HTTPクライアントモック戦略:**

```dart
// 既存 FakeClient パターンを流用
class FakeHttpClient extends http.Client {
  final Map<String, http.Response> _routeMap;

  FakeHttpClient(this._routeMap);

  @override
  Future<http.Response> get(Uri url, {Map<String, String>? headers}) async {
    final uri = url.toString();
    for (final entry in _routeMap.entries) {
      if (uri.contains(entry.key)) {
        return entry.value;
      }
    }
    return http.Response('{}', 404);
  }
}
```

#### Sub-phase 4b: BookSearchService 充実テスト

```
Cycle 4b: BookSearchService 網羅テスト
  [RED]   book_search_service_test.dart にテスト追加（既存17ケースから拡充）
           不足テスト:
           - 全APIフォールバックチェーンが時間内に完了する（タイムアウト確認）
           - API障害時にグレースフルデグラデーション
           - クエリ前後の空白トリム
           - 空文字クエリ → 空リスト
           - 超長文字列クエリ（1000文字以上）
           - 特殊文字（絵文字、HTMLタグ）
           - ISBNのハイフン除去 → 正規化検証
  [GREEN] BookSearchService（既存実装）
  [REFACTOR] バリデーション強化
```

#### Sub-phase 4c: 検索タブUIテスト

```
Cycle 4c: 検索タブUIテスト
  [RED]   explore_screen_test.dart に検索タブテスト追記
           テストケース:
           - 検索タブ選択でTextFieldが表示される
           - 検索フィールドに文字列入力可能
           - onSubmitted で BookSearchService.search が呼ばれる
           - 検索結果リスト表示
           - 検索結果タップで登録確認
           - 検索結果0件 → 「見つかりませんでした」メッセージ
           - 検索中ローディングインジケーター
  [GREEN] ExploreScreen._buildSearchTab（既存実装 + 検索結果表示実装）
  [REFACTOR] 検索ロジックのカスタムフック抽出
```

#### Sub-phase 4d: 推薦ロジックテスト（Phase 4の拡張）

※ 推薦機能は Phase 4 後半で実装される想定。現状のコードベースには推薦ロジックなし。

```
Cycle 4d: 推薦ロジック（設計段階）
  [PLAN]  推薦アルゴリズムの設計:
           - 積読状態の本からランダム推薦
           - 未読カテゴリ優先
           - 最近追加した本を優先
           - 完了率の低い本を優先
  [RED]   test/features/explore/recommendation_test.dart
           テストケース:
           - 積読本のみから推薦される
           - 既読本は推薦されない
           - 空の蔵書 → 推薦なし
           - 1冊のみ → その本が推薦される
           - 同一著者の本を優先（オプション）
  [GREEN] lib/features/explore/domain/recommendation_service.dart（新規）
  [REFACTOR] アルゴリズム抽出
```

### Phase 4 テスト数見積もり

| カテゴリ | 新規テスト | 追記テスト |
|---------|-----------|-----------|
| RakutenApi 単体 | 6 | 0 |
| OpenBDApi 単体 | 4 | 0 |
| GoogleBooksApi 単体 | 5 | 0 |
| BookSearchService 拡充 | 0 | 8 |
| 検索タブUI | 0 | 7 |
| 推薦ロジック | 5 | 0 |
| **Phase 4 合計** | **20** | **15** |

---

### 全Phase テスト数サマリー

| Phase | 新規ファイル | 新規テスト | 追記テスト | 累計テスト数 |
|-------|------------|-----------|-----------|------------|
| 既存 (Phase 0) | 23 | 167 | — | 167 |
| Phase 2 (Supabase CRUD) | 5 | 23 | 6 | 196 |
| Phase 3 (Barcode Scan) | 1 | 9 | 7 | 212 |
| Phase 4 (Search/Recommend) | 4 | 20 | 15 | 247 |
| **総計** | **33** | **219** | **28** | **247（推定）** |

---

## 2. Supabaseテストのモック戦略

### 2.1 三層モック戦略

```
┌────────────────────────────────────────────┐
│ Layer 1: インメモリMockRepository          │
│ 用途: 全Widgetテスト・Providerテスト       │
│ 既存: MockUserBookRepository (49行)        │
│ 新規: MockAuthRepository                   │
│       MockAdventurerRepository             │
│       MockWarTrophyRepository              │
│       MockReadingSessionRepository         │
│ 特徴: seed()/reset()/shouldThrow 統一      │
└────────────────────────────────────────────┘
                      │
                      ▼
┌────────────────────────────────────────────┐
│ Layer 2: Fake SupabaseClient              │
│ 用途: Repositoryユニットテスト            │
│ 方法: SupabaseClient をコンストラクタ注入  │
│       from() が返す PostgrestQueryBuilder  │
│       はモックせず、SupabaseClient全体を   │
│       ダブル（Fake）に差し替え             │
│ ★ 制約: チェーン可能ビルダーはモック不可   │
└────────────────────────────────────────────┘
                      │
                      ▼
┌────────────────────────────────────────────┐
│ Layer 3: 実Supabase (supabase local)      │
│ 用途: 結合テスト・RLS検証                 │
│ 方法: supabase start でローカルDB起動      │
│       migration apply してテストデータ投入 │
│ 対象: CI上で週1回 or PR merge前            │
└────────────────────────────────────────────┘
```

### 2.2 Layer 1: インメモリMockRepository 統一パターン

```dart
// 全MockRepositoryが従う統一インターフェース
abstract class MockRepositoryBase<T> {
  final List<T> _store = [];
  bool shouldThrow = false;

  void seed(List<T> items) => _store.addAll(items);
  void reset() => _store.clear();

  /// 全てのMockRepositoryに共通のエラー注入機構
  /// shouldThrow = true の時、全操作が Exception('Mock error') をスロー
}
```

**各MockRepositoryの責務:**

| MockRepository | 既存 | 型パラメータ | seedデータ例 |
|---------------|------|-------------|-------------|
| MockUserBookRepository | ✅ | UserBook | `seed([userBook1, userBook2])` |
| MockReadingSessionRepository | 未 | ReadingSession | `seed([session1])` |
| MockAuthRepository | 未 | — | state管理のみ（seed不要） |
| MockAdventurerRepository | 未 | — | `stats(AdventurerStats)` |
| MockWarTrophyRepository | 未 | WarTrophy | `seed([trophy1])` |

### 2.3 Layer 2: Fake SupabaseClient 戦略

**制約: 「Supabaseモックは深追いしない（チェーン可能ビルダーはモック不可）」**

この制約を尊重し、以下の方針とする：

```dart
// ❌ 非推奨: PostgrestQueryBuilderのチェーンをモック
when(() => mockClient.from('user_books').select().order('created_at', ascending: false))
    .thenReturn([...]);

// ✅ 推奨: Repository全体をFakeする（最小限の実装）
class FakeSupabaseUserBookRepository implements UserBookRepository {
  // インメモリ実装（MockUserBookRepositoryと同等）
  // ただし、Supabaseの実際の振る舞い（RLS、UUID生成等）を模倣
}
```

**Repositoryユニットテストでは:**

**方針A（推奨）:** Repositoryを直接テスト対象とし、SupabaseClient を `FakeSupabaseClient`（手書きの最小実装）に差し替える。
既存の `SupabaseUserBookRepository` はコンストラクタで `SupabaseClient` を受け取る設計になっているため、
この方法が最もクリーン。

```dart
class FakeSupabaseClient extends Fake implements SupabaseClient {
  @override
  // ignore: overridden_fields
  late final SupabaseGoTrueAuth auth = FakeSupabaseAuth();

  @override
  SupabaseQueryBuilder from(String table) {
    return FakeSupabaseQueryBuilder(table);
  }
}
```

**方針B（代替）:** Repository層を介さず、`BookDataNotifier` の透過永続化をテストする。
この場合、`MockUserBookRepository` を注入して、`addUserBook` 後に `_repository.addBook` が呼ばれたことを確認する。

**推奨: 方針Aを基本とし、方針Bを結合テストで併用。**

### 2.4 Layer 3: Supabase Local 結合テスト

```dart
// integration_test/supabase_crud_test.dart
// 重要: integration_test/ ディレクトリは未作成。新規追加が必要。
// flutter test integration_test/ で実行（実DBが必要）

void main() {
  late SupabaseClient client;

  setUpAll(() async {
    client = SupabaseClient(
      'http://127.0.0.1:54321',  // supabase local
      supabaseAnonKey,            // local anon key
    );
    // 匿名認証
    await client.auth.signInAnonymously();
  });

  tearDownAll(() async {
    await client.auth.signOut();
  });

  group('UserBook CRUD (実DB)', () {
    test('should insert and retrieve user_book', () async { /* ... */ });
    test('should enforce RLS for user isolation', () async { /* ... */ });
    test('should cascade delete reading_sessions', () async { /* ... */ });
  });
}
```

---

## 3. RLSポリシーテストの方法

### 3.1 テスト対象RLSポリシー一覧

Supabaseマイグレーション (`001_initial_schema.sql`) で定義されたRLS:

| テーブル | ポリシー | 動作 |
|---------|---------|------|
| `books` | 誰でも参照可能 | `SELECT` は全ユーザー許可 |
| `books` | 認証ユーザーのみ登録 | `INSERT` は authenticated のみ |
| `user_books` | 自分の蔵書のみ参照/追加/更新/削除 | `auth.uid() = user_id` |
| `reading_sessions` | 自分のセッションのみ参照/追加 | `user_books.user_id = auth.uid()` |
| `war_trophies` | 自分の戦利品のみ参照/追加/更新 | `auth.uid() = user_id` |
| `reading_goals` | 自分の目標のみ参照/追加/更新 | `auth.uid() = user_id` |
| `collections` | 自分のコレクションのみ全操作 | `auth.uid() = user_id` |
| `collection_items` | 自分のコレクションアイテムのみ | 間接的に `collections.user_id` |

### 3.2 RLSテスト方法（3段階）

#### Stage 1: SQL直接検証（開発環境）

```sql
-- supabase/seed_rls_test.sql
-- テストユーザー作成（migrationではやらない、手動 or seed.sql）

-- 検証1: anon（未認証）は user_books を読めない
SET LOCAL ROLE anon;
SELECT * FROM user_books LIMIT 1;
-- → ERROR: new row violates row-level security policy

-- 検証2: ユーザーAはユーザーBの蔵書を見れない
-- （psql or pgTAP で実行）
```

#### Stage 2: pgTAP（PostgreSQLテストフレームワーク）

```sql
-- supabase/pgtap/rls_test.sql
BEGIN;
SELECT plan(6);

-- anon key で user_books を参照不可
SET LOCAL ROLE anon;
SELECT throws_ok(
  'SELECT * FROM user_books LIMIT 1',
  '42501',
  'anon should not be able to select user_books'
);

-- authenticated ユーザーAは自分のデータのみ参照可
SET LOCAL ROLE authenticated;
SET "request.jwt.claims" TO '{"sub": "user-a"}';
SELECT lives_ok(
  'SELECT * FROM user_books WHERE user_id = ''user-a''',
  'user should be able to select own books'
);

ROLLBACK;
```

#### Stage 3: Flutter結合テスト（推奨: supabase local + integration_test）

```dart
// integration_test/rls_test.dart
void main() {
  late SupabaseClient clientA;
  late SupabaseClient clientB;

  setUpAll(() async {
    clientA = await _createAuthenticatedClient('user-a@test.com');
    clientB = await _createAuthenticatedClient('user-b@test.com');
  });

  test('User A cannot read User B books', () async {
    // Arrange: User A inserts a book
    final bookA = await clientA.from('user_books').insert({...}).select().single();
    
    // Act: User B tries to read it
    final result = await clientB.from('user_books').select().eq('id', bookA['id']);

    // Assert: RLS blocks it (returns empty)
    expect(result, isEmpty);
  });

  test('anon key cannot write to user_books', () async {
    final anonClient = SupabaseClient(supabaseUrl, anonKey);
    // anon client should NOT be authenticated
    
    expect(
      () async => await anonClient.from('user_books').insert({...}),
      throwsA(isA<PostgrestException>()),
    );
  });
}
```

### 3.3 CIでのRLSテスト実行計画

```yaml
# .github/workflows/rls-tests.yml (新規)
rls-tests:
  runs-on: ubuntu-latest
  services:
    postgres:
      image: supabase/postgres:15.1.1.49
      env:
        POSTGRES_PASSWORD: postgres
  steps:
    - uses: actions/checkout@v4
    - name: Setup pgTAP
      run: |
        psql -h localhost -U postgres -d postgres -f supabase/migrations/001_initial_schema.sql
        # pgTAP tests
    - name: Flutter integration tests
      if: github.ref == 'refs/heads/main'
      run: |
        supabase start
        flutter test integration_test/
```

---

## 4. バーコードスキャンのE2Eテスト戦略

### 4.1 テスト階層

```
Level 1: ユニットテスト（最優先、カバレッジ高）
  └ _onBarcodeDetected のロジックテスト（9ケース）

Level 2: ウィジェットテスト（中優先）
  └ FakeBarcodeScannerWidget + スキャンタブUI（4ケース）

Level 3: 統合テスト（低優先、CI週次）
  └ 実カメラは不要。BarcodeCapture データ注入で動作確認

Level 4: E2Eテスト（手動 or 実機）
  └ 実カメラ + 実バーコード。TestFlight/Beta 配布後
```

### 4.2 Level 1: ハンドラーロジックユニットテスト

```dart
// テスト対象: ExploreScreen._onBarcodeDetected
// 依存注入: bookSearchServiceProvider を Fake に差し替え

test('should debounce duplicate ISBN within 2500ms', () async {
  final container = ProviderContainer(overrides: [
    bookSearchServiceProvider.overrideWithValue(FakeBookSearchService()),
  ]);
  final screen = ExploreScreen();
  // pumpWidget etc...

  // First scan
  await tester.tap(find.byKey(AppKeys.scanPreview));
  await tester.pump();
  expect(find.text('検索中...'), findsOneWidget);

  // Immediate re-scan (same ISBN) — should be ignored
  await tester.tap(find.byKey(AppKeys.scanPreview));
  await tester.pump();
  // Still searching from first — no second call

  // Wait 2500ms
  await tester.pump(const Duration(milliseconds: 2600));
  // Now re-scan should work
  await tester.tap(find.byKey(AppKeys.scanPreview));
});
```

### 4.3 Level 2: BarcodeScannerWidget ラッパー

**設計判断:** `ExploreScreen` が直接 `MobileScanner` を使っている現状（`_buildScanTab` の L198-211）では、
テスト時にカメラウィジェットをレンダリングできない。

**リファクタ提案:**

```
現状:
  ExploreScreen._buildScanTab() → 直接 MobileScanner(...)

目標:
  ExploreScreen._buildScanTab() → BarcodeScannerWidget(onDetect: ..., controller: ...)
  
テスト時:
  ProviderScope.overrides で BarcodeScannerWidget を FakeBarcodeScannerWidget に差し替え
```

**BarcodeScannerWidgetProvider:**

```dart
// lib/features/explore/presentation/widgets/barcode_scanner_widget_provider.dart
final barcodeScannerWidgetProvider = Provider<BarcodeScannerWidgetBuilder>((ref) {
  return (Function(BarcodeCapture) onDetect, MobileScannerController? controller) {
    return BarcodeScannerWidget(onDetect: onDetect, controller: controller);
  };
});
```

### 4.4 スキャンE2Eシナリオ

| # | シナリオ | 前提 | 確認項目 |
|---|---------|------|---------|
| 1 | 正常ISBNスキャン | 楽天API稼働 | UserBook作成、書庫画面遷移 |
| 2 | 未知ISBNスキャン | 全APIがnull返却 | 「本が見つかりませんでした」SnackBar表示 |
| 3 | 連続スキャン | 同一ISBN | デバウンス動作、重複登録防止 |
| 4 | カメラ権限拒否 | 初回起動 | エラー表示（mobile_scanner依存） |
| 5 | ネットワーク切断 | スキャン後 | 「検索エラー」SnackBar表示 |

---

## 5. 回帰テストの自動化方針

### 5.1 自動化構成

```
GitHub Actions (quality-gates.yml) — 既存
├── static-analysis (5分)
│   └── dart analyze --fatal-infos --fatal-warnings
├── unit-tests (15分)
│   ├── rpg-task
│   └── tsundoku-quest-flutter ★ここが対象
│       └── flutter test --no-pub
└── code-adaptation (5分)
    ├── Semantics検証
    ├── AppKeys一意性
    ├── ErrorBoundary
    └── ファイルサイズ (200行超禁止)
```

### 5.2 回帰テスト実行タイミング

| トリガー | 対象テスト | 実行時間枠 | 優先度 |
|---------|-----------|-----------|--------|
| PR作成/更新 | 全ユニットテスト + 静的解析 | 即時（~15分） | P0 |
| PR merge to main | 同上 + 結合テスト | ~20分 | P0 |
| 日次（main） | 全テスト + 結合テスト | 深夜バッチ | P1 |
| 週次 | 全テスト + 結合テスト + RLSテスト | 週末 | P2 |
| リリース前 | 全テスト + 結合テスト + RLS + E2E | 手動トリガー | P0 |

### 5.3 テスト分割戦略

`flutter test --no-pub` が167テストで約3-5分。247テスト時は5-8分程度と見積もり。

**分割推奨:** テスト数200超えを機に分割を検討

```yaml
# quality-gates.yml の unit-tests ジョブ拡張案
unit-tests:
  strategy:
    matrix:
      world: [utsushiyo/rpg-task, utsushiyo/tsundoku-quest-flutter]
      test-group: [domain, features, core, integration]
  steps:
    - run: flutter test --no-pub test/${{ matrix.test-group }}/
```

ただし `flutter test --no-pub` は全テスト統合実行が基本のため、
現段階では分割より `--coverage` を優先する。

### 5.4 テスト品質メトリクス収集

```yaml
# quality-gates.yml 追加案
- name: Generate coverage report
  run: |
    flutter test --no-pub --coverage
    flutter pub global run coverage:format_coverage --lcov --in=coverage/ --out=coverage/lcov.info

- name: Upload coverage to Codecov
  uses: codecov/codecov-action@v4
  with:
    files: utsushiyo/tsundoku-quest-flutter/coverage/lcov.info
    flags: tsundoku-quest
    fail_ci_if_error: false
```

---

## 6. エッジケース一覧

### 6.1 Phase 2: Supabase CRUD エッジケース

| # | カテゴリ | エッジケース | テスト方法 | 期待動作 |
|---|---------|------------|-----------|---------|
| E2-1 | ネットワーク | Supabase接続断 | `shouldThrow = true` | インメモリで継続、state.errorMessage 設定 |
| E2-2 | ネットワーク | 認証トークン期限切れ | Fakeで401返却 | 再認証 or エラーメッセージ |
| E2-3 | データ | 空の蔵書リスト | seed空配列 | `getMyBooks()` → `[]`、UIは空状態表示 |
| E2-4 | データ | 存在しないIDで更新/削除 | `updateBook('invalid-id')` | 何もしない（エラーは握りつぶす） |
| E2-5 | データ | 重複ISBNで書籍登録 | `upsert` 呼び出し | 既存レコード更新（UPSERT動作） |
| E2-6 | データ | 大量データ（1000件） | seed 1000件 | パフォーマンス劣化なし（ページネーション要検討） |
| E2-7 | 認証 | 匿名認証失敗 | `signInAnonymously()` 例外 | エラー表示、代替フロー |
| E2-8 | 認証 | 同時ログイン（2端末） | 状態同期 | 楽観的ロック（最終書き込み優先） |
| E2-9 | RLS | 他ユーザーデータの参照 | 別ユーザーIDでSELECT | 空リスト返却（RLSブロック） |
| E2-10 | RLS | 未認証でのINSERT | anon key | PostgrestException |

### 6.2 Phase 3: バーコードスキャン エッジケース

| # | カテゴリ | エッジケース | テスト方法 | 期待動作 |
|---|---------|------------|-----------|---------|
| E3-1 | 入力 | null rawValue | `onDetect(BarcodeCapture(barcodes: [Barcode(rawValue: null)]))` | スキップ、_isScanning 変化なし |
| E3-2 | 入力 | 空文字 rawValue | `Barcode(rawValue: '')` | スキップ |
| E3-3 | 入力 | 13桁ISBN（正常） | `9784000000000` | lookupByIsbn 呼び出し |
| E3-4 | 入力 | 10桁ISBN | `4000000000` | lookupByIsbn 呼び出し |
| E3-5 | 入力 | ISBNでないバーコード | `BarcodeFormat.qrCode` など | 検索実行（fallback動作確認） |
| E3-6 | 入力 | 超長文字列（EAN-128など） | 50文字以上 | そのまま検索、API側で処理 |
| E3-7 | タイミング | 連続スキャン（同一ISBN、2500ms以内） | 2回連続検出 | 2回目無視 |
| E3-8 | タイミング | 連続スキャン（同一ISBN、2500ms超） | 3秒後に再検出 | 再度lookupByIsbn呼び出し |
| E3-9 | タイミング | 高速連続スキャン（異なるISBN） | 3種のISBNを500ms間隔 | 逐次処理（前のリクエスト完了後に次） |
| E3-10 | API | lookUpByIsbn成功 | fake returns Book | addBook + 画面遷移 |
| E3-11 | API | lookUpByIsbn未発見 | fake returns null | SnackBar + 1.5秒待機後スキャン再開 |
| E3-12 | API | lookUpByIsbn例外（ネットワーク） | fake throws | SnackBarエラー + スキャン再開 |
| E3-13 | API | 全APIフォールバック（Rakuten→OpenBD→Google） | 段階的null返却 | 3段階フォールバック確認 |
| E3-14 | ライフサイクル | スキャン中に画面離脱 | `dispose()` | scannerController.dispose() 呼び出し |
| E3-15 | ライフサイクル | スキャン中にアプリバックグラウンド | lifecycle event | 処理中断、復帰後再開 |
| E3-16 | カメラ | カメラ権限未許可 | mobile_scanner error | エラーUI表示 |
| E3-17 | カメラ | カメラ初期化失敗 | controller.start() 例外 | エラーSnackBar |
| E3-18 | 重複防止 | 既に蔵書にある本をスキャン | same book_id exists | 重複登録防止 or 確認ダイアログ |

### 6.3 Phase 4: 検索・推薦 エッジケース

| # | カテゴリ | エッジケース | テスト方法 | 期待動作 |
|---|---------|------------|-----------|---------|
| E4-1 | 入力 | 空文字クエリ | `search('')` | 空リスト or バリデーションエラー |
| E4-2 | 入力 | 半角スペースのみ | `search('   ')` | 空リスト |
| E4-3 | 入力 | 超長クエリ（1000文字） | `search('a'*1000)` | エラーなく検索（API次第） |
| E4-4 | 入力 | 特殊文字（絵文字） | `search('📚テスト')` | URLエンコード後検索 |
| E4-5 | 入力 | SQLインジェクション的クエリ | `search(\"'; DROP TABLE books;\")` | 文字列として検索 |
| E4-6 | 入力 | HTMLタグ含む | `search('<script>alert()</script>')` | 文字列として検索 |
| E4-7 | API | Rakuten API制限（429） | Fake 429返却 | OpenBDにフォールバック |
| E4-8 | API | 全API制限（3つとも429） | 3連続429 | ユーザーに「制限中」表示 |
| E4-9 | API | Rakuten応答遅延（10秒） | タイムアウト | Googleにフォールバック（時間節約） |
| E4-10 | API | 不正JSONレスポンス | `response body: 'invalid json'` | パースエラー→そのAPIはスキップ |
| E4-11 | API | 空のレスポンスボディ | `response body: ''` | 空リストとして処理 |
| E4-12 | API | 検索結果0件（全API） | 3APIとも空リスト | 「見つかりませんでした」表示 |
| E4-13 | ISBN | 不完全ISBN（12桁） | `123456789012` | ISBNと認識されず通常検索 |
| E4-14 | ISBN | 15桁の数字 | `123456789012345` | 通常検索として処理 |
| E4-15 | ISBN | ハイフン+スペース混在ISBN | `978-4-00-000000-0` | トリム→正規化→13桁ISBN検出 |
| E4-16 | 推薦 | 空蔵書での推薦 | 0件 | 「推薦できる本がありません」 |
| E4-17 | 推薦 | 全完読状態 | 全status=completed | 推薦候補なし（積読本がない） |
| E4-18 | 推薦 | 1冊のみの推薦 | seed1件 | その1冊が推薦される |
| E4-19 | 推薦 | 同一ISBN異なる媒体 | physical + ebook | 重複除去 or 両方表示 |
| E4-20 | UI | 検索中ローディング | `isLoading = true` | CircularProgressIndicator 表示 |
| E4-21 | UI | 検索中に検索タブ切り替え | search → scan | リクエストキャンセル or 無視 |
| E4-22 | UI | 手動登録 タイトル空欄 | 必須バリデーション | submitボタン無効 or SnackBar |

### 6.4 クロスカッティングエッジケース

| # | カテゴリ | エッジケース | 影響Phase |
|---|---------|------------|----------|
| EC-1 | オフライン | 端末が完全オフライン | Phase 2-4 全て |
| EC-2 | メモリ | 低メモリ状態での画像キャッシュ | Phase 3（カメラ） |
| EC-3 | バッテリー | 低バッテリーモード | Phase 3（カメラ起動抑制） |
| EC-4 | 画面回転 | スキャン中の画面回転 | Phase 3 |
| EC-5 | マルチウィンドウ | 分割画面での動作 | Phase 3（カメラプレビュー縮小） |
| EC-6 | アクセシビリティ | スクリーンリーダー対応 | Phase 3-4 全て |
| EC-7 | 地域 | 日本のみで動作するAPI | Phase 4（楽天APIの地域制限） |
| EC-8 | 時刻 | 日付跨ぎのストリーク計算 | Phase 2（calculate_streak関数） |

---

## 7. 品質ゲートの閾値設定

### 7.1 カバレッジ目標

| メトリクス | 現状（推定） | 目標（Phase 2-4完了時） | ストレッチ目標 |
|-----------|------------|----------------------|--------------|
| ラインカバレッジ | ~60% | **75%** | 85% |
| ファンクションカバレッジ | ~70% | **80%** | 90% |
| ブランチカバレッジ | ~50% | **65%** | 75% |
| 新規コードカバレッジ | — | **90%**（Phase新規コード） | 95% |

**測定方法:**

```bash
flutter test --no-pub --coverage
# coverage/lcov.info が生成される
# lcov または genhtml でHTMLレポート生成
```

**除外対象（カバレッジ計測から除外）:**

| パス | 理由 |
|------|------|
| `lib/main.dart` | アプリエントリポイント（テスト不能） |
| `lib/core/infrastructure/supabase/supabase_client_provider.dart` | Supabase初期化（テスト環境では呼ばれない） |
| `lib/*.g.dart` | 自動生成コード（将来的にhive使用時） |
| `lib/core/theme/*` | テーマ定義（定数のみ） |
| `lib/core/testing/*` | テスト支援コード |

### 7.2 パフォーマンス基準

| メトリクス | 現状 | 目標 | 計測方法 |
|-----------|------|------|---------|
| 全テスト実行時間 | ~4分 | **<8分**（247テスト時） | `time flutter test --no-pub` |
| テストビルド時間 | ~2分 | **<3分** | CIログの `flutter test` 開始〜終了 |
| 1テスト平均時間 | ~20ms | **<30ms** | `flutter test --reporter expanded` |
| CI全体完了時間 | ~8分 | **<15分** | GitHub Actions トータル時間 |
| Supabaseクエリ応答 | — | **<200ms**（ローカル） | `supabase db query` のEXPLAIN ANALYZE |
| スキャン→登録完了 | — | **<5秒**（API含む） | 実機計測 |

### 7.3 品質ゲート通過条件（更新版）

```yaml
# quality-gates.yml 更新案
# 既存6ゲート + 新規4ゲート = 全10ゲート

Gate 1: 静的解析 ✅ dart analyze --fatal-infos --fatal-warnings
Gate 2: Semantics検証 ✅ 全操作可能要素にSemantics
Gate 3: AppKeys一意性 ✅ 重複キー禁止
Gate 4: ErrorBoundary検証 ✅ 全画面ルートにErrorBoundary
Gate 5: ファイルサイズ ✅ 1ファイル200行超禁止
Gate 6: 全試練通過 ✅ flutter test --no-pub
Gate 7: カバレッジ閾値（新規） 🔵 ラインカバレッジ 75%以上
Gate 8: 責務分離検証（新規） 🔵 domain層のFlutter非依存確認
Gate 9: モックパターン統一（新規） 🔵 全MockRepositoryがseed/reset/shouldThrowを持つ
Gate 10: APIキー漏洩防止（新規） 🔵 dart-define 経由のキーがハードコードされていない
```

### 7.4 Gate 7: カバレッジ閾値（実装案）

```yaml
# .github/workflows/quality-gates.yml 追記
- name: Check coverage threshold
  run: |
    flutter test --no-pub --coverage
    # lcov からラインカバレッジを抽出
    LINE_COV=$(lcov --summary coverage/lcov.info 2>&1 | grep "lines......" | awk '{print $2}' | tr -d '%')
    echo "Line coverage: $LINE_COV%"
    if (( $(echo "$LINE_COV < 75" | bc -l) )); then
      echo "❌ Gate 7 失敗: カバレッジ $LINE_COV% < 75%"
      # exit 1 は厳しすぎる場合は warning にする
      exit 1
    fi
    echo "✅ Gate 7 通過: カバレッジ $LINE_COV%"
```

### 7.5 品質ゲートの緩和ルール

| 状況 | ルール | 理由 |
|------|-------|------|
| 新規機能（Phase途中） | Gate 7（カバレッジ）を一時的に 60% に緩和 | 新規コード追加中は安定しない |
| 緊急バグ修正 | Gate 9（モックパターン統一）をスキップ可 | スピード優先 |
| リファクタリングのみ | 全ゲート通過必須（変更なし） | リファクタは品質維持が目的 |
| Phase完了時 | **全ゲート厳格適用** | Phase完了はマイルストーン |

### 7.6 CI設定更新計画

```yaml
# 最終的な quality-gates.yml 構成（Phase 2-4完了時想定）
name: 品質ゲート

on:
  pull_request:
    paths: ['utsushiyo/**', 'scripts/**']
  push:
    branches: [main, master]
  workflow_dispatch:
  schedule:
    - cron: '0 2 * * 0'  # 毎週日曜: 結合テスト + RLSテスト

jobs:
  static-analysis:  # 既存
  unit-tests:       # 既存 + カバレッジ
  integration-tests: # 新規（結合テスト）
    needs: unit-tests
    if: github.ref == 'refs/heads/main'
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: subosito/flutter-action@v2
      - name: Start Supabase local
        run: |
          cd utsushiyo/tsundoku-quest-flutter
          supabase start
      - name: Run integration tests
        run: |
          flutter test integration_test/ --no-pub
      - name: Stop Supabase
        run: supabase stop
  code-adaptation:  # 既存
  rls-tests:        # 新規（週次）
    needs: integration-tests
    if: github.event.schedule == '0 2 * * 0'
```

---

## 付録A: 既存テスト状況マッピング

### 現行テスト一覧とPhase 2-4との関係

| テストファイル | テスト数 | Phase 2関連 | Phase 3関連 | Phase 4関連 | 備考 |
|--------------|---------|------------|------------|------------|------|
| `core/app_router_test.dart` | 2 | — | — | — | 変更不要 |
| `domain/models/user_book_test.dart` | 5 | ✅ fromSupabase/toSupabase確認 | — | — | Supabase変換確認追加推奨 |
| `features/bookshelf/...` (4 files) | 42 | ✅ 透過型永続化 | — | — | 削除フロー完了済 |
| `features/explore/explore_screen_test.dart` | 9 | — | ✅ スキャンUI | ✅ 検索UI | 3タブ分の拡充が必要 |
| `features/history/...` (2 files) | 18 | ✅ ReadingSession連携 | — | — | Phase A-Dで対応済 |
| `features/reading/reading_screen_test.dart` | 7 | ✅ セッション管理 | — | — | Phase A対応済 |
| `mocks/mock_user_book_repository.dart` | — | ✅ (テスト支援) | — | — | 新規Mock追加必要 |
| `shared/models/...` (3 files) | 35 | ✅ モデル永続化 | — | — | fromSupabase確認追加 |
| `shared/providers/...` (4 files) | 29 | ✅ BookDataProvider | — | — | 透過型永続化テスト追加 |
| `shared/repositories/...` (4 files) | 20 | — | — | ✅ BookSearchService | APIクライアント単体テスト不足 |
| **全23ファイル** | **167** | | | | |

---

## 付録B: 推奨実装順序（優先度付き）

```
Week 1-2: Phase 2 基盤
  P0 MockRepository群（Auth/Adventurer/WarTrophy/ReadingSession）
  P0 SupabaseRepositoryユニットテスト
  P0 BookDataNotifier透過型永続化テスト
  P1 AdventurerStats.readingDates 追加（Phase A-D継続）

Week 3: Phase 3 スキャン基盤
  P0 BarcodeScannerWidgetリファクタ（プロダクションコード）
  P0 BarcodeScannerWidgetProvider追加
  P0 ハンドラーユニットテスト（9ケース）
  P1 スキャンタブUIテスト

Week 4: Phase 4 検索
  P0 APIクライアント単体テスト（Rakuten/OpenBD/Google）
  P0 BookSearchService拡充テスト
  P1 検索タブUIテスト
  P2 推薦ロジックテスト

Week 5: 仕上げ
  P0 カバレッジ閾値設定
  P1 統合テスト（supabase local）
  P2 RLSテスト（pgTAP + integration test）
  P2 品質ゲート更新（CI設定修正）
```

---

以上、月読命からの奏上を終える。

**Total estimated new tests: ~52**
**Final estimated test count: ~247 passing with `flutter test --no-pub`**
**Target line coverage: 75% (stretch: 85%)**
