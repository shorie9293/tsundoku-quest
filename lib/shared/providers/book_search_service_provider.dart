import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/infrastructure/supabase/supabase_config.dart';
import '../repositories/book_search_service.dart';
import '../repositories/rakuten_api.dart';
import '../repositories/openbd_api.dart';
import '../repositories/google_books_api.dart';

/// BookSearchService の Riverpod プロバイダ
///
/// 楽天 → OpenBD → Google Books の3段フォールバック。
/// APIキーは --dart-define で注入（未設定時はOpenBDのみ動作）。
final bookSearchServiceProvider = Provider<BookSearchService>((ref) {
  return BookSearchService(
    rakuten: RakutenApi(
      appId: BookApiKeys.rakutenAppId,
      accessKey: BookApiKeys.rakutenAccessKey,
    ),
    openbd: OpenBDApi(),
    googleBooks: GoogleBooksApi(
      apiKey: BookApiKeys.googleBooksApiKey,
    ),
  );
});
