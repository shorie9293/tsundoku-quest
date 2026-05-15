# 🏯 ツンドクエスト Flutter版 — Supabase連携導入 優先順位・スコープ分析

> **作成**: 思兼神（PM視点）
> **日付**: 2026-05-05
> **対象**: tsundoku-quest-flutter (現世: ツンドクエスト)
> **参照**: utsushiyo/tsundoku-quest/supabase/migrations/001_initial_schema.sql

---

## 1. 現状分析

### 1.1 プロジェクト成熟度

| 観点 | 状態 |
|------|------|
| supabase_flutter | ✅ パッケージ導入済み (`^2.8.0`) — コード未着手 |
| データ永続化 | 🟡 Hive (ローカルのみ) — 端末限定、データロストリスク |
| 状態管理 | ✅ Riverpod (StateNotifier) — 全データをメモリ上で管理 |
| 画面実装 | ✅ 4画面 (Bookshelf/Explore/Reading/History) — 全画面でローカルデータ参照 |
| アーキテクチャ | ✅ Feature-First構造準拠 — domain/層への移行余地あり |
| 環境変数(.env) | ❌ 未作成 — Supabase接続情報が設定不可 |

### 1.2 既存モデル vs Supabaseスキーマ 対応表

| Supabaseテーブル | Flutterモデル | 状態 | 画面での利用 | MVP優先度 |
|---|---|---|---|---|
| `books` | `Book` | ✅ モデル有 | 全画面 | **P0** |
| `user_books` | `UserBook` | ✅ モデル有 | Bookshelf, Reading, Explore | **P0** |
| `reading_sessions` | `ReadingSession` | ✅ モデル有 | Reading (timer) | **P1** |
| `war_trophies` | `WarTrophy` | ✅ モデル有 | Reading (読了完了時) | **P1** |
| `reading_goals` | ❌ 未実装 | モデルなし | 未使用 | **P2** |
| `collections` + `collection_items` | ❌ 未実装 | モデルなし | 未使用 (今後の本棚整理) | **P3** |
| Auth (Supabase Auth) | ❌ 未実装 | — | 未ログイン状態 | **P0** |

### 1.3 データ依存関係グラフ

```
認証 (Supabase Auth) ──── すべての基盤
  │
  ├── books ────────────── 独立した書誌マスター (ISBNで重複排除)
  │
  ├── user_books ───────── ユーザーの蔵書 (RLS: auth.uid())
  │   ├── reading_sessions ─ 読書セッション (user_book_id FK)
  │   ├── war_trophies ───── 戦利品カード (user_book_id FK)
  │   └── collection_items ─ コレクション内書籍 (user_book_id FK)
  │
  ├── reading_goals ────── 年度目標 (独立, user_id FK)
  │
  └── collections ──────── 本棚 (独立, user_id FK)
      └── collection_items (collections.id FK)
```

**重要**: `user_books` は全子テーブルの基点。Supabase化の第一歩は `user_books` と `books`。

---

## 2. 優先順位 / 段階的導入計画

### Phase 0: 土台整備 (見積: 2〜3日)

**目的**: Supabase接続 + 認証の基盤を整え、以降のPhaseの障害を除去する。

| タスク | 内容 | 重要度 |
|--------|------|--------|
| 0-1 | `.env` に Supabase URL/Anon Key を設定 | 必須 |
| 0-2 | `main.dart` で `await Supabase.initialize()` | 必須 |
| 0-3 | Supabase Auth 画面 (ログイン/新規登録) を実装 | 必須 |
| 0-4 | Auth状態監視 Provider の作成 (`authProvider`) | 必須 |
| 0-5 | `domain/repositories/` に抽象インターフェースを定義 | 推奨 |
| 0-6 | Hive → Supabase データ移行ユーティリティ | 任意 |

**なぜAuthからか**:  
全テーブルにRLSポリシー (`auth.uid() = user_id`) が設定されている。認証なしでは `user_books` 以下のデータに一切アクセス不可。AuthなしでSupabase連携は成立しない。

---

### Phase 1: MVP — 蔵書のSupabase化 (見積: 4〜6日)

**スコープ**: `books` + `user_books` の2テーブルをSupabase管理下に置く。

**データフロー変更**:
```
Before: Hive(Book) → Riverpod(BookDataNotifier) → UI
After:  Supabase(books) → Riverpod(SupabaseBookRepository) → UI
        ↓ キャッシュ
        Hive(キャッシュ用)
```

**実装タスク**:

| タスク | 内容 | ファイル影響範囲 |
|--------|------|----------------|
| 1-1 | `BookRepository` 抽象クラス作成 (domain/repositories/) | 新規 |
| 1-2 | `SupabaseBookRepository` 具象クラス作成 (features/shared/data/) | 新規 |
| 1-3 | `HiveBookRepository` (オフラインキャッシュ用) 作成 | 新規 |
| 1-4 | `BookDataNotifier` を Supabase 対応に書き換え | book_data_provider.dart |
| 1-5 | `UserBookRepository` + `SupabaseUserBookRepository` | 新規 |
| 1-6 | 認証ユーザーに紐づく蔵書一覧の取得 (RLS準拠) | bookshelf_screen.dart |
| 1-7 | 蔵書登録フローのSupabase連携 (Explore画面) | explore_screen.dart |
| 1-8 | 読書状態変更のSupabase同期 (Reading画面) | reading_screen.dart |
| 1-9 | Hive→Supabase データ移行スクリプト (ユーザー初回起動時) | 新規 (utils/) |

