import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/app/nav.dart';

void main() {
  test('logistics nav', () {
    final paths = navGroups.expand((g) => g.items.map((i) => i.path)).toList();
    expect(paths, containsAll(['/logistica/rotas', '/logistica/entrega', '/config/usuarios']));
  });
}
