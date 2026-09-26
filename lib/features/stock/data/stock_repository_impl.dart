import '../../../core/error/result.dart';
import '../../../core/json.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_guard.dart';
import '../../config/data/mappers.dart';
import '../../config/domain/entities.dart';
import '../domain/entities.dart';
import '../domain/stock_repository.dart';

class StockRepositoryImpl implements StockRepository {
  const StockRepositoryImpl(this._client);

  final ApiClient _client;

  Product _product(Map<String, dynamic> j) => Product(
        id: asString(j, 'id'),
        sku: asString(j, 'sku'),
        name: asString(j, 'name'),
        popularName: asString(j, 'popular_name'),
        barcode: asString(j, 'barcode'),
        ncm: asString(j, 'ncm'),
        categoryId: asString(j, 'category_id'),
        kind: asString(j, 'kind').isEmpty ? 'FINAL' : asString(j, 'kind'),
        purchaseUom: asString(j, 'purchase_uom'),
        saleUom: asString(j, 'sale_uom'),
        stockUom: asString(j, 'stock_uom'),
        salePrice: asDouble(j, 'sale_price'),
        purchasePrice: asDouble(j, 'purchase_price'),
        weightKg: asDouble(j, 'weight_kg'),
        volumeM3: asDouble(j, 'volume_m3'),
        conversions: asMapList(j['uom_conversions'])
            .map(
              (c) => UomConversion(
                fromUom: asString(c, 'from_uom'),
                toUom: asString(c, 'to_uom'),
                factor: asDouble(c, 'factor'),
              ),
            )
            .toList(),
      );

  Category _category(Map<String, dynamic> j) => Category(
        id: asString(j, 'id'),
        name: asString(j, 'name'),
        parentId: asString(j, 'parent_id'),
        children: asMapList(j['children']).map(_category).toList(),
      );

  @override
  Future<Result<List<Product>>> products() => guardApi(() async {
        final list = await _client.getList('/api/stock/products');
        return list.map(_product).toList();
      });

  @override
  Future<Result<Product>> saveProduct(Product p) => guardApi(() async {
        final body = {
          'barcode': p.barcode,
          'name': p.name,
          'popular_name': p.popularName,
          'category_id': p.categoryId,
          'ncm': p.ncm,
          'kind': p.kind,
          'purchase_uom': p.purchaseUom,
          'sale_uom': p.saleUom,
          'stock_uom': p.stockUom.isEmpty ? p.saleUom : p.stockUom,
          'weight_kg': p.weightKg,
          'volume_m3': p.volumeM3,
          'uom_conversions': p.conversions.map((c) => c.toJson()).toList(),
          'attributes': <String, dynamic>{},
        };
        final json = p.id.isEmpty
            ? await _client.post('/api/stock/products', body: body)
            : await _client.put('/api/stock/products/${p.id}', body: body);
        return _product(json);
      });

  @override
  Future<Result<void>> deleteProduct(String id) =>
      guardApi(() => _client.delete('/api/stock/products/$id'));

  @override
  Future<Result<List<Category>>> categories() => guardApi(() async {
        final list = await _client.getList('/api/stock/categories');
        return list.map(_category).toList();
      });

  @override
  Future<Result<Category>> saveCategory(Category c) => guardApi(() async {
        final body = {'name': c.name, 'parent_id': c.parentId};
        final json = c.id.isEmpty
            ? await _client.post('/api/stock/categories', body: body)
            : await _client.put('/api/stock/categories/${c.id}', body: body);
        return _category(json);
      });

  @override
  Future<Result<void>> deleteCategory(String id) =>
      guardApi(() => _client.delete('/api/stock/categories/$id'));

  @override
  Future<Result<List<Warehouse>>> warehouses() => guardApi(() async {
        final list = await _client.getList('/api/stock/warehouses');
        return list
            .map(
              (j) => Warehouse(
                id: asString(j, 'id'),
                code: asString(j, 'code'),
                name: asString(j, 'name'),
              ),
            )
            .toList();
      });

  @override
  Future<Result<Warehouse>> saveWarehouse(Warehouse w) => guardApi(() async {
        final body = {'code': w.code, 'name': w.name};
        final json = w.id.isEmpty
            ? await _client.post('/api/stock/warehouses', body: body)
            : await _client.put('/api/stock/warehouses/${w.id}', body: body);
        return Warehouse(
          id: asString(json, 'id'),
          code: asString(json, 'code'),
          name: asString(json, 'name'),
        );
      });

