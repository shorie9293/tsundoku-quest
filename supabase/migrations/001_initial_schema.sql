-- ══════════════════════════════════════════════
-- ツンドクエスト — Supabase マイグレーション
-- 
-- 積読ダンジョンの冒険を支えるデータの礎。
-- すべてのテーブルには RLS を設定し、
-- ユーザーは自身のデータのみアクセス可能とする。
-- ══════════════════════════════════════════════

-- ━━━ 拡張機能 ━━━
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- ━━━ 列挙型 ━━━
CREATE TYPE book_status AS ENUM ('tsundoku', 'reading', 'completed', 'paused');
CREATE TYPE book_medium AS ENUM ('physical', 'ebook', 'audiobook');
CREATE TYPE book_source AS ENUM ('openbd', 'google_books', 'rakuten', 'manual');

-- ━━━ 本（書誌マスター） ━━━
CREATE TABLE books (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  isbn13 TEXT UNIQUE,
  isbn10 TEXT UNIQUE,
  title TEXT NOT NULL,
  authors TEXT[] DEFAULT '{}',
  publisher TEXT,
  published_date DATE,
  description TEXT,
  page_count INTEGER,
  cover_image_url TEXT,
  source book_source DEFAULT 'manual',
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_books_isbn13 ON books(isbn13);
CREATE INDEX idx_books_title ON books USING gin(to_tsvector('japanese', title));

-- ━━━ ユーザーの蔵書 ━━━
CREATE TABLE user_books (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  book_id UUID NOT NULL REFERENCES books(id) ON DELETE CASCADE,
  status book_status DEFAULT 'tsundoku',
  medium book_medium DEFAULT 'physical',
  current_page INTEGER DEFAULT 0,
  rating INTEGER CHECK (rating >= 1 AND rating <= 5),
  started_at DATE,
  completed_at DATE,
  notes TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_user_books_user_id ON user_books(user_id);
CREATE INDEX idx_user_books_status ON user_books(user_id, status);
CREATE UNIQUE INDEX idx_user_books_unique ON user_books(user_id, book_id, medium);

-- ━━━ 読書セッション ━━━
CREATE TABLE reading_sessions (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_book_id UUID NOT NULL REFERENCES user_books(id) ON DELETE CASCADE,
  started_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  ended_at TIMESTAMPTZ,
  start_page INTEGER NOT NULL DEFAULT 0,
  end_page INTEGER,
  duration_minutes INTEGER,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_reading_sessions_user_book ON reading_sessions(user_book_id);
CREATE INDEX idx_reading_sessions_dates ON reading_sessions(started_at, ended_at);

-- ━━━ 戦利品カード（読了メモ） ━━━
CREATE TABLE war_trophies (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_book_id UUID NOT NULL REFERENCES user_books(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  learnings TEXT[] NOT NULL DEFAULT '{}',  -- 3つの学び
  action TEXT NOT NULL DEFAULT '',          -- 1つの行動
  favorite_quote TEXT,                      -- お気に入りの一文
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_war_trophies_user ON war_trophies(user_id);

-- ━━━ 読書目標 ━━━
CREATE TABLE reading_goals (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  year INTEGER NOT NULL,
  target_books INTEGER NOT NULL DEFAULT 12,
  target_pages INTEGER NOT NULL DEFAULT 3600,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(user_id, year)
);

-- ━━━ コレクション（本棚） ━━━
CREATE TABLE collections (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  description TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE collection_items (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  collection_id UUID NOT NULL REFERENCES collections(id) ON DELETE CASCADE,
  user_book_id UUID NOT NULL REFERENCES user_books(id) ON DELETE CASCADE,
  sort_order INTEGER DEFAULT 0
);

-- ━━━ Row Level Security ━━━
ALTER TABLE user_books ENABLE ROW LEVEL SECURITY;
ALTER TABLE reading_sessions ENABLE ROW LEVEL SECURITY;
ALTER TABLE war_trophies ENABLE ROW LEVEL SECURITY;
ALTER TABLE reading_goals ENABLE ROW LEVEL SECURITY;
ALTER TABLE collections ENABLE ROW LEVEL SECURITY;
ALTER TABLE collection_items ENABLE ROW LEVEL SECURITY;

-- books は共有データだが、参照のみ許可
ALTER TABLE books ENABLE ROW LEVEL SECURITY;
CREATE POLICY "誰でも参照可能" ON books FOR SELECT USING (true);
CREATE POLICY "認証ユーザーのみ登録可能" ON books FOR INSERT WITH CHECK (auth.role() = 'authenticated');

-- user_books ポリシー
CREATE POLICY "自分の蔵書のみ参照" ON user_books
  FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY "自分の蔵書のみ追加" ON user_books
  FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY "自分の蔵書のみ更新" ON user_books
  FOR UPDATE USING (auth.uid() = user_id);
CREATE POLICY "自分の蔵書のみ削除" ON user_books
  FOR DELETE USING (auth.uid() = user_id);

-- reading_sessions ポリシー
CREATE POLICY "自分のセッションのみ参照" ON reading_sessions
  FOR SELECT USING (
    EXISTS (SELECT 1 FROM user_books WHERE id = reading_sessions.user_book_id AND user_id = auth.uid())
  );
CREATE POLICY "自分のセッションのみ追加" ON reading_sessions
  FOR INSERT WITH CHECK (
    EXISTS (SELECT 1 FROM user_books WHERE id = reading_sessions.user_book_id AND user_id = auth.uid())
  );

-- war_trophies ポリシー
CREATE POLICY "自分の戦利品のみ参照" ON war_trophies
  FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY "自分の戦利品のみ追加" ON war_trophies
  FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY "自分の戦利品のみ更新" ON war_trophies
  FOR UPDATE USING (auth.uid() = user_id);

-- reading_goals ポリシー
CREATE POLICY "自分の目標のみ参照" ON reading_goals
  FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY "自分の目標のみ追加" ON reading_goals
  FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY "自分の目標のみ更新" ON reading_goals
  FOR UPDATE USING (auth.uid() = user_id);

-- collections ポリシー
CREATE POLICY "自分のコレクションのみ" ON collections
  FOR ALL USING (auth.uid() = user_id);
CREATE POLICY "自分のコレクションアイテムのみ" ON collection_items
  FOR ALL USING (
    EXISTS (SELECT 1 FROM collections WHERE id = collection_items.collection_id AND user_id = auth.uid())
  );

-- ━━━ 関数 ━━━
-- ストリーク計算用の関数
CREATE OR REPLACE FUNCTION calculate_streak(p_user_id UUID)
RETURNS INTEGER AS $$
DECLARE
  current_streak INTEGER := 0;
  yesterday DATE := CURRENT_DATE - 1;
  has_read BOOLEAN;
BEGIN
  LOOP
    SELECT EXISTS (
      SELECT 1 FROM reading_sessions rs
      JOIN user_books ub ON rs.user_book_id = ub.id
      WHERE ub.user_id = p_user_id
        AND rs.started_at::DATE = yesterday
    ) INTO has_read;

    EXIT WHEN NOT has_read;
    current_streak := current_streak + 1;
    yesterday := yesterday - 1;
  END LOOP;

  -- 今日読んでいるか確認
  SELECT EXISTS (
    SELECT 1 FROM reading_sessions rs
    JOIN user_books ub ON rs.user_book_id = ub.id
    WHERE ub.user_id = p_user_id
      AND rs.started_at::DATE = CURRENT_DATE
  ) INTO has_read;

  IF has_read THEN
    current_streak := current_streak + 1;
  END IF;

  RETURN current_streak;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
