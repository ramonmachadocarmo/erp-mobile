import 'package:flutter_test/flutter_test.dart';

import 'package:mobile/app/nav.dart';
import 'package:mobile/features/auth/domain/access.dart';
import 'package:mobile/features/auth/domain/entities/user.dart';

User _user({String role = 'VENDAS', Map<String, int> menus = const {}}) => User(
      id: '1',
      email: 'a@b.c',
      name: 'A',
      roleCode: role,
      menuPermissions: menus,
    );

void main() {
  test('master can edit everything', () {
    final a = Access(_user(role: 'MASTER'));
    expect(a.canEdit('/config/usuarios'), isTrue);
    expect(a.filterNav(navGroups), navGroups);
  });

  test('menu key differs from mobile path', () {
    final a = Access(_user(menus: {'/producao/produtos': 1}));
    expect(a.canView('/estoque/produtos'), isTrue);
    expect(a.canEdit('/estoque/produtos'), isFalse);
    expect(a.canView('/estoque/saldos'), isFalse);
  });

  test('nested route inherits parent level, non-menu routes are open', () {
    final a = Access(_user(menus: {'/logistica/conferencia': 2}));
    expect(a.canEdit('/logistica/conferencia/42'), isTrue);
    expect(a.canView('/login'), isTrue);
  });

  test('landing page and nav filtering follow the role', () {
    final a = Access(_user(menus: {'/estoque/saldos': 1}));
    expect(a.firstAllowedPath, '/estoque/saldos');
    final groups = a.filterNav(navGroups);
    expect(groups.length, 1);
    expect(groups.single.items.single.path, '/estoque/saldos');
    expect(Access(_user()).firstAllowedPath, isNull);
  });
}
