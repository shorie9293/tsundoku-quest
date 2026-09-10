-- war_trophies に DELETE ポリシーを追加（本削除時に戦利品をサーバー側でも削除するため）
--
-- 背景: SupabaseWarTrophyRepository.deleteTrophiesByUserBook() が
-- war_trophies の DELETE を発行するが、従来のマイグレーションでは
-- SELECT/INSERT/UPDATE のポリシーのみで DELETE ポリシーが存在しなかった。
-- RLS は default-deny のため、ポリシー無しでは削除が 0 行で無音に失敗する。

DROP POLICY IF EXISTS "自分の戦利品のみ削除" ON war_trophies;
CREATE POLICY "自分の戦利品のみ削除" ON war_trophies
  FOR DELETE USING (auth.uid() = user_id);
