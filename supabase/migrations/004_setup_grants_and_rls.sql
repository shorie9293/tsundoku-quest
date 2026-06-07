-- ══════════════════════════════════════════════
-- ツンドクエスト — GRANT・RLS補完（皐月作成）
--
-- 目的:
--   1. anon/authenticated ロールにテーブル権限を付与
--   2. books への匿名参照RLSを明示
--   3. 各テーブルのRLS完全性を再確認
--
-- 適用方法:
--   Supabase管理画面 → SQL Editor に貼り付けて実行。
--   「supabase db push」でも可（ローカルCLI設定済みの場合）。
-- ══════════════════════════════════════════════

-- ━━━ 1. スキーマ使用権限 ━━━
GRANT USAGE ON SCHEMA public TO anon;
GRANT USAGE ON SCHEMA public TO authenticated;
GRANT USAGE ON SCHEMA public TO service_role;

-- ━━━ 2. books — 全ロールにSELECT権限（カタログ参照のため） ━━━
GRANT SELECT ON books TO anon;
GRANT SELECT ON books TO authenticated;
GRANT INSERT, UPDATE, DELETE ON books TO authenticated;
GRANT ALL ON books TO service_role;

-- ━━━ 3. user_books — 認証ユーザーのみ ━━━
GRANT SELECT, INSERT, UPDATE, DELETE ON user_books TO authenticated;
GRANT ALL ON user_books TO service_role;

-- ━━━ 4. reading_sessions — 認証ユーザーのみ ━━━
GRANT SELECT, INSERT, UPDATE, DELETE ON reading_sessions TO authenticated;
GRANT ALL ON reading_sessions TO service_role;

-- ━━━ 5. war_trophies — 認証ユーザーのみ ━━━
GRANT SELECT, INSERT, UPDATE, DELETE ON war_trophies TO authenticated;
GRANT ALL ON war_trophies TO service_role;

-- ━━━ 6. reading_goals — 認証ユーザーのみ ━━━
GRANT SELECT, INSERT, UPDATE, DELETE ON reading_goals TO authenticated;
GRANT ALL ON reading_goals TO service_role;

-- ━━━ 7. collections — 認証ユーザーのみ ━━━
GRANT SELECT, INSERT, UPDATE, DELETE ON collections TO authenticated;
GRANT ALL ON collections TO service_role;

-- ━━━ 8. collection_items — 認証ユーザーのみ ━━━
GRANT SELECT, INSERT, UPDATE, DELETE ON collection_items TO authenticated;
GRANT ALL ON collection_items TO service_role;

-- ━━━ 9. adventurer_profiles — 認証ユーザーのみ ━━━
GRANT SELECT, INSERT, UPDATE ON adventurer_profiles TO authenticated;
GRANT ALL ON adventurer_profiles TO service_role;

-- ━━━ 10. シーケンス権限（UUID生成等に必要） ━━━
GRANT USAGE ON ALL SEQUENCES IN SCHEMA public TO authenticated;
GRANT USAGE ON ALL SEQUENCES IN SCHEMA public TO service_role;

-- ━━━ 11. RLS再確認 ━━━
-- books: 匿名ユーザーもカタログ参照可能
ALTER TABLE books ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "誰でも参照可能" ON books;
CREATE POLICY "誰でも参照可能" ON books
  FOR SELECT USING (true);
DROP POLICY IF EXISTS "認証ユーザーのみ登録可能" ON books;
CREATE POLICY "認証ユーザーのみ登録可能" ON books
  FOR INSERT WITH CHECK (auth.role() = 'authenticated');

-- user_books: 自分の蔵書のみ
ALTER TABLE user_books ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "自分の蔵書のみ参照" ON user_books;
CREATE POLICY "自分の蔵書のみ参照" ON user_books
  FOR SELECT USING (auth.uid() = user_id);
DROP POLICY IF EXISTS "自分の蔵書のみ追加" ON user_books;
CREATE POLICY "自分の蔵書のみ追加" ON user_books
  FOR INSERT WITH CHECK (auth.uid() = user_id);
DROP POLICY IF EXISTS "自分の蔵書のみ更新" ON user_books;
CREATE POLICY "自分の蔵書のみ更新" ON user_books
  FOR UPDATE USING (auth.uid() = user_id);
DROP POLICY IF EXISTS "自分の蔵書のみ削除" ON user_books;
CREATE POLICY "自分の蔵書のみ削除" ON user_books
  FOR DELETE USING (auth.uid() = user_id);

