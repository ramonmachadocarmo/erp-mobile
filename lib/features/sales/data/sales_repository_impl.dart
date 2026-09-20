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
        'address': order.address.toJson(),
        'items': order.items.map((i) => i.toJson()).toList(),
      },
    );
  });

  @override
  Future<Result<void>> cancelOrder(String id) =>
      guardApi(() => _client.post('/api/sales/sales-orders/$id/cancel'));

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
  Future<Result<void>> deliver(String id) =>
      guardApi(() => _client.post('/api/sales/sales-orders/$id/deliver'));

  @override
  Future<Result<void>> failDelivery(String id, String note) => guardApi(
    () =>
        _client.post('/api/sales/sales-orders/$id/fail', body: {'note': note}),
  );

  @override
  Future<Result<void>> undoDeliver(String id) =>
      guardApi(() => _client.post('/api/sales/sales-orders/$id/undeliver'));

  @override
  Future<Result<List<DeliveryPlan>>> deliveryPlans() => guardApi(() async {
    final list = await _client.getList('/api/sales/delivery-plans');
    return list.map(planFrom).toList();
  });

  @override
  Future<Result<DeliveryPlan>> getDeliveryPlan(String id) => guardApi(() async {
    return planFrom(await _client.get('/api/sales/delivery-plans/$id'));
  });

  @override
  Future<Result<List<DeliveryCandidate>>> deliveryCandidates() =>
      guardApi(() async {
        final list = await _client.getList('/api/sales/delivery-candidates');
        return list.map(candidateFrom).toList();
      });

  @override
  Future<Result<PlanResult>> createDeliveryPlans({
    required String centerId,
    required List<String> vehicleIds,
    required List<String> orderIds,
  }) => guardApi(() async {
    final j = await _client.post(
      '/api/sales/delivery-plans',
      body: {
        'center_id': centerId,
        'vehicle_ids': vehicleIds,
        'order_ids': orderIds,
      },
    );
    return planResultFrom(j);
  });

  @override
  Future<Result<DeliveryPlan>> confirmDeliveryPlan(
    String id, {
    RouteOption? option,
  }) => guardApi(() async {
    final body = option == null
        ? <String, dynamic>{}
        : {
            'distance_m': option.distanceM,
            'duration_s': option.durationS,
            'stops': [
              for (final s in option.stops)
                {
                  'seq': s.seq,
                  'sales_order_id': s.salesOrderId,
                  'distance_m': s.distanceM,
                  'duration_s': s.durationS,
                  'lat': s.lat,
                  'lng': s.lng,
                },
            ],
          };
    return planFrom(
      await _client.post('/api/sales/delivery-plans/$id/confirm', body: body),
    );
  });

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
          barcode: asString(p, 'barcode'),
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
