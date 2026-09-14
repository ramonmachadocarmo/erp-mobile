import '../../../core/error/result.dart';
import '../../../core/json.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/network/api_guard.dart';
import '../../config/data/mappers.dart';
import '../../config/domain/entities.dart';
import '../domain/entities.dart';
import '../domain/purchasing_repository.dart';

class PurchasingRepositoryImpl implements PurchasingRepository {
  const PurchasingRepositoryImpl(this._client);

  final ApiClient _client;

  List<PurchaseLine> _lines(dynamic raw) => asMapList(raw)
      .map(
        (i) => PurchaseLine(
          productId: asString(i, 'product_id'),
          quantity: asDouble(i, 'quantity'),
          unitPrice: asDouble(i, 'unit_price'),
        ),
      )
      .toList();

  @override
  Future<Result<List<Quote>>> quotes() => guardApi(() async {
        final list = await _client.getList('/api/purchasing/quotes');
        return list.map(Quote.fromJson).toList();
      });

  @override
  Future<Result<void>> createQuote(Quote quote) => guardApi(() async {
        await _client.post('/api/purchasing/quotes', body: quote.toJson());
      });

  @override
  Future<Result<void>> convertQuote(
    String id, {
    required String methodId,
    required String termId,
  }) =>
      guardApi(
        () => _client.post(
          '/api/purchasing/quotes/$id/convert',
          body: {'payment_method_id': methodId, 'payment_term_id': termId},
        ),
      );

  @override
  Future<Result<List<PurchaseOrder>>> orders() => guardApi(() async {
        final list = await _client.getList('/api/purchasing/purchase-orders');
        return list
            .map(
              (j) => PurchaseOrder(
                id: asString(j, 'id'),
                supplierId: asString(j, 'supplier_id'),
                status: asString(j, 'status'),
                totalAmount: asDouble(j, 'total_amount'),
                quoteId: asString(j, 'quote_id'),
                paymentMethodId: asString(j, 'payment_method_id'),
                paymentTermId: asString(j, 'payment_term_id'),
                items: _lines(j['items']),
              ),
            )
            .toList();
      });

  @override
  Future<Result<void>> createOrder(PurchaseOrder order) => guardApi(() async {
        await _client.post(
          '/api/purchasing/purchase-orders',
          body: {
            'supplier_id': order.supplierId,
            'payment_method_id': order.paymentMethodId,
            'payment_term_id': order.paymentTermId,
            'items': order.items.map((i) => i.toJson()).toList(),
          },
        );
      });

  @override
  Future<Result<void>> receive(String id, {String warehouseId = ''}) =>
      guardApi(
        () => _client.post(
          '/api/purchasing/purchase-orders/$id/receive',
          body: {'warehouse_id': warehouseId},
        ),
      );

  @override
  Future<Result<void>> confer(String id) =>
      guardApi(() => _client.post('/api/purchasing/purchase-orders/$id/confer'));

  @override
  Future<Result<void>> cancel(String id) =>
      guardApi(() => _client.post('/api/purchasing/purchase-orders/$id/cancel'));

  @override
  Future<Result<List<Person>>> suppliers() => guardApi(() async {
        final list = await _client.getList('/api/config/suppliers');
        return list.map(personFrom).toList();
      });

  @override
  Future<Result<Person>> saveSupplier(Person person) => guardApi(() async {
        final body = personBody(person);
        final json = person.id.isEmpty
            ? await _client.post('/api/config/suppliers', body: body)
            : await _client.put('/api/config/suppliers/${person.id}', body: body);
        return personFrom(json);
      });

  @override
  Future<Result<List<PurchasePrice>>> history() => guardApi(() async {
        final list = await _client.getList('/api/stock/prices/purchase');
        return list
            .map(
              (j) => PurchasePrice(
                id: asString(j, 'id'),
                sku: asString(j, 'sku'),
                previousPrice: asDouble(j, 'previous_price'),
                newPrice: asDouble(j, 'new_price'),
                createdAt: asString(j, 'created_at'),
              ),
            )
            .toList();
      });

  Future<List<Map<String, dynamic>>> _listOrEmpty(String path) async {
    try {
      return await _client.getList(path);
    } on ApiException {
      return [];
    }
  }

  @override
  Future<Result<PurchaseLookups>> lookups() => guardApi(() async {
        final suppliers = await _listOrEmpty('/api/config/suppliers');
        final products = await _listOrEmpty('/api/stock/products');
        final methods = await _listOrEmpty('/api/config/payment-methods');
        final terms = await _listOrEmpty('/api/config/payment-terms');
        return PurchaseLookups(
          suppliers: suppliers.map(personFrom).toList(),
          products: products
              .map(
                (p) => (
                  id: asString(p, 'id'),
                  sku: asString(p, 'sku'),
                  name: asString(p, 'name'),
                  purchasePrice: asDouble(p, 'purchase_price'),
                ),
              )
              .toList(),
          methods: methods.map(methodFrom).toList(),
          terms: terms.map(termFrom).toList(),
        );
      });
}
