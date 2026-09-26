import '../../../core/json.dart';
import '../../config/domain/entities.dart';
import '../domain/entities.dart';

SalesOrder orderFrom(Map<String, dynamic> j) {
  final picking = j['picking'];
  var pickedAt = '';
  var pickingNumber = 0;
  var volumeCount = 0;
  if (picking is Map) {
    final m = Map<String, dynamic>.from(picking);
    pickedAt = asString(m, 'completed_at');
    pickingNumber = asInt(m, 'number');
    volumeCount = asInt(m, 'volume_count');
  }
  if (pickedAt.isEmpty && asString(j, 'status') == 'PICKED') {
    if (picking is Map) {
      pickedAt = asString(Map<String, dynamic>.from(picking), 'created_at');
    }
    if (pickedAt.isEmpty) {
      final picks = asMapList(j['picks']);
      if (picks.isNotEmpty) pickedAt = asString(picks.last, 'created_at');
    }
  }
  return SalesOrder(
    id: asString(j, 'id'),
    number: asInt(j, 'number'),
    customerId: asString(j, 'customer_id'),
    warehouseId: asString(j, 'warehouse_id'),
    paymentMethodId: asString(j, 'payment_method_id'),
    paymentTermId: asString(j, 'payment_term_id'),
    status: asString(j, 'status'),
    totalAmount: asDouble(j, 'total_amount'),
    createdAt: asString(j, 'created_at'),
    pickedAt: pickedAt,
    pickingNumber: pickingNumber,
    volumeCount: volumeCount,
    deliveryNote: asString(j, 'delivery_note'),
    paymentStatus: asString(j, 'payment_status'),
    deliveryDate: asString(j, 'delivery_date'),
    address: addressFrom(j['address']),
    items: asMapList(j['items']).map(orderLineFrom).toList(),
    picks: asMapList(j['picks'])
        .map(
          (i) => PickLine(
            productId: asString(i, 'product_id'),
            warehouseId: asString(i, 'warehouse_id'),
            quantity: asDouble(i, 'quantity'),
          ),
        )
        .toList(),
  );
}

OrderLine orderLineFrom(Map<String, dynamic> i) => OrderLine(
  productId: asString(i, 'product_id'),
  quantity: asDouble(i, 'quantity'),
  unitPrice: asDouble(i, 'unit_price'),
  components: asMapList(i['components']).isEmpty
      ? null
      : asMapList(i['components'])
          .map((c) => OrderItemComponent(productId: asString(c, 'product_id'), quantity: asDouble(c, 'quantity')))
          .toList(),
);

Address addressFrom(dynamic value) {
  if (value is! Map) return const Address();
  final m = Map<String, dynamic>.from(value);
  return Address(
    id: asString(m, 'id'),
    alias: asString(m, 'alias'),
    zip: asString(m, 'zip'),
    street: asString(m, 'street'),
    number: asString(m, 'number'),
    complement: asString(m, 'complement'),
    district: asString(m, 'district'),
    city: asString(m, 'city'),
    state: asString(m, 'state'),
  );
}
