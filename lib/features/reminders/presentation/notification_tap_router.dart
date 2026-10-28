/// 通知タップ → 画面遷移の薄い配線。
///
/// 判断（payload の解釈）は [NotificationRouteResolver] が担い、
/// ここは「解決済み遷移先を go_router へ渡す」だけを行う。
/// 未知 route は何もしない（誤爆で画面が飛ばない）。
library;

import 'package:go_router/go_router.dart';
import '../domain/notification_route_resolver.dart';

class NotificationTapRouter {
  /// [router] か [routerGetter] のどちらかを注入する。
  ///
  /// [routerGetter] は遅延取得用（production では `AppRouter.router` の
  /// 初回参照を遷移時まで遅らせ、起動順の循環を避ける）。
  /// [allowedRoutes] を省略すると [NotificationRoutes.all] を使う。
  NotificationTapRouter({
    GoRouter? router,
    GoRouter Function()? routerGetter,
    Set<String>? allowedRoutes,
  })  : _router = router,
        _routerGetter = routerGetter,
        allowedRoutes = allowedRoutes ?? NotificationRoutes.all;

  final GoRouter? _router;
  final GoRouter Function()? _routerGetter;

  /// 遷移を許可する論理 route 名（resolver の `allowedRoutes` と同一の集合）。
  final Set<String> allowedRoutes;

  /// 論理 route 名 → 画面パスの対応表（[NotificationRoutes.paths] と同一）。
  static Map<String, String> get routePaths => NotificationRoutes.paths;

  /// resolver に渡す許可集合（対応表のキーと常に一致する）。
  static Set<String> get defaultAllowedRoutes => NotificationRoutes.all;

  GoRouter get _effectiveRouter {
    final router = _router;
    if (router != null) return router;
    final getter = _routerGetter;
    if (getter == null) {
      throw StateError('NotificationTapRouter に router も routerGetter も無い');
    }
    return getter();
  }

  /// 解決済み遷移先へ遷移する。遷移したら true、しなかったら false。
  bool handle(ResolvedNotificationRoute? resolved) {
    if (resolved == null) return false;
    if (!allowedRoutes.contains(resolved.route)) return false;
    final path = NotificationRoutes.paths[resolved.route];
    if (path == null) return false;

    final id = resolved.id;
    final location = (id == null || id.isEmpty)
        ? path
        : Uri(path: path, queryParameters: {'id': id}).toString();
    _effectiveRouter.go(location);
    return true;
  }

  /// 通知サービスの `onRouteSelected` にそのまま渡せる形。
  void onNotificationTap(ResolvedNotificationRoute resolved) {
    handle(resolved);
  }

  /// payload 文字列から解決して遷移する（テスト・起動時保留の回収用）。
  void handlePayload(String? payload) {
    handle(
      NotificationRouteResolver.resolve(payload, allowedRoutes: allowedRoutes),
    );
  }
}
