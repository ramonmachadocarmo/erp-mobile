import '../../../core/error/result.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_guard.dart';

/// reports-service aggregates on demand and returns heterogeneous rows per report, so rows are
/// kept as JSON maps and formatted by each report page rather than mapped to entities.
typedef ReportRows = List<Map<String, dynamic>>;

class ReportsRepositoryImpl {
  const ReportsRepositoryImpl(this._client);

  final ApiClient _client;

  static const _base = '/api/reports';

  Future<Result<ReportRows>> kits() => guardApi(() => _client.getList('$_base/kits'));

  Future<Result<ReportRows>> stock() => guardApi(() => _client.getList('$_base/stock'));

  Future<Result<ReportRows>> sales({String? from, String? to}) =>
      guardApi(() => _client.getList('$_base/sales${_range(from, to)}'));

  Future<Result<ReportRows>> purchases({String? from, String? to}) =>
      guardApi(() => _client.getList('$_base/purchases${_range(from, to)}'));

  Future<Result<ReportRows>> forecast({
    required int coverageWeeks,
    required double safetyPercent,
    required int lookbackWeeks,
  }) =>
      guardApi(
        () => _client.getList(
          '$_base/forecast?coverage_weeks=$coverageWeeks&safety_percent=$safetyPercent&lookback_weeks=$lookbackWeeks',
        ),
      );

  // Dates arrive as YYYY-MM-DD and are widened to the whole day, like the web report does.
  String _range(String? from, String? to) {
    final q = [
      if (from != null && from.isNotEmpty) 'from=${Uri.encodeQueryComponent('${from}T00:00:00.000Z')}',
      if (to != null && to.isNotEmpty) 'to=${Uri.encodeQueryComponent('${to}T23:59:59.999Z')}',
    ];
    return q.isEmpty ? '' : '?${q.join('&')}';
  }
}
