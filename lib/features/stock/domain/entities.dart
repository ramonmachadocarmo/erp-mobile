class Product {
  const Product({
    required this.id,
    required this.sku,
    required this.name,
    this.popularName = '',
    this.barcode = '',
    this.ncm = '',
    this.categoryId = '',
    this.kind = 'FINAL',
    this.purchaseUom = '',
    this.saleUom = '',
    this.stockUom = '',
    this.salePrice = 0,
    this.purchasePrice = 0,
    this.weightKg = 0,
    this.volumeM3 = 0,
    this.conversions = const [],
  });

  final String id;
  final String sku;
  final String name;
  final String popularName;
  final String barcode;
  final String ncm;
  final String categoryId;
  final String kind;
  final String purchaseUom;
  final String saleUom;
  final String stockUom;
  final double salePrice;
  final double purchasePrice;
  final double weightKg;
  final double volumeM3;
  final List<UomConversion> conversions;

  String get kindLabel {
    if (kind == 'SUPPORT') return 'Apoio';
    if (kind == 'FIXED_ASSET') return 'Ativo fixo';
    return 'Final';
  }

  /// What labels/receipts print and sales screens show — popularName when set, else name.
  String get displayName => popularName.isEmpty ? name : popularName;
}

class UomConversion {
  const UomConversion({
    required this.fromUom,
    required this.toUom,
    required this.factor,
  });

  final String fromUom;
  final String toUom;
  final double factor;

  Map<String, dynamic> toJson() => {
        'from_uom': fromUom,
        'to_uom': toUom,
        'factor': factor,
      };
}

class Category {
  const Category({
    required this.id,
    required this.name,
    this.parentId = '',
    this.children = const [],
  });

  final String id;
  final String name;
  final String parentId;
  final List<Category> children;
}

class Warehouse {
  const Warehouse({required this.id, required this.code, required this.name});

  final String id;
  final String code;
  final String name;
}

class Balance {
  const Balance({
    required this.id,
    required this.productId,
    required this.warehouseId,
    required this.available,
    required this.reserved,
  });

  final String id;
  final String productId;
  final String warehouseId;
  final double available;
  final double reserved;
}

class SalePrice {
  const SalePrice({
    required this.id,
    required this.productId,
    required this.sku,
    required this.previousPrice,
    required this.newPrice,
    required this.createdAt,
  });

  final String id;
  final String productId;
  final String sku;
  final double previousPrice;
  final double newPrice;
  final String createdAt;
}

class Assembly {
  const Assembly({
    required this.id,
    required this.code,
    required this.name,
    this.productId = '',
    this.marginPercent = 0,
    this.cost = 0,
    this.suggestedPrice = 0,
    this.items = const [],
  });

  final String id;
  final String code;
  final String name;
  final String productId;
  final double marginPercent;
  final double cost;
  final double suggestedPrice;
  final List<AssemblyItem> items;
}

class AssemblyItem {
  const AssemblyItem({
    required this.productId,
    required this.quantity,
    required this.role,
  });

  final String productId;
  final double quantity;
  final String role;

  Map<String, dynamic> toJson() => {
        'product_id': productId,
        'quantity': quantity,
        'role': role,
      };
}

/// Um lançamento do kardex — entrada, saída ou transferência de estoque, manual ou derivada de
/// um pedido/nota (reference_doc_type). Só leitura no app (ver docs/MOBILE_PARITY_PLAN.md —
/// criar movimento manual/transferência fica só na web por enquanto).
class StockMovement {
  const StockMovement({
    required this.id,
    required this.productId,
    required this.warehouseId,
    required this.movementType,
    required this.quantity,
    required this.createdAt,
    this.subtype = '',
    this.referenceDocType = '',
  });

  final String id;
  final String productId;
  final String warehouseId;
  final String movementType;
  final String subtype;
  final double quantity;
  final String referenceDocType;
  final String createdAt;

  static const _subtypeLabels = {'PURCHASE': 'Compra', 'SALE': 'Venda', 'LOSS': 'Perda'};

  String get typeLabel {
    final sub = subtype.isEmpty ? '' : (_subtypeLabels[subtype] ?? subtype);
    switch (movementType) {
      case 'MANUAL_IN':
        return sub.isEmpty ? 'Entrada manual' : 'Entrada — $sub';
      case 'MANUAL_OUT':
        return sub.isEmpty ? 'Saída manual' : 'Saída — $sub';
      case 'TRANSFER_OUT':
        return 'Transferência — Saída';
      case 'TRANSFER_IN':
        return 'Transferência — Entrada';
      case 'PURCHASE_IN':
        return 'Entrada (compra)';
      case 'SALE_OUT':
        return 'Saída (NFe)';
      case 'RESERVATION_ADD':
        return 'Reserva';
      case 'RESERVATION_RELEASE':
        return 'Libera reserva';
      default:
        return movementType;
    }
  }

  String get originLabel {
    if (referenceDocType == 'MANUAL') return 'Manual';
    if (referenceDocType == 'TRANSFER') return 'Transferência';
    return referenceDocType;
  }
}

List<Category> flattenCategories(List<Category> nodes, [String prefix = '']) {
  final out = <Category>[];
  for (final n in nodes) {
    final label = prefix.isEmpty ? n.name : '$prefix / ${n.name}';
    out.add(Category(id: n.id, name: label, parentId: n.parentId));
    out.addAll(flattenCategories(n.children, label));
  }
  return out;
}
