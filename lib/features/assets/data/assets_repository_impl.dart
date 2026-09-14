import '../../../core/error/result.dart';
import '../../../core/json.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_guard.dart';
import '../domain/entities.dart';

abstract class AssetsRepository {
  Future<Result<List<FixedAsset>>> assets();
  Future<Result<FixedAsset>> save(FixedAsset asset);
  Future<Result<void>> transfer(String id, String location, String notes);
  Future<Result<void>> depreciate(String id);
  Future<Result<void>> dispose(String id, String notes);
  Future<Result<List<AssetMovement>>> movements();
  Future<Result<List<({String id, String sku, String name})>>> fixedProducts();
}

class AssetsRepositoryImpl implements AssetsRepository {
  const AssetsRepositoryImpl(this._client);

  final ApiClient _client;

  FixedAsset _asset(Map<String, dynamic> j) => FixedAsset(
        id: asString(j, 'id'),
        productId: asString(j, 'product_id'),
        tag: asString(j, 'tag'),
        serialNumber: asString(j, 'serial_number'),
        description: asString(j, 'description'),
        location: asString(j, 'location'),
        acquisitionDate: asString(j, 'acquisition_date'),
        acquisitionCost: asDouble(j, 'acquisition_cost'),
        residualValue: asDouble(j, 'residual_value'),
        usefulLifeMonths: asInt(j, 'useful_life_months'),
        netBookValue: asDouble(j, 'net_book_value'),
        status: asString(j, 'status'),
      );

  @override
  Future<Result<List<FixedAsset>>> assets() => guardApi(() async {
        final list = await _client.getList('/api/assets/assets');
        return list.map(_asset).toList();
      });

  @override
  Future<Result<FixedAsset>> save(FixedAsset a) => guardApi(() async {
        final date = a.acquisitionDate.length >= 10
            ? '${a.acquisitionDate.substring(0, 10)}T00:00:00Z'
            : a.acquisitionDate;
        final body = {
          'product_id': a.productId,
          'tag': a.tag,
          'serial_number': a.serialNumber,
          'description': a.description,
          'location': a.location,
          'acquisition_date': date,
          'acquisition_cost': a.acquisitionCost,
          'residual_value': a.residualValue,
          'useful_life_months': a.usefulLifeMonths,
          'depreciation_method': 'STRAIGHT_LINE',
        };
        final json = a.id.isEmpty
            ? await _client.post('/api/assets/assets', body: body)
            : await _client.put('/api/assets/assets/${a.id}', body: body);
        return _asset(json);
      });

  @override
  Future<Result<void>> transfer(String id, String location, String notes) =>
      guardApi(
        () => _client.post('/api/assets/assets/$id/transfer', body: {'location': location, 'notes': notes}),
      );

  @override
  Future<Result<void>> depreciate(String id) =>
      guardApi(() => _client.post('/api/assets/assets/$id/depreciate', body: {}));

  @override
  Future<Result<void>> dispose(String id, String notes) =>
      guardApi(() => _client.post('/api/assets/assets/$id/dispose', body: {'notes': notes}));

  @override
  Future<Result<List<AssetMovement>>> movements() => guardApi(() async {
        final list = await _client.getList('/api/assets/movements');
        return list
            .map(
              (j) => AssetMovement(
                id: asString(j, 'id'),
                assetId: asString(j, 'asset_id'),
                movementType: asString(j, 'movement_type'),
                toLocation: asString(j, 'to_location'),
                amount: asDouble(j, 'amount'),
                occurredAt: asString(j, 'occurred_at'),
                notes: asString(j, 'notes'),
              ),
            )
            .toList();
      });

  @override
  Future<Result<List<({String id, String sku, String name})>>> fixedProducts() => guardApi(() async {
        final list = await _client.getList('/api/stock/products');
        return list
            .where((p) => asString(p, 'kind') == 'FIXED_ASSET')
            .map(
              (p) => (
                id: asString(p, 'id'),
                sku: asString(p, 'sku'),
                name: asString(p, 'name'),
              ),
            )
            .toList();
      });
}
