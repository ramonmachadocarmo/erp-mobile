class Product {
  const Product({
    required this.id,
    required this.sku,
    required this.name,
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

List<Category> flattenCategories(List<Category> nodes, [String prefix = '']) {
  final out = <Category>[];
  for (final n in nodes) {
    final label = prefix.isEmpty ? n.name : '$prefix / ${n.name}';
    out.add(Category(id: n.id, name: label, parentId: n.parentId));
    out.addAll(flattenCategories(n.children, label));
  }
  return out;
}
