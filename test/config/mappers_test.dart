import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/config/data/mappers.dart';
import 'package:mobile/features/config/domain/entities.dart';

void main() {
  test('centerFrom', () {
    final c = centerFrom({'id': '1', 'code': 'CD1', 'name': 'CD', 'lat': -3.1, 'lng': '-60'});
    expect(c.code, 'CD1');
    expect(c.lat, -3.1);
    expect(c.lng, -60);
  });

  test('vehicleFrom', () {
    final v = vehicleFrom({
      'id': '1',
      'code': 'VAN',
      'name': 'Van',
      'capacity_kg': 800,
      'capacity_m3': 4,
    });
    expect(v.capacityKg, 800);
    expect(v.capacityM3, 4);
    expect(v.active, isTrue);
  });

  test('Address.label', () {
    expect(const Address().label, '—');
    expect(
      const Address(alias: 'Casa', street: 'Rua A', number: '10', city: 'Manaus', state: 'AM').label,
      'Casa — Rua A, 10 · Manaus/AM',
    );
  });

  test('PaymentTerm.summary', () {
    expect(
      const PaymentTerm(id: '1', code: '2X', name: '2x', installments: [
        Installment(days: 30, percent: 50),
        Installment(days: 60, percent: 50),
      ]).summary,
      '50.0% em 30d · 50.0% em 60d',
    );
  });
}
