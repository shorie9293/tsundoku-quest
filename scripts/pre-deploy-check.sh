#!/bin/bash
# ⛩️ Pre-deploy check — デプロイ前に CI 同等の全チェックをローカル実行
# tsundoku-quest 専用：CI 相当の 3-shard テスト構造で P5 ハング（長時間一括試験）を回避
# 八百万の掟：デプロイ前には必ずこのスクリプトを通せ
set -euo pipefail

REPO_ROOT="$(git rev-parse --show-toplevel)"
cd "$REPO_ROOT"

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "⛩️  Pre-deploy check: tsundoku-quest-flutter"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# --- Step 1: flutter pub get ---
echo ""
echo "[1/5] 📦 flutter pub get..."
flutter pub get
echo "✅ pub get OK"

# --- Step 2: flutter analyze ---
echo ""
echo "[2/5] 🔍 flutter analyze --no-fatal-infos..."
flutter analyze --no-fatal-infos
echo "✅ analyze OK (no warnings or errors)"

# --- Step 3: Test shard 1/3 (core + shared — 純ロジック・リポジトリ) ---
echo ""
echo "[3/5] 🧪 test shard 1/3 (core + shared)..."
flutter test --no-pub -j 2 \
  test/core/ \
  test/shared/
echo "✅ shard 1/3 passed"

# --- Step 4: Test shard 2/3 (features — UI・Hive・Supabase) ---
echo ""
echo "[4/5] 🧪 test shard 2/3 (features)..."
flutter test --no-pub -j 1 \
  test/features/
echo "✅ shard 2/3 passed"

# --- Step 5: Test shard 3/3 (domain models) ---
echo ""
echo "[5/5] 🧪 test shard 3/3 (domain)..."
flutter test --no-pub -j 1 \
  test/domain/
echo "✅ shard 3/3 passed"

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🎉 Pre-deploy check PASSED — safe to deploy"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
