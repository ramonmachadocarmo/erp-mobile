import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/auth/data/repositories/users_repository_impl.dart';

void main() {
  test('userFrom', () {
    final u = userFrom({'id': 1, 'email': 'a@erp.local', 'name': 'Ana'});
    expect(u.id, '1');
    expect(u.email, 'a@erp.local');
    expect(u.name, 'Ana');
  });
}
