import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tsundoku_quest/domain/repositories/shelf_repository.dart';
import 'package:tsundoku_quest/features/shelves/data/shelf_repository_provider.dart';
import 'package:tsundoku_quest/features/shelves/presentation/shelf_management_screen.dart';

Widget _wrap(ShelfRepository repo) {
  return ProviderScope(
    overrides: [shelfRepositoryProvider.overrideWithValue(repo)],
    child: const MaterialApp(home: ShelfManagementScreen()),
  );
}

void main() {
  testWidgets('空状態と作成ボタンに semantics identifier が付与されている', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(_wrap(InMemoryShelfRepository()));
    await tester.pumpAndSettle();

    expect(find.bySemanticsIdentifier('btn_shelf_create'), findsOneWidget);
    expect(find.bySemanticsIdentifier('sec_shelves_empty'), findsOneWidget);

    handle.dispose();
  });

  testWidgets('作成ダイアログ内の要素にも identifier が付与されている', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(_wrap(InMemoryShelfRepository()));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('棚を作る'));
    await tester.pumpAndSettle();

    expect(find.bySemanticsIdentifier('txt_shelf_name'), findsOneWidget);
    expect(find.bySemanticsIdentifier('btn_shelf_name_cancel'), findsOneWidget);
    expect(find.bySemanticsIdentifier('btn_shelf_name_save'), findsOneWidget);

    handle.dispose();
  });

  testWidgets('棚一覧の identifier は1回だけ発行され、行は棚 id で一意になる',
      (tester) async {
    final handle = tester.ensureSemantics();
    final repo = InMemoryShelfRepository();
    final first = await repo.createShelf('棚A');
    final second = await repo.createShelf('棚B');

    await tester.pumpWidget(_wrap(repo));
    await tester.pumpAndSettle();

    // 一覧そのものは外側で1回だけ包む
    expect(find.bySemanticsIdentifier('list_shelves'), findsOneWidget);
    expect(find.bySemanticsIdentifier('sec_shelves_empty'), findsNothing);

    // 行ごとの identifier は棚 id を含む一意な文字列
    expect(find.bySemanticsIdentifier('item_shelf_${first.id}'),
        findsOneWidget);
    expect(find.bySemanticsIdentifier('item_shelf_${second.id}'),
        findsOneWidget);
    expect(find.bySemanticsIdentifier('btn_shelf_menu_${first.id}'),
        findsOneWidget);
    expect(find.bySemanticsIdentifier('btn_shelf_menu_${second.id}'),
        findsOneWidget);

    handle.dispose();
  });

  testWidgets('削除ダイアログの操作要素に identifier が付与されている', (tester) async {
    final handle = tester.ensureSemantics();
    final repo = InMemoryShelfRepository();
    final shelf = await repo.createShelf('棚A');

    await tester.pumpWidget(_wrap(repo));
    await tester.pumpAndSettle();

    await tester.tap(find.bySemanticsIdentifier('btn_shelf_menu_${shelf.id}'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('削除').last);
    await tester.pumpAndSettle();

    expect(find.bySemanticsIdentifier('btn_shelf_delete_cancel'),
        findsOneWidget);
    expect(find.bySemanticsIdentifier('btn_shelf_delete_confirm'),
        findsOneWidget);

    handle.dispose();
  });

  testWidgets('既存の作成フロー（tooltip 起点）の挙動は不変', (tester) async {
    final repo = InMemoryShelfRepository();
    await tester.pumpWidget(_wrap(repo));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('棚を作る'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '積ん読の山');
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();

    expect(find.text('積ん読の山'), findsOneWidget);
    expect(await repo.listShelves(), hasLength(1));
  });
}
