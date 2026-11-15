import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../history/data/reading_habit_provider.dart';
import '../../history/data/weekly_reading_provider.dart';

/// 読書セッション書き込み成功後に派生Providerを落とす唯一の窓口。画面ごとに散らすな。
///
/// 背景（禍津）: [readingHabitSessionsProvider] と [weeklyReadingMinutesProvider] は
/// autoDispose でない FutureProvider であるため、書き込み後に invalidate しない限り
/// 一度読んだキャッシュがアプリ再起動まで固定される。結果としてヒートマップ・
/// 週間グラフ・バッジ・日次目標が読書記録の追加後も古いままになる。
///
/// 呼び出し元は書き込み系リポジトリの「成功時のみ」フックに限定する
/// （`FallbackReadingSessionRepository.onSuccessfulWrite`）。画面や各Providerが
/// 個別に `ref.invalidate` を散らすと、書き込み経路の追加時に落とし忘れが再発する。
final Provider<void Function()> readingDerivedInvalidatorProvider =
    Provider<void Function()>((ref) {
  return () {
    ref.invalidate(readingHabitSessionsProvider);
    ref.invalidate(weeklyReadingMinutesProvider);
  };
});
