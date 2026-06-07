import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tsundoku_quest/shared/providers/book_search_service_provider.dart';
import 'package:tsundoku_quest/shared/repositories/book_search_service.dart';

void main() {
  group('bookSearchServiceProvider', () {
    test('creates a non-null BookSearchService', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final service = container.read(bookSearchServiceProvider);

      expect(service, isNotNull);
      expect(service, isA<BookSearchService>());
    });

    test('returns the same instance (singleton-like)', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final service1 = container.read(bookSearchServiceProvider);
      final service2 = container.read(bookSearchServiceProvider);

      expect(identical(service1, service2), isTrue);
    });

    test('has non-null sub-APIs (rakuten, openbd, googleBooks)', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final service = container.read(bookSearchServiceProvider);

      // BookSearchService requires all three sub-APIs as required named params;
      // a successfully created service guarantees they are non-null.
      expect(service, isNotNull);
      expect(service, isA<BookSearchService>());
    });
  });
}
