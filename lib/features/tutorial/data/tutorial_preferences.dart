import 'package:shared_preferences/shared_preferences.dart';

/// チュートリアル表示状態を管理するPrefKeys
class TutorialPrefKeys {
  TutorialPrefKeys._();

  /// 世界観説明を表示済みか
  static const String loreSeen = 'tutorial_lore_seen';

  /// 操作説明を表示済みか
  static const String operationSeen = 'tutorial_operation_seen';
}

/// shared_preferences を用いたチュートリアル表示状態管理
class TutorialPreferences {
  TutorialPreferences(this._prefs);

  final SharedPreferences _prefs;

  /// 世界観説明が未表示か
  bool get isLoreNotSeen => !(_prefs.getBool(TutorialPrefKeys.loreSeen) ?? false);

  /// 操作説明が未表示か
  bool get isOperationNotSeen =>
      !(_prefs.getBool(TutorialPrefKeys.operationSeen) ?? false);

  /// 世界観説明を表示済みにする
  Future<void> markLoreSeen() =>
      _prefs.setBool(TutorialPrefKeys.loreSeen, true);

  /// 操作説明を表示済みにする
  Future<void> markOperationSeen() =>
      _prefs.setBool(TutorialPrefKeys.operationSeen, true);

  /// 全チュートリアルが初回起動か（両方とも未表示）
  bool get isFirstLaunch => isLoreNotSeen && isOperationNotSeen;
}