**MVP判断基準**:  
- ユーザーがログインし、本を登録 → 書庫に表示 → 状態変更がSupabaseに保存される
- 別端末でログインすると同じ蔵書一覧が表示される
- オフライン時はHiveキャッシュで読み取り専用動作

**なぜここがMVPか**:  
Next.js版のSupabaseスキーマでRLSがかかっている `user_books` は `reading_sessions` と `war_trophies` の親テーブル。ここをSupabase化しないと、読書セッションや戦利品カードをSupabaseに保存しても整合性が取れない。また、蔵書登録がアプリの最大のコアバリューであり、最も頻繁に使われる操作。

---

### Phase 2: 読書セッション + 戦利品カード (見積: 3〜4日)

**スコープ**: `reading_sessions` + `war_trophies` をSupabase化。

**前提**: Phase 1完了により、`user_books.id` がSupabase側のUUIDで一意に決まっていること。

| タスク | 内容 |
|--------|------|
| 2-1 | `ReadingSessionRepository` + Supabase実装 |
| 2-2 | `WarTrophyRepository` + Supabase実装 |
| 2-3 | 読書タイマー完了時にReadingSessionをSupabaseに保存 |
| 2-4 | 読了完了時にWarTrophyをSupabaseに保存 |
| 2-5 | ストリーク計算をSupabase関数 (`calculate_streak`) 呼び出しに |
| 2-6 | 戦利品カード一覧画面 (Trophy画面) の実装 |

**依存関係**: `reading_sessions` と `war_trophies` は共に `user_books.id` (UUID) にFK依存。RLSも `user_books` の所有権を経由して判定されるため、Phase 1の完了が必須。

**価値**:  
- 端末をまたいだ読書時間の蓄積が可能に
- ストリーク計算がサーバー側で正確に行われる
- 戦利品カードがクラウドに保存され、紛失しない

---

### Phase 3: 読書目標 (見積: 1〜2日)

**スコープ**: `reading_goals` テーブルをSupabase化。

| タスク | 内容 |
|--------|------|
| 3-1 | `ReadingGoal` モデル作成 (domain/models/) |
| 3-2 | `ReadingGoalRepository` + Supabase実装 |
| 3-3 | 年度目標設定UI (設定画面など) |
| 3-4 | 目標進捗表示 (History画面 or 書庫) |

**独立度**: `reading_goals` は `user_id` のみに依存し、他のテーブルとFK関係がないため、Phase 1/2と並行して実装可能。ただし画面要件が未定義のため優先度低。

---

### Phase 4: コレクション機能 (見積: 2〜3日)

**スコープ**: `collections` + `collection_items` をSupabase化。

| タスク | 内容 |
|--------|------|
| 4-1 | `Collection` + `CollectionItem` モデル作成 |
| 4-2 | `CollectionRepository` + Supabase実装 |
| 4-3 | コレクション作成・編集UI |
| 4-4 | 書庫画面でのコレクション表示切替 |

**位置づけ**: 現行Flutter版にはコレクション機能の画面が存在しない。新規機能開発となる。Next.js版でもコレクション機能は基本スキーマのみでUI未実装の可能性が高い。

---

## 3. アーキテクチャ方針

### 3.1 Repositoryパターン導入

```
UI層 (presentation/)
  ↓ Provider (Riverpod)
ドメイン層 (domain/)
  ├── models/          ← 純粋Dartモデル (現在のshared/models/)
  ├── repositories/    ← 抽象インターフェース ← ★新規
  └── services/        ← 純粋関数 (XP計算等)
データ層 (features/shared/data/)
  ├── repositories/    ← Supabase実装 + Hiveキャッシュ実装
  └── datasources/     ← Supabaseクライアントラッパー
```

**メリット**:
- テスト容易性: MockRepositoryでテスト可能に
- オフライン対応: HiveキャッシュRepositoryを透過的に切り替え
- アーキテクチャ準拠: 高天原のFeature-First構造令に合致

### 3.2 オフライン戦略

| 状態 | 動作 |
|------|------|
| オンライン | Supabase読み書き + Hiveにキャッシュ |
| オフライン | Hiveから読み取り専用 (書き込みはキューに積む or ブロック) |
| 復帰時 | 差分同期 (楽観的更新 or Supabase Realtime) |

**推奨**: MVPでは「オンライン時のみ書き込み」のシンプルな戦略。オフラインキューはPhase 2以降。

### 3.3 スキーマ互換性

Flutterモデル ↔ Supabaseの変換で注意すべき点:

