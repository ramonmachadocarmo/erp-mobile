import '../../../core/error/result.dart';
import '../../../core/json.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_guard.dart';
import '../domain/config_repository.dart';
import '../domain/entities.dart';
import 'mappers.dart';

class ConfigRepositoryImpl implements ConfigRepository {
  const ConfigRepositoryImpl(this._client);

  final ApiClient _client;

  @override
  Future<Result<Address>> lookupCep(String cep) => guardApi(() async {
    final digits = cep.replaceAll(RegExp(r'\D'), '');
    final j = await _client.get('/api/config/cep/$digits');
    return _addressFromCep(j);
  });

  @override
  Future<Result<List<Address>>> searchCep({
    required String state,
    required String city,
    required String street,
    String district = '',
  }) => guardApi(() async {
    final query = Uri(
      queryParameters: {
        'state': state.trim(),
        'city': city.trim(),
        'street': street.trim(),
        if (district.trim().isNotEmpty) 'district': district.trim(),
      },
    ).query;
    final list = await _client.getList('/api/config/cep?$query');
    return list.map(_addressFromCep).toList();
  });

  Address _addressFromCep(Map<String, dynamic> j) => Address(
    zip: asString(j, 'zip'),
    street: asString(j, 'street'),
    complement: asString(j, 'complement'),
    district: asString(j, 'district'),
    city: asString(j, 'city'),
    state: asString(j, 'state'),
  );

  @override
  Future<Result<List<Unit>>> units() => guardApi(() async {
        final list = await _client.getList('/api/config/units');
        return list.map(unitFrom).toList();
      });

  @override
  Future<Result<Unit>> saveUnit(Unit unit) => guardApi(() async {
        final body = {'code': unit.code, 'name': unit.name, 'symbol': unit.symbol};
        final json = unit.id.isEmpty
            ? await _client.post('/api/config/units', body: body)
            : await _client.put('/api/config/units/${unit.id}', body: body);
        return unitFrom(json);
      });

  @override
  Future<Result<List<PaymentMethod>>> methods() => guardApi(() async {
        final list = await _client.getList('/api/config/payment-methods');
        return list.map(methodFrom).toList();
      });

  @override
  Future<Result<PaymentMethod>> saveMethod(PaymentMethod method) => guardApi(() async {
        final body = {'code': method.code, 'name': method.name, 'active': true};
        final json = method.id.isEmpty
            ? await _client.post('/api/config/payment-methods', body: body)
            : await _client.put('/api/config/payment-methods/${method.id}', body: body);
        return methodFrom(json);
      });

  @override
  Future<Result<List<PaymentTerm>>> terms() => guardApi(() async {
        final list = await _client.getList('/api/config/payment-terms');
        return list.map(termFrom).toList();
      });

  @override
  Future<Result<PaymentTerm>> saveTerm(PaymentTerm term) => guardApi(() async {
        final body = {
          'code': term.code,
          'name': term.name,
          'installments': term.installments.map((i) => i.toJson()).toList(),
          'active': true,
        };
        final json = term.id.isEmpty
            ? await _client.post('/api/config/payment-terms', body: body)
            : await _client.put('/api/config/payment-terms/${term.id}', body: body);
        return termFrom(json);
      });

  @override
  Future<Result<bool>> quoteRequired() => guardApi(() async {
        final json = await _client.get('/api/config/settings/purchase_quote_required');
        return json['value']?.toString() == 'true';
      });

  @override
  Future<Result<void>> setQuoteRequired(bool value) => guardApi(() async {
        await _client.put(
          '/api/config/settings/purchase_quote_required',
          body: {'value': value ? 'true' : 'false'},
        );
      });

  @override
  Future<Result<String>> defaultWarehouse() => guardApi(() async {
        final json = await _client.get('/api/config/settings/default_warehouse_id');
        return json['value']?.toString() ?? '';
      });

  @override
  Future<Result<void>> setDefaultWarehouse(String id) => guardApi(() async {
        await _client.put(
          '/api/config/settings/default_warehouse_id',
          body: {'value': id},
        );
      });

  @override
  Future<Result<List<DistCenter>>> centers() => guardApi(() async {
        final list = await _client.getList('/api/config/centers');
        return list.map(centerFrom).toList();
      });

  @override
  Future<Result<List<Vehicle>>> vehicles() => guardApi(() async {
        final list = await _client.getList('/api/config/vehicles');
        return list.map(vehicleFrom).where((v) => v.active).toList();
      });
}