-- reading_sessions: 自分の蔵書のセッションのみ
ALTER TABLE reading_sessions ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "自分のセッションのみ参照" ON reading_sessions;
CREATE POLICY "自分のセッションのみ参照" ON reading_sessions
  FOR SELECT USING (
    EXISTS (SELECT 1 FROM user_books WHERE id = reading_sessions.user_book_id AND user_id = auth.uid())
  );
DROP POLICY IF EXISTS "自分のセッションのみ追加" ON reading_sessions;
CREATE POLICY "自分のセッションのみ追加" ON reading_sessions
  FOR INSERT WITH CHECK (
    EXISTS (SELECT 1 FROM user_books WHERE id = reading_sessions.user_book_id AND user_id = auth.uid())
  );
DROP POLICY IF EXISTS "自分のセッションのみ更新" ON reading_sessions;
CREATE POLICY "自分のセッションのみ更新" ON reading_sessions
  FOR UPDATE USING (
    EXISTS (SELECT 1 FROM user_books WHERE id = reading_sessions.user_book_id AND user_id = auth.uid())
  );
DROP POLICY IF EXISTS "自分のセッションのみ削除" ON reading_sessions;
CREATE POLICY "自分のセッションのみ削除" ON reading_sessions
  FOR DELETE USING (
    EXISTS (SELECT 1 FROM user_books WHERE id = reading_sessions.user_book_id AND user_id = auth.uid())
  );

-- war_trophies: 自分の戦利品のみ
ALTER TABLE war_trophies ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "自分の戦利品のみ参照" ON war_trophies;
CREATE POLICY "自分の戦利品のみ参照" ON war_trophies
  FOR SELECT USING (auth.uid() = user_id);
DROP POLICY IF EXISTS "自分の戦利品のみ追加" ON war_trophies;
CREATE POLICY "自分の戦利品のみ追加" ON war_trophies
  FOR INSERT WITH CHECK (auth.uid() = user_id);
DROP POLICY IF EXISTS "自分の戦利品のみ更新" ON war_trophies;
CREATE POLICY "自分の戦利品のみ更新" ON war_trophies
  FOR UPDATE USING (auth.uid() = user_id);

-- reading_goals: 自分の目標のみ
ALTER TABLE reading_goals ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "自分の目標のみ参照" ON reading_goals;
CREATE POLICY "自分の目標のみ参照" ON reading_goals
  FOR SELECT USING (auth.uid() = user_id);
DROP POLICY IF EXISTS "自分の目標のみ追加" ON reading_goals;
CREATE POLICY "自分の目標のみ追加" ON reading_goals
  FOR INSERT WITH CHECK (auth.uid() = user_id);
DROP POLICY IF EXISTS "自分の目標のみ更新" ON reading_goals;
CREATE POLICY "自分の目標のみ更新" ON reading_goals
  FOR UPDATE USING (auth.uid() = user_id);

-- collections: 自分のコレクションのみ
ALTER TABLE collections ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "自分のコレクションのみ" ON collections;
CREATE POLICY "自分のコレクションのみ" ON collections
  FOR ALL USING (auth.uid() = user_id);

-- collection_items: 自分のコレクションのアイテムのみ
ALTER TABLE collection_items ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "自分のコレクションアイテムのみ" ON collection_items;
CREATE POLICY "自分のコレクションアイテムのみ" ON collection_items
  FOR ALL USING (
    EXISTS (SELECT 1 FROM collections WHERE id = collection_items.collection_id AND user_id = auth.uid())
  );

-- adventurer_profiles: 自分のプロフィールのみ
ALTER TABLE adventurer_profiles ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "自分のプロフィールのみ参照" ON adventurer_profiles;
CREATE POLICY "自分のプロフィールのみ参照" ON adventurer_profiles
  FOR SELECT USING (auth.uid() = user_id);
DROP POLICY IF EXISTS "自分のプロフィールのみ挿入" ON adventurer_profiles;
CREATE POLICY "自分のプロフィールのみ挿入" ON adventurer_profiles
  FOR INSERT WITH CHECK (auth.uid() = user_id);
DROP POLICY IF EXISTS "自分のプロフィールのみ更新" ON adventurer_profiles;
CREATE POLICY "自分のプロフィールのみ更新" ON adventurer_profiles
  FOR UPDATE USING (auth.uid() = user_id);

-- ══════════════════════════════════════════════
-- 完了確認
-- ══════════════════════════════════════════════
-- テーブルごとのRLS状態を確認:
-- SELECT tablename, rowsecurity FROM pg_tables WHERE schemaname = 'public' ORDER BY tablename;
--
-- テーブルごとのポリシー一覧:
-- SELECT tablename, policyname, permissive, roles, cmd, qual FROM pg_policies WHERE schemaname = 'public' ORDER BY tablename, policyname;
