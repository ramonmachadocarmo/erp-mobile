import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/app/nav.dart';

void main() {
  test('logistics nav', () {
    final paths = navGroups.expand((g) => g.items.map((i) => i.path)).toList();
    // Rotas e Entrega ficam só na web (ver docs/MOBILE_PARITY_PLAN.md) — o app não navega
    // pra elas, mas continuam em menuCatalog pra matriz de permissões.
    expect(paths, containsAll(['/logistica/entrada', '/logistica/conferencia', '/config/usuarios']));
    expect(paths, isNot(contains('/logistica/rotas')));
    expect(paths, isNot(contains('/logistica/entrega')));
  });

  test('menuCatalog still lists every web screen, rendered or not', () {
    final paths = menuCatalog.expand((g) => g.items.map((i) => i.path)).toList();
    expect(paths, containsAll(['/logistica/rotas', '/logistica/entrega']));
  });
}
