import 'package:flutter_test/flutter_test.dart';
import 'package:tsundoku_quest/shared/load_state.dart';

void main() {
  group('LoadState', () {
    test('位相ごとの getter が正しい', () {
      expect(LoadState<int>.loading().isLoading, isTrue);
      expect(LoadState<int>.data(1).isData, isTrue);
      expect(LoadState<int>.empty().isEmpty, isTrue);
      expect(LoadState<int>.error('失敗').isError, isTrue);

      expect(LoadState<int>.loading().isData, isFalse);
      expect(LoadState<int>.data(1).isLoading, isFalse);
    });

    test('valueOrNull は data のときだけ値を返す', () {
      expect(LoadState<int>.data(7).valueOrNull, 7);
      expect(LoadState<int>.empty().valueOrNull, isNull);
      expect(LoadState<int>.error('失敗').valueOrNull, isNull);
    });

    test('message は error のときだけ返す', () {
      expect(LoadState<int>.error('読み込みに失敗しました').message, '読み込みに失敗しました');
      expect(LoadState<int>.data(1).message, isNull);
    });

    test('when が全位相を網羅する', () {
      String describe(LoadState<int> s) => s.when(
            loading: () => 'loading',
            data: (v) => 'data:$v',
            empty: () => 'empty',
            error: (m, retryable) => 'error:$m:$retryable',
          );

      expect(describe(LoadState<int>.loading()), 'loading');
      expect(describe(LoadState<int>.data(3)), 'data:3');
      expect(describe(LoadState<int>.empty()), 'empty');
      expect(describe(LoadState<int>.error('失敗', retryable: false)),
          'error:失敗:false');
    });

    test('等価性と hashCode', () {
      expect(LoadState<int>.empty(), LoadState<int>.empty());
      expect(LoadState<int>.empty().hashCode, LoadState<int>.empty().hashCode);
      expect(LoadState<int>.data(1), LoadState<int>.data(1));
      expect(LoadState<int>.data(1).hashCode, LoadState<int>.data(1).hashCode);
      expect(LoadState<int>.data(1), isNot(LoadState<int>.data(2)));
      expect(LoadState<int>.data(1), isNot(LoadState<int>.empty()));
      expect(
        LoadState<int>.error('失敗', retryable: true),
        LoadState<int>.error('失敗', retryable: true),
      );
      expect(
        LoadState<int>.error('失敗', retryable: true),
        isNot(LoadState<int>.error('失敗', retryable: false)),
      );
    });

    test('cause も等価性に含まれる', () {
      final cause = Exception('boom');
      expect(LoadState<int>.error('失敗', cause: cause),
          LoadState<int>.error('失敗', cause: cause));
      expect(LoadState<int>.error('失敗', cause: cause),
          isNot(LoadState<int>.error('失敗')));
    });

    test('toString が位相を表す', () {
      expect(LoadState<int>.empty().toString(), contains('empty'));
      expect(LoadState<int>.data(5).toString(), contains('data(5)'));
      expect(LoadState<int>.error('失敗').toString(), contains('失敗'));
    });

    test('不正引数は ArgumentError', () {
      expect(() => LoadState<int>.error(''), throwsArgumentError);
      expect(() => LoadState<int>.error('  '), throwsArgumentError);
    });

    test('null 許容型なら data(null) を許す', () {
      final state = LoadState<String?>.data(null);
      expect(state.isData, isTrue);
      expect(state.valueOrNull, isNull);
    });
  });

  group('LoadResult', () {
    test('success/failure の getter', () {
      final ok = LoadResult<int>.success(1);
      expect(ok.isSuccess, isTrue);
      expect(ok.isFailure, isFalse);
      expect(ok.valueOrNull, 1);
      expect(ok.message, isNull);

      final ng = LoadResult<int>.failure('失敗');
      expect(ng.isFailure, isTrue);
      expect(ng.valueOrNull, isNull);
      expect(ng.message, '失敗');
      expect(ng.retryable, isTrue);
    });

    test('when が成否で分岐する', () {
      expect(
        LoadResult<int>.success(2).when(
          success: (v) => 'ok:$v',
          failure: (m, r) => 'ng:$m',
        ),
        'ok:2',
      );
      expect(
        LoadResult<int>.failure('だめ').when(
          success: (v) => 'ok:$v',
          failure: (m, r) => 'ng:$m:$r',
        ),
        'ng:だめ:true',
      );
    });

    test('等価性と hashCode', () {
      expect(LoadResult<int>.success(1), LoadResult<int>.success(1));
      expect(
        LoadResult<int>.success(1).hashCode,
        LoadResult<int>.success(1).hashCode,
      );
      expect(LoadResult<int>.success(1), isNot(LoadResult<int>.success(2)));
      expect(LoadResult<int>.success(1), isNot(LoadResult<int>.failure('x')));
      expect(
        LoadResult<int>.failure('失敗', retryable: false),
        LoadResult<int>.failure('失敗', retryable: false),
      );
      expect(
          LoadResult<int>.failure('失敗'), isNot(LoadResult<int>.failure('別')));
    });

    test('null 許容型なら success(null) を許す', () {
      final result = LoadResult<String?>.success(null);
      expect(result.isSuccess, isTrue);
      expect(result.valueOrNull, isNull);
    });

    test('不正引数は ArgumentError', () {
      expect(() => LoadResult<int>.failure(''), throwsArgumentError);
      expect(() => LoadResult<int>.failure('   '), throwsArgumentError);
    });
  });
}
