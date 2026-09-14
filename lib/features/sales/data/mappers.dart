import '../../../core/json.dart';
import '../../config/data/mappers.dart';
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
    address: addressFrom(j['address']),
    items: asMapList(j['items'])
        .map(
          (i) => OrderLine(
            productId: asString(i, 'product_id'),
            quantity: asDouble(i, 'quantity'),
            unitPrice: asDouble(i, 'unit_price'),
          ),
        )
        .toList(),
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

DeliveryPlan planFrom(Map<String, dynamic> j) => DeliveryPlan(
      id: asString(j, 'id'),
      status: asString(j, 'status'),
      vehicleName: asString(j, 'vehicle_name'),
      vehicleCode: asString(j, 'vehicle_code'),
      centerName: asString(j, 'center_name'),
      centerLat: asDouble(j, 'center_lat'),
      centerLng: asDouble(j, 'center_lng'),
      distanceM: asDouble(j, 'distance_m'),
      durationS: asDouble(j, 'duration_s'),
      weightKg: asDouble(j, 'weight_kg'),
      volumeM3: asDouble(j, 'volume_m3'),
      occupancyPct: asDouble(j, 'occupancy_pct'),
      stops: asMapList(j['stops']).map(stopFrom).toList(),
      options: asMapList(j['options']).map(optionFrom).toList(),
    );

RouteOption optionFrom(Map<String, dynamic> j) => RouteOption(
      label: asString(j, 'label'),
      distanceM: asDouble(j, 'distance_m'),
      durationS: asDouble(j, 'duration_s'),
      selected: asBool(j, 'selected'),
      stops: asMapList(j['stops']).map(stopFrom).toList(),
    );

DeliveryCandidate candidateFrom(Map<String, dynamic> j) => DeliveryCandidate(
      id: asString(j, 'id'),
      customerId: asString(j, 'customer_id'),
      weightKg: asDouble(j, 'weight_kg'),
      volumeM3: asDouble(j, 'volume_m3'),
      hasGeo: asBool(j, 'has_geo'),
      planned: asBool(j, 'planned'),
      address: addressFrom(j['address']),
    );

DeliveryStop stopFrom(Map<String, dynamic> j) => DeliveryStop(
      seq: asInt(j, 'seq'),
      salesOrderId: asString(j, 'sales_order_id'),
      customerId: asString(j, 'customer_id'),
      distanceM: asDouble(j, 'distance_m'),
      durationS: asDouble(j, 'duration_s'),
      lat: asDouble(j, 'lat'),
      lng: asDouble(j, 'lng'),
      address: addressFrom(j['address']),
    );

PlanResult planResultFrom(Map<String, dynamic> j) => PlanResult(
      plans: asMapList(j['plans']).map(planFrom).toList(),
      skipped: asMapList(j['skipped'])
          .map((s) => SkippedStop(orderId: asString(s, 'order_id'), reason: asString(s, 'reason')))
          .toList(),
    );
