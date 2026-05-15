#!/bin/bash
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# 【鍛冶のハーネス】— Flutter 開発検証パイプライン
# 奏上: 天目一箇神（アメノマヒトツ）
# 制定: 令和八年皐月四日（2026年5月4日）
#
# 用法:
#   ./scripts/flutter_harness.sh          # 全ゲート実行（エラー時に停止）
#   ./scripts/flutter_harness.sh --quick  # 静的解析＋テストのみ（高速モード）
#   ./scripts/flutter_harness.sh --full   # 全ゲート＋build検証
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
set -euo pipefail

# ── 神器の在処 ──
readonly FLUTTER="${FLUTTER:-/home/horie/flutter/bin/flutter}"
readonly DART="${DART:-/home/horie/flutter/bin/cache/dart-sdk/bin/dart}"
readonly PROJECT_ROOT="${PROJECT_ROOT:-/home/horie/projects/takamagahara/utsushiyo/tsundoku-quest-flutter}"
readonly COLOR_RESET='\033[0m'
readonly COLOR_GREEN='\033[0;32m'
readonly COLOR_RED='\033[0;31m'
readonly COLOR_YELLOW='\033[1;33m'
readonly COLOR_BLUE='\033[0;34m'
readonly COLOR_CYAN='\033[0;36m'

cd "$PROJECT_ROOT"

# ── 出力用関数 ──
banner() {
    echo -e "${COLOR_BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${COLOR_RESET}"
    echo -e "${COLOR_BLUE}  🔨 $1${COLOR_RESET}"
    echo -e "${COLOR_BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${COLOR_RESET}"
}

pass() {
    echo -e "  ${COLOR_GREEN}✅ PASS${COLOR_RESET} — $1 (${2}s)"
}

fail() {
    echo -e "  ${COLOR_RED}❌ FAIL${COLOR_RESET} — $1 (${2}s)"
    echo -e "  ${COLOR_YELLOW}📋 詳細: $3${COLOR_RESET}"
}

info() {
    echo -e "  ${COLOR_CYAN}ℹ $1${COLOR_RESET}"
}

# ── タイマー ──
timer_start() {
    date +%s%N
}

timer_elapsed() {
    local start=$1
    local end=$(date +%s%N)
    echo "scale=1; ($end - $start) / 1000000000" | bc
}

# ─────────────────────────────────────────────────────────
# 第一ゲート：フォーマット検証
# ─────────────────────────────────────────────────────────
gate_format() {
    banner "【第一ゲート】フォーマット検証 (dart format)"

    local t0=$(timer_start)
    local output
    output=$($DART format --output=none --set-exit-if-changed lib/ test/ 2>&1) && local rc=$? || rc=$?
    local elapsed=$(timer_elapsed $t0)

    if [ $rc -eq 0 ]; then
        pass "フォーマット検証" "$elapsed"
        return 0
    else
        local changed
        changed=$(echo "$output" | grep -c "Changed" || echo "不明")
        fail "フォーマット検証" "$elapsed" "${changed}ファイルが未フォーマット。\`dart format lib/ test/\` を実行せよ。"
        echo "$output" | head -20
        return 1
    fi
}

# ─────────────────────────────────────────────────────────
# 第二ゲート：静的解析
# ─────────────────────────────────────────────────────────
gate_analyze() {
    banner "【第二ゲート】静的解析 (flutter analyze)"

    local t0=$(timer_start)
    local output
    output=$($FLUTTER analyze 2>&1) && local rc=$? || rc=$?
    local elapsed=$(timer_elapsed $t0)

    local errors
    errors=$(echo "$output" | grep -c " error •" 2>/dev/null || true)
    errors=${errors:-0}
    errors=$(echo "$errors" | tr -d '[:space:]')
    local warnings
    warnings=$(echo "$output" | grep -c "warning •" 2>/dev/null || true)
    warnings=${warnings:-0}
    warnings=$(echo "$warnings" | tr -d '[:space:]')

    if [ "$errors" = "0" ] || [ "$errors" -eq 0 ] 2>/dev/null; then
        if [ "$warnings" -gt 0 ]; then
            pass "静的解析（警告${warnings}件は許容）" "$elapsed"
        else
            pass "静的解析（完全クリーン）" "$elapsed"
        fi
        return 0
    else
        fail "静的解析" "$elapsed" "${errors}件のエラー + ${warnings}件の警告を検出"
        echo "$output" | grep " error •" | head -10
        return 1
    fi
}

