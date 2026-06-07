import 'package:flutter_test/flutter_test.dart';
import 'package:tsundoku_quest/core/infrastructure/supabase/supabase_config.dart';

void main() {
  group('SupabaseConfig', () {
    test('url は String 型である', () {
      expect(SupabaseConfig.url, isA<String>());
    });

    test('anonKey は String 型である', () {
      expect(SupabaseConfig.anonKey, isA<String>());
    });

    test('url のデフォルトは空文字列', () {
      expect(SupabaseConfig.url, '');
    });

    test('anonKey のデフォルトは空文字列', () {
      expect(SupabaseConfig.anonKey, '');
    });
  });

  group('BookApiKeys', () {
    test('rakutenAppId は String 型である', () {
      expect(BookApiKeys.rakutenAppId, isA<String>());
    });

    test('rakutenAccessKey は String 型である', () {
      expect(BookApiKeys.rakutenAccessKey, isA<String>());
    });

    test('googleBooksApiKey は String 型である', () {
      expect(BookApiKeys.googleBooksApiKey, isA<String>());
    });

    test('rakutenAppId のデフォルトは空文字列', () {
      expect(BookApiKeys.rakutenAppId, '');
    });

    test('rakutenAccessKey のデフォルトは空文字列', () {
      expect(BookApiKeys.rakutenAccessKey, '');
    });

    test('googleBooksApiKey のデフォルトは空文字列', () {
      expect(BookApiKeys.googleBooksApiKey, '');
    });
  });
}
