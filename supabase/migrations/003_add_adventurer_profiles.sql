-- ══════════════════════════════════════════════
-- ツンドクエスト — 冒険者プロフィール（XP永続化）
--
-- 冒険者の累積XPを Supabase に保存し、
-- アプリ再起動時にもレベル・称号を復元できるようにする。
-- ══════════════════════════════════════════════

-- ━━━ 冒険者プロフィール ━━━
CREATE TABLE IF NOT EXISTS adventurer_profiles (
  user_id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  total_xp INTEGER NOT NULL DEFAULT 0,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- ━━━ Row Level Security ━━━
ALTER TABLE adventurer_profiles ENABLE ROW LEVEL SECURITY;

CREATE POLICY "自分のプロフィールのみ参照" ON adventurer_profiles
  FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "自分のプロフィールのみ挿入" ON adventurer_profiles
  FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "自分のプロフィールのみ更新" ON adventurer_profiles
  FOR UPDATE USING (auth.uid() = user_id);

-- ━━━ updated_at 自動更新トリガー ━━━
CREATE OR REPLACE FUNCTION update_adventurer_profiles_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_adventurer_profiles_updated_at
  BEFORE UPDATE ON adventurer_profiles
  FOR EACH ROW
  EXECUTE FUNCTION update_adventurer_profiles_updated_at();
