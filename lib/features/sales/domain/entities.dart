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
    this.deliveryDate = '',
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

  /// Dia que o cliente espera o pedido (YYYY-MM-DD, "" = não informado). O planejamento de
  /// rotas (web) agrupa as entregas por essa data — ver docs/MOBILE_PARITY_PLAN.md.
  final String deliveryDate;
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

/// Substitui um item da receita de um kit numa linha do pedido — ver kit_swap.dart. Ausente
/// (ou vazio) significa "usa a receita padrão cadastrada em Estoque -> Montagem".
class OrderItemComponent {
  const OrderItemComponent({required this.productId, required this.quantity});

  final String productId;
  final double quantity;

  Map<String, dynamic> toJson() => {'product_id': productId, 'quantity': quantity};
}

class OrderLine {
  const OrderLine({
    required this.productId,
    required this.quantity,
    required this.unitPrice,
    this.components,
  });

  final String productId;
  final double quantity;
  final double unitPrice;
  final List<OrderItemComponent>? components;

  Map<String, dynamic> toJson() => {
    'product_id': productId,
    'quantity': quantity,
    'unit_price': unitPrice,
    if (components != null && components!.isNotEmpty)
      'components': components!.map((c) => c.toJson()).toList(),
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
    ({String id, String sku, String name, String barcode, String saleUom, double salePrice})
  >
  products;
  final List<({String id, String code, String name})> warehouses;
  final List<PaymentMethod> methods;
  final List<PaymentTerm> terms;
}