| 項目 | Supabase (Postgres) | Flutter (Dart) | 変換方法 |
|------|-------------------|----------------|---------|
| 配列 | `TEXT[]` | `List<String>` | PostgREST自動変換 |
| 日付 | `TIMESTAMPTZ` | `String` | ISO 8601文字列として扱う |
| UUID | `UUID` | `String` | そのまま文字列 |
| Enum | `book_status` | `BookStatus` enum | `.value` ↔ DB文字列 |
| NULL許容 | `INTEGER CHECK` | `int?` | nullable対応 |

**注意点**: Next.js版の `totalReadingMinutes` は `user_books` のカラムだが、Supabaseスキーマにはそのカラムがない。これは「累積読書時間を `reading_sessions` から集計する設計」を示唆。Flutter版でも同様の方針を取るか、`user_books` にキャッシュ列を追加するか要検討。

---

## 4. リスクと対策

| リスク | 影響 | 対策 |
|--------|------|------|
| Supabase無料枠の制限 (500MB DB/2GB BW) | 中 | 画像は外部CDN、カバー画像はURL保存のみ |
| 既存Hiveデータの移行漏れ | 中 | Phase 0で移行ユーティリティを作成、初回起動時に1度だけ実行 |
| Auth実装の遅延で全Phaseがブロック | 高 | AuthはPhase 0で最優先、ログインスキップ機能は設けない |
| オフライン時のUX低下 | 中 | Hiveキャッシュ読み取りで最低限の操作性を確保 |
| domain/層移行の設計コスト | 低 | 現shared/models/は domain/models/ にそのまま移動可能 |

---

## 5. 推奨スケジュール

```
Week 1 ─── Phase 0: 基盤整備 (Auth + Supabase初期化)
            ├── Mon-Tue: Auth実装, .env設定, main.dart初期化
            └── Wed: domain/repositories/ 抽象定義, CI確認

Week 2-3 ─ Phase 1: MVP (books + user_books Supabase化)
            ├── Mon-Tue: BookRepository, UserBookRepository
            ├── Wed-Thu: Provider書き換え, 画面連携
            └── Fri: テスト + Hive移行 + QA

Week 4-5 ─ Phase 2: reading_sessions + war_trophies
            ├── Mon-Tue: ReadingSessionRepository
            ├── Wed-Thu: WarTrophyRepository + Trophy画面
            └── Fri: ストリーク連携 + E2Eテスト

Week 6 ─── Phase 3-4: Goals + Collections (余力で)
```

**MVP (Minimum Viable Product) の定義**:
Phase 0 + Phase 1 完了時点。つまり：
- ✅ Supabase Auth でログイン/新規登録できる
- ✅ 本を検索・登録できる (ISBN or 手入力)
- ✅ 蔵書一覧がSupabase経由で表示される
- ✅ 読書状態を変更できる (tsundoku/reading/completed)
- ✅ 別端末で同じアカウントでログインすると同期される
- ✅ オフラインでもHiveキャッシュから閲覧可能

---

## 6. 結論

### 優先順位サマリー

| 順位 | データ | 理由 |
|------|--------|------|
| **P0** | Auth + books + user_books | 全機能の基盤。RLSがauth.uid()依存。他の全テーブルの親 |
| **P1** | reading_sessions + war_trophies | コア体験。user_booksにFK依存。ストリーク/統計に必須 |
| **P2** | reading_goals | 独立テーブル。ただし画面未実装のため後回し |
| **P3** | collections + collection_items | 新規機能。MVPには不要 |

### キーメッセージ

1. **Authが最優先かつ最大のボトルネック** — Supabase連携の第一歩は認証。全RLSが `auth.uid()` に依存。
2. **`books` + `user_books` がMVPのスコープ** — これだけで「端末をまたいだ蔵書管理」という最大価値が実現する。
3. **`reading_sessions` はPhase 1の次** — 読書時間の蓄積・ストリーク計算には必須だが、`user_books.id` がSupabase UUIDであることが前提。
4. **`AdventurerStats` はローカル計算で十分** — 集計値であり、リアルタイム更新を考えるとクライアント側で計算＋適宜同期が適切。
5. **Repositoryパターン導入 must** — テスト容易性・オフライン対応・アーキテクチャ準拠の3点を満たすため、Phase 0で抽象インターフェースを定義すべし。

---

## 付録: Next.js版との差分で注意すべき点

| 項目 | Next.js版 | Flutter版への示唆 |
|------|-----------|-----------------|
| 状態管理 | Zustand (ローカル→Supabase同期なし) | Riverpod + Repositoryパターンで「Supabase First」に |
| 認証 | Supabase SSR (server/client分離) | `supabase_flutter` の `Supabase.auth` で一元管理 |
| データ移行 | Zustand persist (localStorage) | HiveからSupabaseへの完全移行が必要 |
| totalReadingMinutes | user_booksのカラムとして保持 | Supabaseスキーマにはない。要検討: (a) user_booksに追加 (b) reading_sessionsから算出 |
| ストリーク | Supabase関数 `calculate_streak()` | Flutter版も同じ関数を呼び出すか、ローカル計算＋定期同期 |
