-- ══════════════════════════════════════════════
-- ツンドクエスト — 累積読書時間カラム追加
--
-- user_books に total_reading_minutes を追加。
-- 既存データは reading_sessions の合計から逆算。
-- ══════════════════════════════════════════════

-- 1. カラム追加（既存行はデフォルト0）
ALTER TABLE user_books
ADD COLUMN IF NOT EXISTS total_reading_minutes INTEGER NOT NULL DEFAULT 0;

-- 2. 既存データの補完：reading_sessions の duration_minutes 合計で埋める
UPDATE user_books ub
SET total_reading_minutes = COALESCE(
  (SELECT SUM(rs.duration_minutes)
   FROM reading_sessions rs
   WHERE rs.user_book_id = ub.id),
  0
);
