import '../../../core/error/result.dart';
import '../../../core/json.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_guard.dart';
import '../../config/data/mappers.dart';
import '../../config/domain/entities.dart';
import '../domain/entities.dart';
import '../domain/sales_repository.dart';
import 'mappers.dart';

class SalesRepositoryImpl implements SalesRepository {
  const SalesRepositoryImpl(this._client);

  final ApiClient _client;

  @override
  Future<Result<List<SalesOrder>>> orders() => guardApi(() async {
    final list = await _client.getList('/api/sales/sales-orders');
    return list.map(orderFrom).toList();
  });

  @override
  Future<Result<SalesOrder>> getOrder(String id) => guardApi(() async {
    final json = await _client.get('/api/sales/sales-orders/$id');
    return orderFrom(json);
  });

  @override
  Future<Result<void>> createOrder(SalesOrder order) => guardApi(() async {
    await _client.post(
      '/api/sales/sales-orders',
      body: {
        'customer_id': order.customerId,
        'warehouse_id': order.warehouseId,
        'payment_method_id': order.paymentMethodId,
        'payment_term_id': order.paymentTermId,
        'discount_amount': 0,
        if (order.paymentStatus.isNotEmpty)
          'payment_status': order.paymentStatus,
        'delivery_date': order.deliveryDate,
        'address': order.address.toJson(),
        'items': order.items.map((i) => i.toJson()).toList(),
      },
    );
  });

  @override
  Future<Result<void>> cancelOrder(String id) =>
      guardApi(() => _client.post('/api/sales/sales-orders/$id/cancel'));

  @override
  Future<Result<void>> deleteOrder(String id) =>
      guardApi(() => _client.delete('/api/sales/sales-orders/$id'));

  @override
  Future<Result<SalesOrder>> scanPick(
    String id, {
    required String productId,
    required String warehouseId,
    double quantity = 1,
  }) => guardApi(() async {
    final json = await _client.post(
      '/api/sales/sales-orders/$id/picking/scan',
      body: {
        'product_id': productId,
        'warehouse_id': warehouseId,
        'quantity': quantity,
      },
    );
    return orderFrom(json);
  });

  @override
  Future<Result<SalesOrder>> completePicking(
    String id, {
    required int volumeCount,
  }) => guardApi(() async {
    final json = await _client.post(
      '/api/sales/sales-orders/$id/picking/complete',
      body: {'volume_count': volumeCount},
    );
    return orderFrom(json);
  });

  @override
  Future<Result<void>> undoPicking(String id) =>
      guardApi(() => _client.post('/api/sales/sales-orders/$id/picking/undo'));

  @override
  Future<Result<List<Person>>> customers() => guardApi(() async {
    final list = await _client.getList('/api/config/customers');
    return list.map(personFrom).toList();
  });

  @override
  Future<Result<Person>> saveCustomer(Person person) => guardApi(() async {
    final body = personBody(person);
    final json = person.id.isEmpty
        ? await _client.post('/api/config/customers', body: body)
        : await _client.put('/api/config/customers/${person.id}', body: body);
    return personFrom(json);
  });

  @override
  Future<Result<SalesLookups>> lookups() => guardApi(() async {
    final customers = await _client.getList('/api/config/customers');
    final products = await _client.getList('/api/stock/products');
    final prices = await _client.getList('/api/stock/prices/sale');
    final warehouses = await _client.getList('/api/stock/warehouses');
    final methods = await _client.getList('/api/config/payment-methods');
    final terms = await _client.getList('/api/config/payment-terms');
    final latestSale = <String, double>{};
    for (final h in prices) {
      final id = asString(h, 'product_id');
      latestSale.putIfAbsent(id, () => asDouble(h, 'new_price'));
    }
    return SalesLookups(
      customers: customers.map(personFrom).toList(),
      products: products.map((p) {
        final id = asString(p, 'id');
        return (
          id: id,
          sku: asString(p, 'sku'),
          name: asString(p, 'name'),
          popularName: asString(p, 'popular_name'),
          barcode: asString(p, 'barcode'),
          saleUom: asString(p, 'sale_uom'),
          salePrice: latestSale[id] ?? asDouble(p, 'sale_price'),
        );
      }).toList(),
      warehouses: warehouses
          .map(
            (w) => (
              id: asString(w, 'id'),
              code: asString(w, 'code'),
              name: asString(w, 'name'),
            ),
          )
          .toList(),
      methods: methods.map(methodFrom).toList(),
      terms: terms.map(termFrom).toList(),
    );
  });
}