# ─────────────────────────────────────────────────────────
# 第三ゲート：単体テスト
# ─────────────────────────────────────────────────────────
gate_test() {
    banner "【第三ゲート】単体テスト (flutter test)"

    local t0=$(timer_start)
    local concurrency=${FLUTTER_TEST_JOBS:-$(nproc)}
    info "並列実行数: ${concurrency}"

    local output
    output=$($FLUTTER test --concurrency="$concurrency" --reporter compact 2>&1) && local rc=$? || rc=$?
    local elapsed=$(timer_elapsed $t0)

    if [ $rc -eq 0 ]; then
        local passed
        passed=$(echo "$output" | grep -oP '\+\d+' | tail -1 | tr -d '+' || echo "全")
        pass "単体テスト — ${passed}件成功" "$elapsed"
        return 0
    else
        local failed
        failed=$(echo "$output" | grep -c "FAILED\|Some tests failed" || echo "0")
        fail "単体テスト" "$elapsed" "${failed}件のテスト失敗"
        echo "$output" | grep -B1 -A5 "FAILED\|Test failed\|Expected:" | head -40
        return 1
    fi
}

# ─────────────────────────────────────────────────────────
# 第四ゲート：コード適応検証（Semantics / AppKeys / ErrorBoundary）
# ─────────────────────────────────────────────────────────
gate_code_adaptation() {
    banner "【第四ゲート】コード適応検証"

    local t0=$(timer_start)
    local issues=0

    # ── 4-1. Semantics付与状況 ──
    info "4-1. Semantics付与状況"
    local screen_files
    screen_files=$(find lib/features -name '*_screen.dart' 2>/dev/null)
    local total_screens=0
    local screens_with_semantics=0

    for f in $screen_files; do
        total_screens=$((total_screens + 1))
        if grep -q "Semantics\|SemanticHelper" "$f" 2>/dev/null; then
            screens_with_semantics=$((screens_with_semantics + 1))
        fi
    done

    echo -e "  画面ファイル数: ${total_screens}"
    echo -e "  Semantics付与済: ${screens_with_semantics}"

    if [ "$total_screens" -gt 0 ] && [ "$screens_with_semantics" -lt "$total_screens" ]; then
        echo -e "  ${COLOR_YELLOW}⚠ 全${total_screens}画面中${screens_with_semantics}画面のみSemantics付与${COLOR_RESET}"
        # 未付与の画面を列挙
        for f in $screen_files; do
            if ! grep -q "Semantics\|SemanticHelper" "$f" 2>/dev/null; then
                echo -e "    ${COLOR_YELLOW}→ $f${COLOR_RESET}"
            fi
        done
        issues=$((issues + 1))
    fi

    # ── 4-2. AppKeys使用状況 ──
    info "4-2. AppKeys使用状況"
    local key_count
    key_count=$(grep -r "AppKeys\." lib/ --include='*.dart' 2>/dev/null | wc -l)
    echo -e "  AppKeys参照箇所数: ${key_count}"

    if [ "$key_count" -lt 20 ]; then
        echo -e "  ${COLOR_YELLOW}⚠ AppKeys参照が少ない（${key_count}箇所）。全操作可能要素にKeyを付与せよ。${COLOR_RESET}"
        issues=$((issues + 1))
    fi

    # ── 4-3. ErrorBoundary使用状況 ──
    info "4-3. ErrorBoundary使用状況"
    local eb_count
    eb_count=$(grep -r "ErrorBoundary\|ErrorBoundaryWidget" lib/ --include='*.dart' 2>/dev/null | wc -l)
    echo -e "  ErrorBoundary使用箇所数: ${eb_count}"

    # main.dart での ErrorWidget.builder 設定は最低限必須
    if grep -q "ErrorBoundaryWidget" lib/main.dart 2>/dev/null; then
        echo -e "  ${COLOR_GREEN}✓ main.dart に ErrorBoundary 設定あり${COLOR_RESET}"
    else
        echo -e "  ${COLOR_RED}✗ main.dart に ErrorBoundary 設定なし${COLOR_RESET}"
        issues=$((issues + 1))
    fi

    # ── 判定 ──
    local elapsed=$(timer_elapsed $t0)

    if [ "$issues" -eq 0 ]; then
        pass "コード適応検証（全項目合格）" "$elapsed"
        return 0
    else
        fail "コード適応検証" "$elapsed" "${issues}項目の違反あり。上記の⚠/✗を修正せよ。"
        return 1
    fi
}