  @override
  Future<Result<List<Balance>>> balances() => guardApi(() async {
        final list = await _client.getList('/api/stock/balances');
        return list
            .map(
              (j) => Balance(
                id: asString(j, 'id'),
                productId: asString(j, 'product_id'),
                warehouseId: asString(j, 'warehouse_id'),
                available: asDouble(j, 'quantity_available'),
                reserved: asDouble(j, 'quantity_reserved'),
              ),
            )
            .toList();
      });

  @override
  Future<Result<void>> createMovement({
    required String productId,
    required String warehouseId,
    required String direction,
    required String subtype,
    required double quantity,
  }) =>
      guardApi(
        () => _client.post(
          '/api/stock/movements',
          body: {
            'product_id': productId,
            'warehouse_id': warehouseId,
            'direction': direction,
            'subtype': subtype,
            'quantity': quantity,
          },
        ),
      );

  @override
  Future<Result<void>> transferStock({
    required String productId,
    required String fromWarehouseId,
    required String toWarehouseId,
    required double quantity,
  }) =>
      guardApi(
        () => _client.post(
          '/api/stock/movements/transfer',
          body: {
            'product_id': productId,
            'from_warehouse_id': fromWarehouseId,
            'to_warehouse_id': toWarehouseId,
            'quantity': quantity,
          },
        ),
      );

  @override
  Future<Result<List<SalePrice>>> salePrices() => guardApi(() async {
        final list = await _client.getList('/api/stock/prices/sale');
        return list
            .map(
              (j) => SalePrice(
                id: asString(j, 'id'),
                productId: asString(j, 'product_id'),
                sku: asString(j, 'sku'),
                previousPrice: asDouble(j, 'previous_price'),
                newPrice: asDouble(j, 'new_price'),
                createdAt: asString(j, 'created_at'),
              ),
            )
            .toList();
      });

  @override
  Future<Result<void>> createSalePrice({
    required String productId,
    required double newPrice,
  }) =>
      guardApi(
        () => _client.post(
          '/api/stock/prices/sale',
          body: {'product_id': productId, 'new_price': newPrice},
        ),
      );

  @override
  Future<Result<List<Assembly>>> assemblies() => guardApi(() async {
        final list = await _client.getList('/api/stock/assemblies');
        return list
            .map(
              (j) => Assembly(
                id: asString(j, 'id'),
                code: asString(j, 'code'),
                name: asString(j, 'name'),
                productId: asString(j, 'product_id'),
                marginPercent: asDouble(j, 'margin_percent'),
                cost: asDouble(j, 'cost'),
                suggestedPrice: asDouble(j, 'suggested_price'),
                items: asMapList(j['items'])
                    .map(
                      (i) => AssemblyItem(
                        productId: asString(i, 'product_id'),
                        quantity: asDouble(i, 'quantity'),
                        role: asString(i, 'role'),
                      ),
                    )
                    .toList(),
              ),
            )
            .toList();
      });

  @override
  Future<Result<Assembly>> saveAssembly(Assembly a) => guardApi(() async {
        final body = {
          'code': a.code,
          'name': a.name,
          'product_id': a.productId,
          'margin_percent': a.marginPercent,
          'items': a.items.map((i) => i.toJson()).toList(),
        };
        final json = a.id.isEmpty
            ? await _client.post('/api/stock/assemblies', body: body)
            : await _client.put('/api/stock/assemblies/${a.id}', body: body);
        return Assembly(
          id: asString(json, 'id'),
          code: asString(json, 'code'),
          name: asString(json, 'name'),
          productId: asString(json, 'product_id'),
          marginPercent: asDouble(json, 'margin_percent'),
          cost: asDouble(json, 'cost'),
          suggestedPrice: asDouble(json, 'suggested_price'),
        );
      });

  @override
  Future<Result<List<Unit>>> units() => guardApi(() async {
        final list = await _client.getList('/api/config/units');
        return list.map(unitFrom).toList();
      });

  @override
  Future<Result<List<StockMovement>>> movements() => guardApi(() async {
        final list = await _client.getList('/api/stock/movements');
        return list
            .map(
              (j) => StockMovement(
                id: asString(j, 'id'),
                productId: asString(j, 'product_id'),
                warehouseId: asString(j, 'warehouse_id'),
                movementType: asString(j, 'movement_type'),
                subtype: asString(j, 'subtype'),
                quantity: asDouble(j, 'quantity'),
                referenceDocType: asString(j, 'reference_doc_type'),
                createdAt: asString(j, 'created_at'),
              ),
            )
            .toList();
      });
}
