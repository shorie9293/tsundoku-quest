# 【UX分析】tsundoku-quest-flutter Supabase連携によるユーザー体験の変化

> 作成: 2026-05-05
> 視座: 天宇受賣命（UX神）
> 対象: tsundoku-quest-flutter 現世（Feature-First構造）

---

## 目次

1. [現状分析：Supabase導入前のUX](#1-現状分析supabase導入前のux)
2. [クラウド同期がもたらすUXの恩恵](#2-クラウド同期がもたらすuxの恩恵)
3. [導入すべきUI要素の詳細設計](#3-導入すべきui要素の詳細設計)
4. [認証フローの設計](#4-認証フローの設計)
5. [オフラインファースト戦略](#5-オフラインファースト戦略)
6. [初回起動体験（Onboarding）](#6-初回起動体験onboarding)
7. [既存画面への影響評価](#7-既存画面への影響評価)
8. [実装優先順位とロードマップ](#8-実装優先順位とロードマップ)

---

## 1. 現状分析：Supabase導入前のUX

### 1.1 現在のアーキテクチャ

```
メモリ内状態 (Riverpod StateNotifier)
  ├── AdventurerNotifier → AdventurerStats
  ├── BookDataNotifier   → BookDataState (books, userBooks, trophies)
  └── derived providers  → フィルタリング・統計
```

**特徴：**
- 全てのデータはアプリ起動中のみ存続（アプリ再起動で消失）
- `userId` はハードコードされた `'local-user'`
- 認証なし、ネットワーク依存なし、同期概念なし
- Hive は `pubspec.yaml` に宣言されているが未使用

### 1.2 現状のUXの問題点

| 問題点 | 影響 | 深刻度 |
|--------|------|--------|
| 🚨 データ永続化ゼロ | アプリ終了で蔵書・読書進捗・XPが全て消える | **致命的** |
| 📱 単一デバイスロックイン | 機種変更・タブレット併用不可 | 中 |
| 🔒 ユーザー識別なし | デバイス共有時のデータ混在リスク | 中 |
| ☁️ バックアップなし | デバイス破損・紛失でデータ完全喪失 | **高** |

### 1.3 Supabase導入によるUX変化の全体像

```
Before:  [端末メモリ] ── 揮発性・孤立的
After:   [Hive(ローカル)] ←→ [Supabase(クラウド)]
          ├── オフラインでも動作
          ├── オンライン時は自動同期
          └── マルチデバイスで同一データ
```

---

## 2. クラウド同期がもたらすUXの恩恵

### 2.1 マルチデバイス同期 🖥️📱

**ユーザーストーリー：**
> 「通勤中にスマホで読書を進めて、帰宅後タブレットで続きから読める」

**実現する体験：**
| シナリオ | 変更前 | 変更後 |
|----------|--------|--------|
| スマホで本を登録 → PCで確認 | ❌ 不可 | ✅ 即座に反映 |
| タブレットで読了 → スマホで戦利品カード確認 | ❌ 不可 | ✅ 自動同期 |
| 機種変更 | ❌ データ消失 | ✅ ログインで復元 |

**UX要件：**
- **最終読書位置の同期**：ページ進捗・タイマー経過時間をデバイス間で一致
- **ステータス遷移の同期**：tsundoku → reading → completed の状態変更を即反映
- **競合解決**：同一データを別デバイスで同時編集した場合の最終書き込み勝ち（またはマージ戦略）

### 2.2 データバックアップと復元 💾

**ユーザーストーリー：**
> 「スマホを買い替えても、ログインするだけで今までの読書履歴とXPが完全に復元される」

**UX上の価値：**
| 要素 | 現状 | 導入後 |
|------|------|--------|
| 蔵書一覧（100冊登録） | アプリ削除で消える | 永遠に保持 |
| 累計読書時間（100時間） | 消える | クラウドに蓄積 |
| XP・レベル（Lv.50） | 消える | アカウントに紐付く |
| ストリーク（365日） | 消える | 継続保持 |
| 戦利品カードの学び | 消える | 知識資産として保存 |

**UX要件：**
- **自動バックアップ**：変更のたびにバックグラウンド同期（ユーザー操作不要）
- **初回同期のプログレス表示**：「データを復元しています…」（大量データ時）
- **バックアップ日時の表示**：「最終同期：5分前」

### 2.3 付随的なUX恩恵

| 恩恵 | 説明 |
|------|------|
| 🏆 アカウント単位のバッジ | Supabase Row Level Security でユーザー固有バッジ管理 |
| 📊 コミュニティ統計（将来） | 「平均読書時間との比較」等、集計機能への布石 |
| 🔗 外部連携への拡張性 | Web版・PWA版とのデータ共有（将来のマルチプラットフォーム対応） |
| 🛡️ データセキュリティ | RLSにより他ユーザーのデータ閲覧不可（個人情報保護） |

---

## 3. 導入すべきUI要素の詳細設計

### 3.1 同期状態表示（Sync Status Indicator）

#### 3.1.1 概念設計

アプリ全体でネットワーク状態と同期状態を一元管理し、視認性が高く・邪魔にならない方法で表示する。

#### 3.1.2 UIコンポーネント

**① グローバル同期インジケーター（AppBar上部）**

```
┌─────────────────────────────────┐
│ ☁️ 同期済み          📚 書庫    │  ← 微細な点で状態表現
└─────────────────────────────────┘
```

| 状態 | 表示 | 意味 | 色 |
|------|------|------|-----|
| 同期済み | なし（または☁️/チェック） | 全データ同期完了 | — |
| 同期中 | 🔄 回転アニメーション | アップロード/ダウンロード中 | 青(#4A90D9) |
| オフライン | 📡 オフラインアイコン | ネットワーク不通 | 橙(#FF9500) |
| エラー | ⚠️ エラーアイコン（タップ可能） | 同期失敗 | 赤(#FF3B30) |
| 初回同期 | 進捗バー（プログレス） | 大量データの初期同期中 | 青 |

**実装方針：**
- AppBarの `actions` に配置（またはleadingの横に小型バッジ）
- `provider` で `SyncStatus` enum を一元管理
- エラー時はSnackBarで詳細メッセージを補完

**② 画面ごとの同期コンテキスト表示**

各画面下部に細いバーで状態を示す（オプション、初期は①のみで十分）：

```
┌─────────────────────────────────┐
│                                 │
│         メインコンテンツ          │
│                                 │
├─────────────────────────────────┤
│ 📡 オフライン — ローカルデータで  │
│    表示しています                │
└─────────────────────────────────┘
```

#### 3.1.3 Widget案

```dart
/// 同期状態を表示する小型インジケーター
class SyncStatusBadge extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(syncStatusProvider);
    
    return switch (status) {
      SyncStatus.synced    => const SizedBox.shrink(), // 同期済みは非表示
      SyncStatus.syncing   => const SizedBox(
        width: 16, height: 16,
        child: CircularProgressIndicator(strokeWidth: 2),
      ),
      SyncStatus.offline   => GestureDetector(
        onTap: () => _showOfflineBanner(context),
        child: const Icon(Icons.wifi_off, size: 16, color: Colors.orange),
      ),
      SyncStatus.error     => GestureDetector(
        onTap: () => _showSyncError(context),
        child: const Icon(Icons.sync_problem, size: 16, color: Colors.red),
      ),
      SyncStatus.initialSync => const LinearProgressIndicator(minHeight: 2),
    };
  }
}
```

### 3.2 オフラインフォールバック 🤝

#### 3.2.1 基本原則：オフラインファースト

```
[ユーザー操作] → [Hiveに即時保存] → [バックグラウンドでSupabaseに同期]
                  ↑ 常にローカルが主、クラウドは従
```

#### 3.2.2 オフライン時のUI振る舞い

| 操作 | オフライン時の振る舞い | UIフィードバック |
|------|----------------------|-----------------|
| 蔵書を閲覧 | Hiveから表示（通常通り） | オフラインアイコン表示のみ |
| 本を登録 | Hiveに保存、キューに追加 | 「📚 本を登録しました（オフライン）」 |
| 読了操作 | Hiveに保存、後で同期 | 「🏆 オフラインでも記録は保存されます」 |
| ページ進捗更新 | Hiveに保存 | 問題なし |
| 同期キュー確認 | 設定画面で「未同期: N件」表示 | 「☁️ N件の変更が同期待ちです」 |
| ログアウト | 不可（オフライン時はログアウトボタン非活性） | グレーアウト |

#### 3.2.3 専用UI要素

**③ 未同期件数バッジ（設定画面or書庫画面）**

```
[設定]
  ├── ☁️ クラウド同期
  │   ├── 最終同期: 2026/05/05 18:00
  │   ├── 未同期の変更: 3件 ＞  [今すぐ同期]
  │   └── 📡 オフラインデータのみで動作中
```

**④ 同期キュー状況表示**

```dart
class PendingSyncBanner extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pendingCount = ref.watch(pendingSyncCountProvider);
    if (pendingCount == 0) return const SizedBox.shrink();
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: AppTheme.warningBackground,
      child: Row(
        children: [
          const Icon(Icons.cloud_upload_outlined, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text('$pendingCount件の変更が同期待ちです'),
          ),
          TextButton(
            onPressed: () => ref.read(syncServiceProvider).syncNow(),
            child: const Text('今すぐ同期'),
          ),
        ],
      ),
    );
  }
}
```

### 3.3 同期状態のProvider構造

```dart
// ━━━ 同期状態の型定義 ━━━
enum SyncStatus {
  synced,       // 全データ同期済み
  syncing,      // 同期中
  offline,      // ネットワーク不通
  error,        // 同期エラー
  initialSync,  // 初回同期（ログイン直後）
}

// ━━━ 同期状態管理 ━━━
class SyncState {
  final SyncStatus status;
  final int pendingChanges;   // 未同期変更数
  final DateTime? lastSyncedAt;
  final String? lastError;
  
  const SyncState({...});
}

// ━━━ ネットワーク接続状態 ━━━
enum ConnectivityStatus {
  online,
  offline,
}
```

---

## 4. 認証フローの設計

### 4.1 基本方針：ゲストファースト + オプションサインアップ

**決定理由：**
- 「まず使ってみたい」ユーザーに認証の壁を作らせない
- 後からアカウント作成し、データをクラウド同期できる
- ゲスト状態でも全機能をローカルで使用可能

### 4.2 認証の種類と選択

| 方式 | 優先度 | 理由 |
|------|--------|------|
| **メール + パスワード** | P0 | 確実・どのプラットフォームでも動作 |
| **Apple ID (Sign in with Apple)** | P1 | iOS必須要件・ユーザー利便性 |
| **Google OAuth** | P1 | Androidユーザーにスムーズ |
| **マジックリンク（パスワードレス）** | P2 | 高セキュリティ・簡便 |

### 4.3 認証画面遷移図

```
[アプリ起動]
    │
    ├── [ゲストユーザー] ─────────→ 書庫画面（通常通り）
    │                                ↑ 下部に「☁️ データをバックアップ」
    │                                  「アカウント作成でデータを守る」
    │
    └── [認証済みユーザー]
         ├── 初回ログイン後 → 初期同期（プログレス表示）→ 書庫画面
         └── 通常起動 → バックグラウンド同期 → 書庫画面
```

### 4.4 認証画面デザイン

#### ④ ログイン画面

```
┌─────────────────────────────────┐
│                                 │
│        📚 ツンドクエスト          │
│    "読書という冒険を始めよう"     │
│                                 │
│  ┌─────────────────────────┐    │
│  │ 📧 メールアドレス        │    │
│  └─────────────────────────┘    │
│  ┌─────────────────────────┐    │
│  │ 🔒 パスワード            │    │
│  └─────────────────────────┘    │
│                                 │
│  [ 🚪 ログイン ]                 │
│                                 │
│  ─── または ───                  │
│                                 │
│  [ 🍏 Appleでログイン ]          │
│  [ G Googleでログイン ]          │
│                                 │
│  アカウントをお持ちでない方       │
│  [ ✨ 新規登録 ]                 │
│                                 │
│  [ 🚶‍♂️ ゲストとして使う ]         │  ← 目立たないテキストリンク
│      ログインしなくても使えます    │
└─────────────────────────────────┘
```

#### ⑤ サインアップ画面

```
┌─────────────────────────────────┐
│                                 │
│  ✨ 冒険者登録                   │
│                                 │
│  ┌─────────────────────────┐    │
│  │ 📧 メールアドレス        │    │
│  └─────────────────────────┘    │
│  ┌─────────────────────────┐    │
│  │ 🔒 パスワード            │    │
│  └─────────────────────────┘    │
│  ┌─────────────────────────┐    │
│  │ 🔒 パスワード（確認）    │    │
│  └─────────────────────────┘    │
│                                 │
│  [ ] 利用規約に同意する          │
│                                 │
│  [ ✨ 冒険を始める ]            │
│                                 │
│  既にアカウントをお持ちですか？   │
│  [ ログイン ]                    │
└─────────────────────────────────┘
```

#### ⑥ ゲスト→アカウント変換フロー

**重要：ゲストデータの継承**

```
[ゲストとして使用中]
     │
     │ 書庫画面下部バナー:
     │ 「☁️ アカウントを作成すると、データがクラウドに保存されます」
     │                        [アカウント作成]
     ▼
[認証画面] → [アカウント作成/ログイン]
     │
     ▼
[データマージ確認ダイアログ]
     ┌────────────────────────────┐
     │ 🔄 ローカルデータを        │
     │    クラウドと同期しますか？  │
     │                            │
     │ ローカルのデータ: 15冊      │
     │ 対応する既存データ: なし    │
     │                            │
     │ [ローカルを優先] [キャンセル]│
     └────────────────────────────┘
     │
     ▼
[初期同期実行] → [書庫画面（認証済み）]
```

### 4.5 ゲストユーザーのUUID管理

```dart
// ゲストユーザーにも一意のUUIDを割り当て（Hive保存）
// アカウント作成時にこのUUIDをSupabase Authのユーザーに紐付ける
class GuestIdentityService {
  Future<String> getGuestUserId() async {
    final box = await Hive.openBox('settings');
    String? guestId = box.get('guest_user_id');
    if (guestId == null) {
      guestId = const Uuid().v4();
      await box.put('guest_user_id', guestId);
    }
    return guestId;
  }
}
```

---

## 5. オフラインファースト戦略

### 5.1 アーキテクチャ設計

```
┌─────────────────────────────────────────────────┐
│                 アプリケーション層               │
├─────────────────────────────────────────────────┤
│  Provider (Riverpod)          ← 変化を購読      │
├─────────────────────────────────────────────────┤
│  Repository (抽象)                               │
├──────────────────┬──────────────────────────────┤
│  HiveRepository  │  SupabaseRepository          │
│  (ローカル永続化)  │  (クラウドAPI)               │
├──────────────────┴──────────────────────────────┤
│  SyncService (オーケストレーター)                 │
│  ├── connectivity_monitor                       │
│  ├── change_log (未同期変更の追跡)               │
│  └── sync_engine (差分同期)                     │
└─────────────────────────────────────────────────┘
```

### 5.2 データフロー

```
[書き込み操作]
    │
    ▼
[1. Hiveに即時書き込み] ← ユーザーには一瞬で反映
    │
[2. ChangeLogに追記]
    │   {type: 'upsert', table: 'user_books', id: 'xxx', timestamp: ...}
    │
[3. ネットワーク状態確認]
    ├── Online → [4. Supabaseに即時同期] → [ChangeLogから削除]
    └── Offline → [5. キューに保留]
                      │
                   [オンライン復帰]
                      │
                      ▼
                   [6. キューを順次実行]
```

### 5.3 差分同期と競合解決

| シナリオ | 戦略 |
|----------|------|
| 同一デバイス・オフライン後の再同期 | タイムスタンプ順に適用（最終書き込み勝ち） |
| 別デバイスで同時編集 | 最終書き込み勝ち（last_updated_atで判定） |
| 削除と更新の競合 | 削除優先（トゥームストーン方式） |
| 初回同期（ローカル > クラウド） | Hiveデータをそのままアップロード |
| 初回同期（クラウド > ローカル） | クラウドデータをそのままダウンロード |

### 5.4 同期関連UIの状態遷移

```
[アプリ起動]
    │
    ├── [初回起動（未ログイン）] → Hive新規作成 → 通常利用
    │
    ├── [ログイン後・初回同期]
    │   ├── データ量 < 100件 → バックグラウンドで自動同期（サイレント）
    │   └── データ量 ≥ 100件 → スプラッシュ画面で進捗表示
    │
    ├── [通常起動（認証済み）]
    │   ├── Online → バックグラウンド差分同期 → 完了
    │   └── Offline → Hiveデータのみ表示（後で同期）
    │
    └── [ゲスト→アカウント変換]
        → 初回同期と同じプログレス表示
```

---

## 6. 初回起動体験（Onboarding）

### 6.1 基本方針：摩擦ゼロ

**ルール：ログインを必須にしない。**

初回起動時に認証を強要すると、`「まだ本も登録してないのにアカウント作らされるのは嫌だ」`という離脱原因になる。

### 6.2 Onboardingフロー

```
[アプリ初回起動]
    │
    ▼
[オンボーディング画面（スキップ可能）]
    ┌──────────────────────────────┐
    │  📚 ツンドクエスト             │
    │                              │
    │  "本を読む=冒険"             │
    │                              │
    │  [1] 本を登録して書庫を作る    │  ← 横スワイプで3枚
    │  [2] タイマーで読書を記録      │
    │  [3] XPをためてレベルアップ    │
    │                              │
    │  [ 🚪 冒険に出る！ ]          │
    │  [ゲストとして始める]          │  ← 小さいテキスト
    └──────────────────────────────┘
    │
    ▼
[書庫画面（空の状態）]
    │  ↓ 下部にプロモーションバナー
    │  「☁️ アカウント作成でデータをバックアップ」
    │              [作成する]
    │
    ▼
[アカウント作成 or そのまま利用]
```

### 6.3 プロモーションバナーのデザイン

**⑦ ゲスト向けアップセルバナー（書庫画面下部）**

```dart
class CloudSyncPromoBanner extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isLoggedIn = ref.watch(authProvider).isLoggedIn;
    if (isLoggedIn) return const SizedBox.shrink();
    
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [AppTheme.accent, AppTheme.active]),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(Icons.cloud, color: Colors.white, size: 32),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('データをクラウドに保存',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                const Text('アカウント作成で読書データをバックアップ',
                    style: TextStyle(color: Colors.white70, fontSize: 12)),
              ],
            ),
          ),
          TextButton(
            onPressed: () => context.push('/auth/signup'),
            child: const Text('作成する', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}
```

### 6.4 ログイン状態による初期画面分岐

```dart
// app_router.dart の拡張
GoRouter createRouter() {
  return GoRouter(
    initialLocation: '/',
    redirect: (context, state) {
      final isLoggedIn = ref.read(authProvider).isLoggedIn;
      final isOnAuthScreen = state.matchedLocation.startsWith('/auth');
      
      // 認証済みユーザーが認証画面に行こうとしたらリダイレクト
      if (isLoggedIn && isOnAuthScreen) return '/';
      
      // 未認証でもブロックしない（ゲストアクセス許可）
      return null;
    },
    routes: [
      // 認証ルート
      GoRoute(path: '/auth/login', ...),
      GoRoute(path: '/auth/signup', ...),
      
      // メインルート（ShellRoute）
      ShellRoute(
        builder: (_, __, child) => AppScaffold(child: child),
        routes: [
          GoRoute(path: '/', builder: (_, __) => BookshelfScreen()),
          GoRoute(path: '/explore', ...),
          GoRoute(path: '/reading', ...),
          GoRoute(path: '/history', ...),
        ],
      ),
    ],
  );
}
```

---

## 7. 既存画面への影響評価

### 7.1 各画面の変更点一覧

| 画面 | 現状の課題 | Supabase導入による変更 | 影響度 |
|------|-----------|----------------------|--------|
| **書庫（ホーム）** | データ永続化なし | SyncStatusBadge追加 / PromoBanner追加 / Hiveからの読み込み | **大** |
| **探索（本の登録）** | `userId: 'local-user'` | 動的userId / 登録時にHive+Supaへの二重書き込み | 中 |
| **読書中** | タイマー・ページ進捗消える | 読了時にHive+Supa同期 / オフラインでも動作 | 中 |
| **足跡（統計）** | 全データ揮発 | 変更なし（プロバイダ経由のため透過的） | 小 |
| **戦利品カード** | 同上 | 同上 | 小 |
| **AppScaffold（タブ）** | — | タブバー横にSyncStatusBadge追加 | 小 |

### 7.2 変更が必要なモデル

| モデル | 変更内容 |
|--------|---------|
| `AdventurerStats` | `toJson()` / `fromJson()` 追加、Supabaseテーブル `adventurer_stats` と対応 |
| `Book` | `toJson()` / `fromJson()` 既存 ✅、`id` を Supabaseの `uuid` 生成に変更 |
| `UserBook` | ✅ 同上、`userId` を動的に |
| `WarTrophy` | ✅ 同上 |

### 7.3 新規追加が必要なProvider

| Provider | 責務 |
|----------|------|
| `authProvider` | Supabase Authの状態管理 |
| `syncStatusProvider` | 同期状態の一元管理 |
| `connectivityProvider` | ネットワーク接続状態 |
| `pendingSyncCountProvider` | 未同期変更数 |
| `syncServiceProvider` | SyncServiceのインスタンス提供 |

### 7.4 新規追加が必要なファイル

```
lib/
├── features/
│   └── auth/                        # 新規Feature
│       ├── presentation/
│       │   ├── login_screen.dart
│       │   ├── signup_screen.dart
│       │   └── widgets/
│       │       └── auth_provider_button.dart
│       └── data/
│           └── supabase_auth_repository.dart
├── shared/
│   ├── data/
│   │   ├── repositories/
│   │   │   ├── hive_repository.dart   # Hive永続化実装
│   │   │   └── supabase_repository.dart # Supabase API実装
│   │   └── services/
│   │       ├── sync_service.dart      # 同期エンジン
│   │       └── connectivity_service.dart # ネットワーク監視
│   └── viewmodels/
│       └── auth_viewmodel.dart
│   └── widgets/
│       ├── sync_status_badge.dart
│       └── cloud_sync_promo_banner.dart
└── core/
    └── infrastructure/
        └── supabase_client.dart       # Supabase初期化
```

---

## 8. 実装優先順位とロードマップ

### 8.1 Phase 0：基盤整備（必須・最優先）

| # | タスク | 理由 |
|---|--------|------|
| 1 | HiveRepositoryの実装 | データ永続化は最優先課題 |
| 2 | モデルにtoJson/fromJson追加（AdventurerStats） | 現状不足 |
| 3 | AdventurerNotifier/BookDataNotifierをHiveと連携 | 状態保存の確立 |
| 4 | Supabase初期化（`supabase_client.dart`） | 基盤セットアップ |

**UX目標：** アプリ終了後もデータが保持される（これだけでも現在比で**劇的改善**）

### 8.2 Phase 1：認証（次優先）

| # | タスク | UX効果 |
|---|--------|--------|
| 5 | authProviderの作成 | 認証状態の一元管理 |
| 6 | ログイン画面（メール+パスワード） | アカウント作成可能に |
| 7 | サインアップ画面 | — |
| 8 | ゲストユーザーUUID生成 | 全ユーザーに一意ID |
| 9 | ゲスト→アカウント変換フロー | データ継承 |

### 8.3 Phase 2：同期（中優先）

| # | タスク | UX効果 |
|---|--------|--------|
| 10 | SyncServiceの実装 | クラウド同期の開始 |
| 11 | change_log/同期キュー | オフライン対応 |
| 12 | SyncStatusBadge | 状態の可視化 |
| 13 | オフラインバナー | ユーザーへの通知 |
| 14 | ConnectivityService | ネットワーク監視 |

### 8.4 Phase 3：リッチ化（余裕があれば）

| # | タスク | UX効果 |
|---|--------|--------|
| 15 | OAuth（Apple/Google） | 認証の利便性向上 |
| 16 | Onboarding画面 | 初回体験の質向上 |
| 17 | PromoBanner（ゲート→アカウント変換） | コンバージョン向上 |
| 18 | 初回同期プログレス表示 | 大規模データのUX配慮 |

### 8.5 推奨スケジュール

```
Week 1-2: Phase 0 (Hive永続化) ─── データが消えなくなる 🎉
Week 3-4: Phase 1 (認証) ─────── アカウント作成可能に
Week 5-6: Phase 2 (同期) ─────── クラウドバックアップ完了 ☁️
Week 7-8: Phase 3 (リッチ化) ─── OAuth・オンボーディング
```

---

## 付録：QA用チェックリスト（月読命へ引き継ぎ用）

- [ ] オフラインで本の登録→オンライン復帰で同期されるか
- [ ] ログイン中のユーザーデータと他ユーザーデータが混在しないか（RLS確認）
- [ ] アプリ終了→再起動でデータが保持されているか
- [ ] 認証トークン期限切れ時のリフレッシュが自動で行われるか
- [ ] 同期エラー時のリトライが適切に動作するか
- [ ] ゲスト→アカウント変換時にローカルデータが正しく継承されるか
- [ ] 大量データ（1000件）での初回同期がタイムアウトしないか
- [ ] 競合発生時の最終書き込み勝ちが期待通り動作するか
- [ ] オフライン時にログアウトボタンが非活性になるか
- [ ] SyncStatusの各状態で適切なUIが表示されるか

---

以上、天宇受賣命（UX神）より奏上。
