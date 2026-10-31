import 'package:flutter/foundation.dart';

/// 読み込み状態の位相。
///
/// 「データが0件」と「読み込みに失敗した」を別の位相として扱うことで、
/// 通信断を「見つかりません」と誤表示しないための基盤。
enum LoadPhase { loading, data, empty, error }

/// 画面の読み込み状態（loading / data / empty / error）。
///
/// - `LoadState.loading()` — 読み込み中
/// - `LoadState.data(value)` — 取得成功（1件以上）
/// - `LoadState.empty()` — 取得成功だが0件
/// - `LoadState.error(message)` — 読み込み失敗（[cause] に元例外を保持）
@immutable
class LoadState<T> {
  final LoadPhase phase;
  final T? _value;
  final String? _message;
  final bool retryable;
  final Object? cause;

  const LoadState._(
    this.phase,
    this._value,
    this._message,
    this.retryable,
    this.cause,
  );

  /// 読み込み中。
  factory LoadState.loading() =>
      const LoadState._(LoadPhase.loading, null, null, true, null);

  /// 取得成功（[value] は必須。null を許す型なら null も可）。
  factory LoadState.data(T value) {
    if (value == null && null is! T) {
      throw ArgumentError.value(value, 'value', 'LoadState.data に null は渡せません');
    }
    return LoadState._(LoadPhase.data, value, null, true, null);
  }

  /// 取得成功だが0件。
  factory LoadState.empty() =>
      const LoadState._(LoadPhase.empty, null, null, true, null);

  /// 読み込み失敗。[message] は空であってはならない。
  factory LoadState.error(
    String message, {
    bool retryable = true,
    Object? cause,
  }) {
    if (message.trim().isEmpty) {
      throw ArgumentError.value(message, 'message', 'エラー文言が空です');
    }
    return LoadState._(LoadPhase.error, null, message, retryable, cause);
  }

  bool get isLoading => phase == LoadPhase.loading;
  bool get isData => phase == LoadPhase.data;
  bool get isEmpty => phase == LoadPhase.empty;
  bool get isError => phase == LoadPhase.error;

  /// data 以外では null。
  T? get valueOrNull => isData ? _value : null;

  /// error 以外では null。
  String? get message => isError ? _message : null;

  /// 位相ごとに分岐する。
  R when<R>({
    required R Function() loading,
    required R Function(T data) data,
    required R Function() empty,
    required R Function(String message, bool retryable) error,
  }) {
    switch (phase) {
      case LoadPhase.loading:
        return loading();
      case LoadPhase.data:
        return data(_value as T);
      case LoadPhase.empty:
        return empty();
      case LoadPhase.error:
        return error(_message!, retryable);
    }
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is LoadState<T> &&
        other.phase == phase &&
        other._value == _value &&
        other._message == _message &&
        other.retryable == retryable &&
        other.cause == cause;
  }

  @override
  int get hashCode => Object.hash(phase, _value, _message, retryable, cause);

  @override
  String toString() {
    switch (phase) {
      case LoadPhase.loading:
        return 'LoadState<$T>.loading()';
      case LoadPhase.data:
        return 'LoadState<$T>.data($_value)';
      case LoadPhase.empty:
        return 'LoadState<$T>.empty()';
      case LoadPhase.error:
        return 'LoadState<$T>.error($_message, retryable: $retryable)';
    }
  }
}

/// 一度きりの読み込み結果（成功 or 失敗）。
///
/// ネットワーク越しの1回の問い合わせ結果を、例外ではなく値として返す。
@immutable
class LoadResult<T> {
  final T? _value;
  final String? _message;
  final bool isSuccess;
  final bool retryable;
  final Object? cause;

  const LoadResult._(
    this.isSuccess,
    this._value,
    this._message,
    this.retryable,
    this.cause,
  );

  /// 成功。[value] は必須（null を許す型なら null も可）。
  factory LoadResult.success(T value) {
    if (value == null && null is! T) {
      throw ArgumentError.value(
        value,
        'value',
        'LoadResult.success に null は渡せません',
      );
    }
    return LoadResult._(true, value, null, true, null);
  }

  /// 失敗。[message] は空であってはならない。
  factory LoadResult.failure(
    String message, {
    bool retryable = true,
    Object? cause,
  }) {
    if (message.trim().isEmpty) {
      throw ArgumentError.value(message, 'message', 'エラー文言が空です');
    }
    return LoadResult._(false, null, message, retryable, cause);
  }

  bool get isFailure => !isSuccess;

  /// 成功時の値。失敗時は null（null 許容型の成功と区別するには [isSuccess]）。
  T? get valueOrNull => isSuccess ? _value : null;

  /// 失敗時の文言。成功時は null。
  String? get message => isSuccess ? null : _message;

  /// 成否で分岐する。
  R when<R>({
    required R Function(T value) success,
    required R Function(String message, bool retryable) failure,
  }) {
    if (isSuccess) return success(_value as T);
    return failure(_message!, retryable);
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is LoadResult<T> &&
        other.isSuccess == isSuccess &&
        other._value == _value &&
        other._message == _message &&
        other.retryable == retryable &&
        other.cause == cause;
  }

  @override
  int get hashCode =>
      Object.hash(isSuccess, _value, _message, retryable, cause);

  @override
  String toString() => isSuccess
      ? 'LoadResult<$T>.success($_value)'
      : 'LoadResult<$T>.failure($_message, retryable: $retryable)';
}
