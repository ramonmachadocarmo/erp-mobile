import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/sales/domain/kit_swap.dart';

void main() {
  // Mesmos exemplos usados para validar a versão web (kitSwap.ts).
  test('banana 12 -> tangerina 22/kg vira 0.5 kg', () {
    final eq = equivalentQuantity(12, 22, qtyStep('KG'));
    expect(eq.ok, isTrue);
    expect(eq.quantity, 0.5);
  });

  test('banana 12 -> laranja 14/kg vira 0.8 kg', () {
    final eq = equivalentQuantity(12, 14, qtyStep('KG'));
    expect(eq.ok, isTrue);
    expect(eq.quantity, 0.8);
  });

  test('banana 12 -> item por unidade a 14 é recusado (+16.7%)', () {
    final eq = equivalentQuantity(12, 14, qtyStep('UN'));
    expect(eq.ok, isFalse);
  });

  test('dentro de 15% é aceito', () {
    final eq = equivalentQuantity(12, 13, qtyStep('UN'));
    expect(eq.ok, isTrue);
    expect(eq.quantity, 1);
  });

  test('sem preço original ou do substituto é recusado', () {
    expect(equivalentQuantity(0, 14, 0.1).ok, isFalse);
    expect(equivalentQuantity(12, 0, 0.1).ok, isFalse);
  });

  test('withinPremium', () {
    expect(withinPremium(1.3, 12, 12), isFalse); // 1.3kg * 12 = 15.6, +30%
    expect(withinPremium(1.1, 12, 12), isTrue); // 1.1kg * 12 = 13.2, +10%
  });

  test('qtyStep', () {
    expect(qtyStep('KG'), 0.1);
    expect(qtyStep('kg'), 0.1);
    expect(qtyStep('L'), 0.1);
    expect(qtyStep('UN'), 1);
    expect(qtyStep('CX'), 1);
    expect(qtyStep(null), 1);
  });
}
