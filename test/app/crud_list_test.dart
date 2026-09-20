import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile/app/widgets/crud_list.dart';
import 'package:mobile/app/widgets/list_filters.dart';
import 'package:mobile/features/auth/domain/access.dart';
import 'package:mobile/features/auth/domain/entities/user.dart';
import 'package:mobile/features/auth/presentation/providers/auth_notifier.dart';

class _Item {
  const _Item(this.name, this.kind);
  final String name;
  final String kind;
}

const _items = [
  _Item('Açúcar cristal', 'FINAL'),
  _Item('Sacola plástica', 'SUPPORT'),
  _Item('Arroz', 'FINAL'),
];

Widget _app({List<ListFilter<_Item>> filters = const []}) {
  const master = User(id: '1', email: 'a@b.c', name: 'A', roleCode: 'MASTER');
  final router = GoRouter(
    initialLocation: '/estoque/produtos',
    routes: [
      GoRoute(
        path: '/estoque/produtos',
        builder: (_, _) => CrudList<_Item>(
          value: const AsyncData(_items),
          onRefresh: () async {},
          titleOf: (i) => i.name,
          subtitleOf: (i) => i.kind,
          filters: filters,
        ),
      ),
    ],
  );
  return ProviderScope(
    overrides: [accessProvider.overrideWithValue(const Access(master))],
    child: MaterialApp.router(routerConfig: router),
  );
}

void main() {
  test('normalizeSearch ignores case and accents', () {
    expect(normalizeSearch('Açúcar'), 'acucar');
    expect(normalizeSearch('PLÁSTICA'), 'plastica');
  });

  test('byValue derives distinct sorted options from the data', () {
    final f = ListFilter<_Item>.byValue(label: 'Tipo', valueOf: (i) => i.kind);
    expect(f.optionsFor(_items).map((o) => o.value), ['FINAL', 'SUPPORT']);
    expect(f.matches(_items[1], 'SUPPORT'), isTrue);
    expect(f.matches(_items[1], 'FINAL'), isFalse);
  });

  testWidgets('search narrows the list and shows an empty result message', (t) async {
    await t.pumpWidget(_app());
    expect(find.text('Arroz'), findsOneWidget);
    expect(find.text('Sacola plástica'), findsOneWidget);

    await t.enterText(find.byType(TextField), 'acucar');
    await t.pump();
    expect(find.text('Açúcar cristal'), findsOneWidget);
    expect(find.text('Arroz'), findsNothing);

    await t.enterText(find.byType(TextField), 'zzz');
    await t.pump();
    expect(find.text('Nenhum resultado'), findsOneWidget);
  });

  testWidgets('a dropdown filter combines with the search', (t) async {
    await t.pumpWidget(
      _app(
        filters: [
          ListFilter<_Item>.byValue(label: 'Tipo', valueOf: (i) => i.kind),
        ],
      ),
    );
    await t.tap(find.byType(DropdownButtonFormField<String>));
    await t.pumpAndSettle();
    await t.tap(find.text('SUPPORT').last);
    await t.pumpAndSettle();
    expect(find.text('Sacola plástica'), findsOneWidget);
    expect(find.text('Arroz'), findsNothing);

    await t.enterText(find.byType(TextField).first, 'arroz');
    await t.pump();
    expect(find.text('Nenhum resultado'), findsOneWidget);
  });
}
