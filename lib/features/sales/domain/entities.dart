import '../../config/domain/entities.dart';

class SalesOrder {
  const SalesOrder({
    required this.id,
    required this.customerId,
    required this.warehouseId,
    required this.paymentMethodId,
    required this.paymentTermId,
    required this.status,
    required this.totalAmount,
    this.items = const [],
    this.picks = const [],
    this.createdAt = '',
    this.pickedAt = '',
    this.pickingNumber = 0,
    this.volumeCount = 0,
    this.address = const Address(),
    this.deliveryNote = '',
    this.paymentStatus = '',
  });

  final String id;
  final String customerId;
  final String warehouseId;
  final String paymentMethodId;
  final String paymentTermId;
  final String status;
  final double totalAmount;
  final List<OrderLine> items;
  final List<PickLine> picks;
  final String createdAt;
  final String pickedAt;
  final int pickingNumber;
  final int volumeCount;
  final Address address;
  final String deliveryNote;

  /// Only sent on create: PDV counter sales are collected on the spot (PAID).
  final String paymentStatus;
}

class PickLine {
  const PickLine({
    required this.productId,
    required this.warehouseId,
    required this.quantity,
  });

  final String productId;
  final String warehouseId;
  final double quantity;
}

class OrderLine {
  const OrderLine({
    required this.productId,
    required this.quantity,
    required this.unitPrice,
  });

  final String productId;
  final double quantity;
  final double unitPrice;

  Map<String, dynamic> toJson() => {
    'product_id': productId,
    'quantity': quantity,
    'unit_price': unitPrice,
  };
}

class SalesLookups {
  const SalesLookups({
    required this.customers,
    required this.products,
    required this.warehouses,
    required this.methods,
    required this.terms,
  });

  final List<Person> customers;
  final List<
    ({String id, String sku, String name, String barcode, double salePrice})
  >
  products;
  final List<({String id, String code, String name})> warehouses;
  final List<PaymentMethod> methods;
  final List<PaymentTerm> terms;
}

class DeliveryPlan {
  const DeliveryPlan({
    required this.id,
    required this.status,
    this.vehicleName = '',
    this.vehicleCode = '',
    this.centerName = '',
    this.centerLat = 0,
    this.centerLng = 0,
    this.distanceM = 0,
    this.durationS = 0,
    this.weightKg = 0,
    this.volumeM3 = 0,
    this.occupancyPct = 0,
    this.stops = const [],
    this.options = const [],
  });

  final String id;
  final String status;
  final String vehicleName;
  final String vehicleCode;
  final String centerName;
  final double centerLat;
  final double centerLng;
  final double distanceM;
  final double durationS;
  final double weightKg;
  final double volumeM3;
  final double occupancyPct;
  final List<DeliveryStop> stops;
  final List<RouteOption> options;
}

class DeliveryStop {
  const DeliveryStop({
    required this.seq,
    required this.salesOrderId,
    this.customerId = '',
    this.address = const Address(),
    this.distanceM = 0,
    this.durationS = 0,
    this.lat = 0,
    this.lng = 0,
  });

  final int seq;
  final String salesOrderId;
  final String customerId;
  final Address address;
  final double distanceM;
  final double durationS;
  final double lat;
  final double lng;
}

class RouteOption {
  const RouteOption({
    required this.label,
    this.distanceM = 0,
    this.durationS = 0,
    this.stops = const [],
    this.selected = false,
  });

  final String label;
  final double distanceM;
  final double durationS;
  final List<DeliveryStop> stops;
  final bool selected;
}

class PlanResult {
  const PlanResult({this.plans = const [], this.skipped = const []});

  final List<DeliveryPlan> plans;
  final List<SkippedStop> skipped;
}

class SkippedStop {
  const SkippedStop({required this.orderId, required this.reason});

  final String orderId;
  final String reason;
}

class DeliveryCandidate {
  const DeliveryCandidate({
    required this.id,
    required this.customerId,
    this.address = const Address(),
    this.weightKg = 0,
    this.volumeM3 = 0,
    this.hasGeo = false,
    this.planned = false,
  });

  final String id;
  final String customerId;
  final Address address;
  final double weightKg;
  final double volumeM3;
  final bool hasGeo;
  final bool planned;
}
