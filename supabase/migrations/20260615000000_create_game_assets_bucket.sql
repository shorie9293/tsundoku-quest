-- Storage bucket: game-assets (ドット絵アセット格納用)
-- public=true で匿名ユーザーもSELECT可能
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
  'game-assets',
  'game-assets',
  true,
  5242880, -- 5MB per file
  ARRAY['image/png', 'image/webp', 'application/json']
)
ON CONFLICT (id) DO UPDATE SET public = true;

-- 公開読み取りポリシー（誰でも閲覧可能）
DROP POLICY IF EXISTS "Public Read game-assets" ON storage.objects;
CREATE POLICY "Public Read game-assets"
ON storage.objects FOR SELECT
USING (bucket_id = 'game-assets');

-- 認証済みユーザーのアップロードポリシー
DROP POLICY IF EXISTS "Auth Upload game-assets" ON storage.objects;
CREATE POLICY "Auth Upload game-assets"
ON storage.objects FOR INSERT
WITH CHECK (bucket_id = 'game-assets' AND auth.role() = 'authenticated');
