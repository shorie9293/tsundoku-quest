import 'package:tsundoku_quest/domain/models/reading_session.dart';

/// 手動記録フォームの検証エラー種別
enum SessionEditError { emptyBook, invalidDuration, durationTooLong, invalidPageRange }

/// セッション編集の検証結果
class SessionEditValidation {
  final SessionEditError? error;

  /// 日本語の短い説明
  final String? message;

  const SessionEditValidation.valid()
      : error = null,
        message = null;

  const SessionEditValidation.invalid(SessionEditError error, String message)
      : error = error,
        message = message;

  bool get isValid => error == null;
}

/// 読書セッションの手動記録・修正のための純粋サービス。
///
/// UI（次工程）から利用する。検証・構築・整形はすべて静的メソッドで提供し、
/// 外部依存を持たない（テスト容易）。
class ReadingSessionEditorService {
  /// 1セッションとして許容する最大読書時間（24時間）
  static const int maxDurationMinutes = 24 * 60;

  ReadingSessionEditorService._();

  /// 手動記録フォームの入力検証（純粋）
  static SessionEditValidation validate({
    required String userBookId,
    required int durationMinutes,
    required int startPage,
    int? endPage,
  }) {
    if (userBookId.isEmpty) {
      return const SessionEditValidation.invalid(
        SessionEditError.emptyBook,
        '本を選択してください',
      );
    }
    if (durationMinutes <= 0) {
      return const SessionEditValidation.invalid(
        SessionEditError.invalidDuration,
        '読書時間は1分以上で入力してください',
      );
    }
    if (durationMinutes > maxDurationMinutes) {
      return const SessionEditValidation.invalid(
        SessionEditError.durationTooLong,
        '読書時間は24時間以内で入力してください',
      );
    }
    if (startPage < 0) {
      return const SessionEditValidation.invalid(
        SessionEditError.invalidPageRange,
        '開始ページは0以上で入力してください',
      );
    }
    if (endPage != null && endPage < startPage) {
      return const SessionEditValidation.invalid(
        SessionEditError.invalidPageRange,
        '終了ページは開始ページ以上で入力してください',
      );
    }
    return const SessionEditValidation.valid();
  }

  /// 検証済み入力から ReadingSession を構築（純粋）。
  ///
  /// startedAt はローカル DateTime で受け取り、モデルには UTC ISO8601
  /// 文字列で格納する。endedAt = startedAt + durationMinutes。
  /// createdAt は未指定なら now を代用する（UTC ISO）。
  static ReadingSession buildManual({
    required String id,
    required String userBookId,
    required DateTime startedAt,
    required int durationMinutes,
    required int startPage,
    int? endPage,
    DateTime? createdAt,
  }) {
    final utcStart = startedAt.toUtc();
    final nowUtc = (createdAt ?? DateTime.now()).toUtc();
    final endedAt =
        utcStart.add(Duration(minutes: durationMinutes)).toIso8601String();
    return ReadingSession(
      id: id,
      userBookId: userBookId,
      startedAt: utcStart.toIso8601String(),
      endedAt: endedAt,
      startPage: startPage,
      endPage: endPage,
      durationMinutes: durationMinutes,
      createdAt: nowUtc.toIso8601String(),
    );
  }

  /// 開始・終了時刻から読書時間（分）を算出。end が start 以前なら 0。
  static int durationFromTimes(DateTime start, DateTime end) {
    final diff = end.difference(start).inMinutes;
    if (diff <= 0) return 0;
    return diff;
  }

  /// 分 → 日本語表記。例: 45→'45分', 90→'1時間30分', 120→'2時間', 0→'0分'
  static String formatDuration(int minutes) {
    if (minutes < 60) return '${minutes}分';
    final hours = minutes ~/ 60;
    final rest = minutes % 60;
    if (rest == 0) return '$hours時間';
    return '$hours時間${rest}分';
  }

  /// DateTime → 'YYYY-MM-DD'（ローカル基準・ゼロ埋め）
  static String dateOnly(DateTime dt) {
    final mm = dt.month.toString().padLeft(2, '0');
    final dd = dt.day.toString().padLeft(2, '0');
    return '${dt.year}-$mm-$dd';
  }

  /// 'YYYY-MM-DD' + 時/分 → ローカル DateTime。不正な日付なら null。
  static DateTime? combineDateAndTime(String date, int hour, int minute) {
    final parts = date.split('-');
    if (parts.length != 3) return null;
    final year = int.tryParse(parts[0]);
    final month = int.tryParse(parts[1]);
    final day = int.tryParse(parts[2]);
    if (year == null || month == null || day == null) return null;
    if (year <= 0 || month < 1 || month > 12 || day < 1 || day > 31) {
      return null;
    }
    final dt = DateTime(year, month, day, hour, minute);
    // 例: 2月30日 → DateTime は 3月2日に繰り上げるため、
    // 月日が変わっていれば不正日付とみなす
    if (dt.month != month || dt.day != day) return null;
    return dt;
  }
}