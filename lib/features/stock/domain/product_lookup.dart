import '../../../core/scan_code.dart';
import 'entities.dart';

/// Produto cujo código de barras ou SKU é [code] (sem diferenciar maiúsculas); null se não houver.
Product? findProductByCode(Iterable<Product> products, String code) {
  for (final p in products) {
    if (p.barcode.isNotEmpty && sameCode(p.barcode, code)) return p;
    if (p.sku.isNotEmpty && sameCode(p.sku, code)) return p;
  }
  return null;
}
