import '../../../core/error/result.dart';
import '../../../core/json.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_guard.dart';
import '../domain/entities.dart';

abstract class CashflowRepository {
  Future<Result<List<CashEntry>>> entries();
  Future<Result<List<CashSummary>>> summary();
}

class CashflowRepositoryImpl implements CashflowRepository {
  const CashflowRepositoryImpl(this._client);

  final ApiClient _client;

  @override
  Future<Result<List<CashEntry>>> entries() => guardApi(() async {
        final list = await _client.getList('/api/cashflow/entries');
        return list
            .map(
              (j) => CashEntry(
                id: asString(j, 'id'),
                dueDate: asString(j, 'due_date'),
                amount: asDouble(j, 'amount'),
                direction: asString(j, 'direction'),
                status: asString(j, 'status'),
                paymentMethodCode: asString(j, 'payment_method_code'),
                referenceType: asString(j, 'reference_type'),
              ),
            )
            .toList();
      });

  @override
  Future<Result<List<CashSummary>>> summary() => guardApi(() async {
        final list = await _client.getList('/api/cashflow/summary');
        return list
            .map(
              (j) => CashSummary(
                date: asString(j, 'date'),
                inflow: asDouble(j, 'inflow'),
                outflow: asDouble(j, 'outflow'),
                net: asDouble(j, 'net'),
                balance: asDouble(j, 'balance'),
              ),
            )
            .toList();
      });
}
