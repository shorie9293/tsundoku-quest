/// 外部API接続設定
class SupabaseConfig {
  /// SupabaseプロジェクトのURL（環境変数から注入）
  static const String url = String.fromEnvironment('SUPABASE_URL');

  /// Supabaseの匿名キー（環境変数から注入）
  static const String anonKey = String.fromEnvironment('SUPABASE_ANON_KEY');
}

/// 書籍検索APIキー
class BookApiKeys {
  /// 楽天ブックスAPI アプリケーションID
  static const String rakutenAppId =
      String.fromEnvironment('RAKUTEN_APP_ID');

  /// 楽天ブックスAPI アクセスキー
  static const String rakutenAccessKey =
      String.fromEnvironment('RAKUTEN_ACCESS_KEY');

  /// Google Books API キー
  static const String googleBooksApiKey =
      String.fromEnvironment('GOOGLE_BOOKS_API_KEY');
}
