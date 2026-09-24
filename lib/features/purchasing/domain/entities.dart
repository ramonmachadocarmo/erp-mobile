import '../../config/domain/entities.dart';

// Quote/QuoteLine/QuoteStatus come from erp_schema (see ../../../../../erp-schema, sibling
// repo) instead of being hand-written here — this is the entity that drifted out of sync
// with the web frontend (missing discount_amount/delivery_amount) before that schema
// existed. Re-exported so existing call sites (`import '../domain/entities.dart'`) don't
// need to change their import path.
export 'package:erp_schema/erp_schema.dart' show Quote, QuoteLine, QuoteStatus;

class PurchaseOrder {
  const PurchaseOrder({
    required this.id,
    required this.supplierId,
    required this.status,
    required this.totalAmount,
    this.quoteId = '',
    this.paymentMethodId = '',
    this.paymentTermId = '',
    this.paymentStatus = 'PENDING',
    this.stockReceived = false,
    this.items = const [],
  });

  final String id;
  final String supplierId;
  // Eixo de entrega: APPROVED (pendente entrega), RECEIVED, CONFERRED (finalizado), CANCELLED.
  final String status;
  final double totalAmount;
  final String quoteId;
  final String paymentMethodId;
  final String paymentTermId;
  // Eixo financeiro, independente do de entrega: PENDING ou PAID.
  final String paymentStatus;
  // true depois que o estoque já recebeu a mercadoria — reabrir pra "pendente entrega" fica
  // bloqueado nesse caso (senão um novo "Receber" lançaria a entrada em dobro).
  final bool stockReceived;
  final List<PurchaseLine> items;
}

class PurchaseLine {
  const PurchaseLine({
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

class PurchasePrice {
  const PurchasePrice({
    required this.id,
    required this.sku,
    required this.previousPrice,
    required this.newPrice,
    required this.createdAt,
  });

  final String id;
  final String sku;
  final double previousPrice;
  final double newPrice;
  final String createdAt;
}

class PurchaseLookups {
  const PurchaseLookups({
    required this.suppliers,
    required this.products,
    required this.methods,
    required this.terms,
  });

  final List<Person> suppliers;
  final List<({String id, String sku, String name, double purchasePrice})> products;
  final List<PaymentMethod> methods;
  final List<PaymentTerm> terms;
}
