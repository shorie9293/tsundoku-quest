# ゲームアセットパイプライン基盤 具現化計画

> **For Hermes:** 各TaskをTDDサイクル（RED→GREEN→REFACTOR）で具現化せよ。

**Goal:** アバター（3Dドット絵回転表示）＋敵（ランク別ランダム出現）のアセットパイプライン基盤を構築する。

**Architecture:** Supabase Storage にドット絵PNGを格納、アプリ起動時に公開URLを取得。アバターは多角度スプライトを `GestureDetector` で切替表示。敵はJSON定義からランダム抽選。オフライン時はプログラム生成プレースホルダーにフォールバック。

**Tech Stack:** Flutter + Riverpod + Supabase Storage（既存SDK活用）、新規依存なし。

---

## Task 1: データモデル — GameAvatar

**Files:**
- Create: `lib/domain/models/game_avatar.dart`
- Create: `test/domain/models/game_avatar_test.dart`

`GameAvatar`:
- `id` (String)
- `name` (String)
- `spriteAngles`: `Map<AvatarAngle, String>` — 角度→Supabase Storage公開URL
- `defaultAngle`: `AvatarAngle.front`
- `AvatarAngle` enum: `front, frontRight, right, backRight, back, backLeft, left, frontLeft` (8方向)

```dart
enum AvatarAngle {
  front, frontRight, right, backRight, back, backLeft, left, frontLeft;
  
  /// 隣の角度（右回転）
  AvatarAngle get next => AvatarAngle.values[(index + 1) % 8];
  /// 隣の角度（左回転）
  AvatarAngle get prev => AvatarAngle.values[(index + 7) % 8];
}
```

---

## Task 2: データモデル — Enemy

**Files:**
- Create: `lib/domain/models/enemy.dart`
- Create: `test/domain/models/enemy_test.dart`

`Enemy`:
- `id` (String)
- `name` (String)
- `rank` (int, 1-5)
- `hp` (int)
- `attack` (int)
- `defense` (int)
- `xpReward` (int)
- `spriteUrl` (String) — 敵ドット絵のSupabase Storage公開URL

---

## Task 3: Supabase Storage サービス層

**Files:**
- Create: `lib/core/infrastructure/supabase/supabase_storage_service.dart`
- Create: `test/core/infrastructure/supabase/supabase_storage_service_test.dart`

```dart
class SupabaseStorageService {
  final SupabaseClient _client;
  static const _bucketName = 'game-assets';
  
  /// アバターの全角度スプライトURLを取得
  Future<Map<AvatarAngle, String>> fetchAvatarSprites(String avatarId);
  
  /// 敵スプライトURLを取得
  Future<String> fetchEnemySprite(String enemyId);
  
  /// 敵一覧JSONを取得
  Future<List<Enemy>> fetchEnemyList();
  
  /// 公開URLを構築
  String _publicUrl(String path);
}
```

**フォールバック**: Supabase未初期化時はプレースホルダーURLを返す。

---

## Task 4: Avatar Provider + 回転Widget

**Files:**
- Create: `lib/shared/providers/avatar_provider.dart`
- Create: `lib/core/widgets/rotatable_pixel_avatar.dart`
- Create: `test/shared/providers/avatar_provider_test.dart`
- Create: `test/core/widgets/rotatable_pixel_avatar_test.dart`

`AvatarNotifier` (Riverpod StateNotifier):
- State: `GameAvatar?` + `AvatarAngle currentAngle`
- 起動時に `SupabaseStorageService.fetchAvatarSprites()` で読み込み
- `rotateTo(AvatarAngle angle)` で角度変更

`RotatablePixelAvatar` (Widget):
- `GestureDetector` で水平ドラッグを検出
- ドラッグ量に応じて `AvatarAngle` を切替
- `AnimatedSwitcher` でスムーズな切替
- 未ロード時は `CircularProgressIndicator`
- Supabase未接続時は `CustomPaint` で簡易ドット絵プレースホルダー描画

---

## Task 5: Enemy Provider + ランダム選択

**Files:**
- Create: `lib/shared/providers/enemy_provider.dart`
- Create: `lib/core/widgets/enemy_sprite_widget.dart`
- Create: `test/shared/providers/enemy_provider_test.dart`

`EnemyProvider` (Riverpod Provider):
- `fetchEnemies()` → `List<Enemy>`
- `randomEnemy({int? playerLevel})` → `Enemy?` — プレイヤーレベル以下のランクからランダム抽選
- ランク重み付け: 低ランクほど出現率高め

`EnemySpriteWidget` (Widget):
- 敵のドット絵を表示
- ロード中はスケルトン表示
- 未ロード時は `CustomPaint` プレースホルダー

---

## Task 6: Supabase Storage bucket SQL migration

**Files:**
- Create: `supabase/migrations/20260615000000_create_game_assets_bucket.sql`

```sql
-- Storage bucket: game-assets
INSERT INTO storage.buckets (id, name, public) 
VALUES ('game-assets', 'game-assets', true);

-- 公開読み取りポリシー
CREATE POLICY "Public Read game-assets"
ON storage.objects FOR SELECT
USING (bucket_id = 'game-assets');
```

---

## Task 7: テスト＋flutter analyze＋全試験通過確認

```bash
cd /home/horie/Takamagahara/utsushiyo/tsundoku-quest-flutter
PATH="/tmp/flutter/bin:$PATH" flutter pub get
PATH="/tmp/flutter/bin:$PATH" flutter analyze --no-fatal-infos
PATH="/tmp/flutter/bin:$PATH" flutter test --no-pub
```

---

## Pitfalls

- **Supabase Storage は匿名キーでも公開bucketのSELECTは可能**（INSERT/UPDATEにはservice_roleが必要）。Dashboard手動アップロード想定。
- **オフライン時のプレースホルダー描画**に `CustomPaint` を使う場合、テストでは `TestWidgetsFlutterBinding.ensureInitialized()` が必須。
- **`GestureDetector` + `AnimatedSwitcher`** の組み合わせで、ドラッグ中に Widget が再構築されないよう `StatefulWidget` でローカル状態管理すること。
- **Riverpod Provider のテスト**では `ProviderContainer` を使用し、Supabaseクライアントをモック化する。
