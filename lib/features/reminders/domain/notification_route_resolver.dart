/// 通知 payload（JSON 文字列）を画面遷移先へ解決する純粋層。
///
/// 通知の発火側（`FlutterLocalReminderService`）が載せた payload を、
/// タップ側（`NotificationTapRouter`）が解釈する。両者が同じ語彙を
/// 使うよう、論理 route 名と画面パスの対応は [NotificationRoutes] に一元化する。
library;

import 'dart:convert';

/// 通知から遷移しうる論理 route 名と、その画面パスの対応表（唯一の源）。
///
/// 発火側の payload・resolver の `allowedRoutes`・router の実遷移先は
/// すべてこの表から導く（食い違いを作らない）。
abstract final class NotificationRoutes {
  /// 書庫（積読リマインダーの既定遷移先）。
  static const String library = 'library';

  /// 読書画面（`id` に userBook / book の id を載せうる）。
  static const String reading = 'reading';

  /// 探索。
  static const String explore = 'explore';

  /// 足跡。
  static const String history = 'history';

  /// 次に読む一覧。
  static const String queue = 'queue';

  /// 論理 route 名 → go_router のパス。
  static const Map<String, String> paths = {
    library: '/',
    reading: '/reading',
    explore: '/explore',
    history: '/history',
    queue: '/reading-queue',
  };

  /// 通知タップで遷移してよい論理 route 名の集合。
  static Set<String> get all => Set<String>.unmodifiable(paths.keys);
}

/// 解決済みの遷移先（不変・値等価）。
///
/// [route] の妥当性は `assert` ではなくコンストラクタ本体で検証する
/// （release ビルドでも消えない）。
class ResolvedNotificationRoute {
  ResolvedNotificationRoute({required this.route, this.id}) {
    if (route.trim().isEmpty) {
      throw ArgumentError.value(route, 'route', '空の route は遷移先として不正');
    }
  }

  /// 論理 route 名（[NotificationRoutes] の語彙）。
  final String route;

  /// 付随 id（読書画面の対象など）。無ければ null。
  final String? id;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ResolvedNotificationRoute &&
          other.route == route &&
          other.id == id;

  @override
  int get hashCode => Object.hash(route, id);

  @override
  String toString() => 'ResolvedNotificationRoute(route: $route, id: $id)';
}

/// 通知 payload の解釈と組み立て。
abstract final class NotificationRouteResolver {
  /// `{"route":"library","id":"..."}` 形式の payload を解決する。
  ///
  /// 以下はすべて null を返す（**例外は投げない**）:
  /// - payload が null / 空 / 空白のみ
  /// - JSON として壊れている、またはオブジェクトでない
  /// - `route` が無い / 文字列でない / 空
  /// - `route` が [allowedRoutes] に無い（未知 route は遷移しない）
  ///
  /// `id` が文字列でない・空文字の場合は id なしとして扱う（route は活かす）。
  static ResolvedNotificationRoute? resolve(
    String? payload, {
    required Set<String> allowedRoutes,
  }) {
    if (payload == null) return null;
    final raw = payload.trim();
    if (raw.isEmpty) return null;

    final Object? decoded;
    try {
      decoded = jsonDecode(raw);
    } catch (_) {
      return null;
    }
    if (decoded is! Map<String, dynamic>) return null;

    final route = decoded['route'];
    if (route is! String) return null;
    if (route.trim().isEmpty) return null;
    if (!allowedRoutes.contains(route)) return null;

    final rawId = decoded['id'];
    final id = rawId is String && rawId.trim().isNotEmpty ? rawId : null;

    return ResolvedNotificationRoute(route: route, id: id);
  }

  /// 通知 payload を組み立てる（[resolve] の逆）。
  static String buildPayload(String route, {String? id}) {
    if (route.trim().isEmpty) {
      throw ArgumentError.value(route, 'route', '空の route は payload にできない');
    }
    if (id == null || id.isEmpty) return jsonEncode({'route': route});
    return jsonEncode({'route': route, 'id': id});
  }
}