# ─────────────────────────────────────────────────────────
# 第五ゲート（オプション）：ビルド検証
# ─────────────────────────────────────────────────────────
gate_build_check() {
    banner "【第五ゲート】ビルド検証 (flutter build apk --debug)"

    local t0=$(timer_start)
    info "Android Debugビルドを実行中...（この工程は時間がかかる）"
    local output
    output=$($FLUTTER build apk --debug 2>&1) && local rc=$? || rc=$?
    local elapsed=$(timer_elapsed $t0)

    if [ $rc -eq 0 ]; then
        pass "ビルド検証" "$elapsed"
        return 0
    else
        fail "ビルド検証" "$elapsed" "ビルドエラー発生"
        echo "$output" | grep -i "error\|FAILURE" | head -15
        return 1
    fi
}

# ── メイン ──
main() {
    local mode="${1:-all}"
    local failed_gates=()
    local stopped=false

    echo ""
    echo -e "${COLOR_BLUE}╔══════════════════════════════════════════════════════╗${COLOR_RESET}"
    echo -e "${COLOR_BLUE}║  🔨 天目一箇神 鍛冶のハーネス v1.0                     ║${COLOR_RESET}"
    echo -e "${COLOR_BLUE}║  現世: ツンドクエスト                                 ║${COLOR_RESET}"
    echo -e "${COLOR_BLUE}║  神器: Flutter ${FLUTTER_VERSION:-}                                  ║${COLOR_RESET}"
    echo -e "${COLOR_BLUE}╚══════════════════════════════════════════════════════╝${COLOR_RESET}"
    echo ""

    local overall_start=$(timer_start)

    # ── 第一ゲート: フォーマット ──
    if ! gate_format; then
        failed_gates+=("第一(フォーマット)")
    fi

    # ── 第二ゲート: 静的解析 ──
    if ! gate_analyze; then
        failed_gates+=("第二(静的解析)")
        stopped=true
    fi

    # 静的解析エラー時は後続ゲートをスキップ（無意味）
    if [ "$stopped" = true ] && [ "$mode" != "--force-all" ]; then
        echo ""
        echo -e "${COLOR_RED}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${COLOR_RESET}"
        echo -e "${COLOR_RED}  💀 静的解析エラーのためハーネス中断${COLOR_RESET}"
        echo -e "${COLOR_RED}    エラーを修正し再実行せよ。${COLOR_RESET}"
        echo -e "${COLOR_RED}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${COLOR_RESET}"
        exit 1
    fi

    # ── 第三ゲート: テスト ──
    if [ "$mode" != "--analyze-only" ]; then
        if ! gate_test; then
            failed_gates+=("第三(テスト)")
        fi
    fi

    # ── 第四ゲート: コード適応 ──
    if [ "$mode" != "--quick" ] && [ "$mode" != "--analyze-only" ]; then
        if ! gate_code_adaptation; then
            failed_gates+=("第四(コード適応)")
        fi
    fi

    # ── 第五ゲート: ビルド（--full モードのみ） ──
    if [ "$mode" = "--full" ] || [ "$mode" = "--build" ]; then
        if ! gate_build_check; then
            failed_gates+=("第五(ビルド)")
        fi
    fi

    # ── 総括 ──
    local overall_elapsed=$(timer_elapsed $overall_start)

    echo ""
    if [ ${#failed_gates[@]} -eq 0 ]; then
        echo -e "${COLOR_GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${COLOR_RESET}"
        echo -e "${COLOR_GREEN}  ✨ 全ゲート通過！鍛造完了！${COLOR_RESET}"
        echo -e "${COLOR_GREEN}  総時間: ${overall_elapsed}秒${COLOR_RESET}"
        echo -e "${COLOR_GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${COLOR_RESET}"
        exit 0
    else
        echo -e "${COLOR_RED}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${COLOR_RESET}"
        echo -e "${COLOR_RED}  💀 失敗ゲート: ${failed_gates[*]}${COLOR_RESET}"
        echo -e "${COLOR_RED}  総時間: ${overall_elapsed}秒${COLOR_RESET}"
        echo -e "${COLOR_RED}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${COLOR_RESET}"
        exit 1
    fi
}

# ── エントリポイント ──
main "$@"
