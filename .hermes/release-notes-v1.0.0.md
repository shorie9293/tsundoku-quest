# ツンドクエスト v1.0.0 リリースノート

## 概要
Next.js PWAからFlutterネイティブへ完全移行した初回リリース。

## 機能
- 📚 **書庫**: 冒険者ステータス、XPバー、ストリーク表示、本棚セクション
- 🧭 **探索**: 検索・バーコードスキャン・手入力の3方式で本を登録
- ⏱ **読書中**: 読書タイマー、ページ進捗、読了メモ（戦利品カード）
- 📊 **足跡**: 読書統計、XP/レベル表示、読書カレンダー

## 技術スタック
- Flutter 3.27+ / Dart 3.6+
- Riverpod（状態管理）
- GoRouter（ルーティング）
- mobile_scanner（バーコード）
- Hive（ローカル永続化）
- Supabase（バックエンド）

## ビルド方法
```bash
cd utsushiyo/tsundoku-quest-flutter
flutter build appbundle --release
```

## テスト
- ユニットテスト: 132 tests ✅
- Widgetテスト: 画面・コンポーネントテスト完備
- Semantics + AppKeys によるアクセシビリティ対応済
