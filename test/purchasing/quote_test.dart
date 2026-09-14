import 'package:erp_schema/erp_schema.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Quote.fromJson parses discount/delivery/items from a server response', () {
    // Regression test: this Quote type used to be hand-written in this app and was
    // missing discount_amount/delivery_amount entirely, silently dropping them from
    // every request. It now comes from erp_schema (generated from the shared schema),
    // so this proves the mobile app's actual dependency wiring round-trips correctly,
    // not just that the schema itself is correct.
    final q = Quote.fromJson({
      'id': 'q1',
      'supplier_id': 's1',
      'status': 'OPEN',
      'subtotal_amount': 20.0,
      'discount_amount': 5.0,
      'delivery_amount': 3.0,
      'total_amount': 18.0,
      'notes': 'urgente',
      'items': [
        {'product_id': 'p1', 'quantity': 2, 'unit_price': 10.0, 'total_price': 20.0},
      ],
      'created_at': '2026-01-15T10:00:00.000Z',
    });

    expect(q.id, 'q1');
    expect(q.supplierId, 's1');
    expect(q.status, QuoteStatus.OPEN);
    expect(q.discountAmount, 5.0);
    expect(q.deliveryAmount, 3.0);
    expect(q.totalAmount, 18.0);
    expect(q.items, hasLength(1));
    expect(q.items.single.productId, 'p1');
  });

  test('a create-request Quote serializes discount/delivery even with no id/status yet', () {
    final q = Quote(
      supplierId: 's1',
      notes: '',
      discountAmount: 5,
      deliveryAmount: 3,
      items: [QuoteLine(productId: 'p1', quantity: 2, unitPrice: 10)],
    );

    final json = q.toJson();

    expect(json['supplier_id'], 's1');
    expect(json['discount_amount'], 5);
    expect(json['delivery_amount'], 3);
    expect(json['id'], isNull);
    expect(json['status'], isNull);
    expect((json['items'] as List).single['product_id'], 'p1');
  });
}
