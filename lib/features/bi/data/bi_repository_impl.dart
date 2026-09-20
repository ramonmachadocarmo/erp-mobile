import '../../../core/error/result.dart';
import '../../../core/json.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_guard.dart';
import '../domain/entities.dart';

class BiRepositoryImpl {
  const BiRepositoryImpl(this._client);

  final ApiClient _client;

  static const _base = '/api/bi';

  String _planQuery(PlanParams p) =>
      'coverage_weeks=${p.coverageWeeks}&safety_percent=${p.safetyPercent}&lookback_weeks=${p.lookbackWeeks}';

  Future<Result<List<Forecast>>> forecasts({required int lookbackWeeks, bool includeExcluded = false}) =>
      guardApi(() async {
        final q = 'lookback_weeks=$lookbackWeeks${includeExcluded ? '&include_excluded=true' : ''}';
        final list = await _client.getList('$_base/forecasts?$q');
        return list.map((j) {
          final override = j['override_weekly_qty'];
          return Forecast(
            kind: asString(j, 'kind'),
            targetId: asString(j, 'target_id'),
            code: asString(j, 'code'),
            name: asString(j, 'name'),
            computedWeeklyQty: asDouble(j, 'computed_weekly_qty'),
            overrideWeeklyQty: override == null ? null : asDouble(j, 'override_weekly_qty'),
            effectiveWeeklyQty: asDouble(j, 'effective_weekly_qty'),
            excluded: asBool(j, 'excluded'),
          );
        }).toList();
      });

  Future<Result<void>> setForecastOverride(String kind, String targetId, double weeklyQty) =>
      guardApi(() => _client.put('$_base/forecasts/$kind/$targetId', body: {'weekly_qty': weeklyQty}));

  Future<Result<void>> clearForecastOverride(String kind, String targetId) =>
      guardApi(() => _client.delete('$_base/forecasts/$kind/$targetId'));

  Future<Result<void>> excludeForecast(String kind, String targetId) =>
      guardApi(() => _client.post('$_base/forecasts/$kind/$targetId/exclude'));

  Future<Result<void>> includeForecast(String kind, String targetId) =>
      guardApi(() => _client.delete('$_base/forecasts/$kind/$targetId/exclude'));

  Future<Result<List<PlanLine>>> storagePlan(PlanParams p) => guardApi(() async {
        final list = await _client.getList('$_base/storage-plan?${_planQuery(p)}');
        return list
            .map(
              (j) => PlanLine(
                productId: asString(j, 'product_id'),
                sku: asString(j, 'sku'),
                name: asString(j, 'name'),
                forecastQty: asDouble(j, 'forecast_qty'),
                onHandQty: asDouble(j, 'on_hand_qty'),
                openPoQty: asDouble(j, 'open_po_qty'),
                neededQty: asDouble(j, 'needed_qty'),
              ),
            )
            .toList();
      });

  Future<Result<List<FinancialLine>>> financials(int lookbackWeeks) => guardApi(() async {
        final list = await _client.getList('$_base/financials?lookback_weeks=$lookbackWeeks');
        return list
            .map(
              (j) => FinancialLine(
                kind: asString(j, 'kind'),
                targetId: asString(j, 'target_id'),
                code: asString(j, 'code'),
                name: asString(j, 'name'),
                weeklyQty: asDouble(j, 'weekly_qty'),
                unitRevenue: asDouble(j, 'unit_revenue'),
                unitCost: asDouble(j, 'unit_cost'),
                weeklyRevenue: asDouble(j, 'weekly_revenue'),
                weeklyCost: asDouble(j, 'weekly_cost'),
                weeklyProfit: asDouble(j, 'weekly_profit'),
                marginPercent: asDouble(j, 'margin_percent'),
              ),
            )
            .toList();
      });

  Budget _budget(Map<String, dynamic> j) => Budget(
        id: asString(j, 'id'),
        code: asString(j, 'code'),
        status: asString(j, 'status'),
        coverageWeeks: asInt(j, 'coverage_weeks'),
        safetyPercent: asDouble(j, 'safety_percent'),
        lookbackWeeks: asInt(j, 'lookback_weeks'),
        createdAt: asString(j, 'created_at'),
        items: [
          for (final i in asMapList(j['items']))
            BudgetItem(
              id: asString(i, 'id'),
              productId: asString(i, 'product_id'),
              neededQty: asDouble(i, 'needed_qty'),
              allocations: [
                for (final a in asMapList(i['allocations']))
                  BudgetAllocation(
                    id: asString(a, 'id'),
                    supplierId: asString(a, 'supplier_id'),
                    quantity: asDouble(a, 'quantity'),
                    unitPrice: asDouble(a, 'unit_price'),
                    hasQuote: asString(a, 'quote_id').isNotEmpty,
                  ),
              ],
            ),
        ],
      );

  Future<Result<List<Budget>>> budgets() =>
      guardApi(() async => (await _client.getList('$_base/budgets')).map(_budget).toList());

  Future<Result<Budget>> budget(String id) => guardApi(() async => _budget(await _client.get('$_base/budgets/$id')));

  Future<Result<Budget>> createBudget(PlanParams p) => guardApi(
        () async => _budget(
          await _client.post(
            '$_base/budgets',
            body: {
              'coverage_weeks': p.coverageWeeks,
              'safety_percent': p.safetyPercent,
              'lookback_weeks': p.lookbackWeeks,
            },
          ),
        ),
      );

  Future<Result<void>> deleteBudget(String id) => guardApi(() => _client.delete('$_base/budgets/$id'));

  Future<Result<void>> confirmBudget(String id) => guardApi(() => _client.post('$_base/budgets/$id/confirm'));

  Future<Result<void>> cancelBudget(String id) => guardApi(() => _client.post('$_base/budgets/$id/cancel'));

  Future<Result<void>> updateItemNeeded(String budgetId, String itemId, double qty) =>
      guardApi(() => _client.put('$_base/budgets/$budgetId/items/$itemId', body: {'needed_qty': qty}));

  Future<Result<void>> deleteItem(String budgetId, String itemId) =>
      guardApi(() => _client.delete('$_base/budgets/$budgetId/items/$itemId'));

  Future<Result<void>> addAllocation(
    String budgetId,
    String itemId, {
    required String supplierId,
    required double quantity,
    required double unitPrice,
  }) =>
      guardApi(
        () => _client.post(
          '$_base/budgets/$budgetId/items/$itemId/allocations',
          body: {'supplier_id': supplierId, 'quantity': quantity, 'unit_price': unitPrice},
        ),
      );

  Future<Result<void>> deleteAllocation(String budgetId, String allocationId) =>
      guardApi(() => _client.delete('$_base/budgets/$budgetId/allocations/$allocationId'));

  Future<Result<List<SupplierPrice>>> supplierPrices() => guardApi(() async {
        final list = await _client.getList('$_base/supplier-prices');
        return list
            .map(
              (j) => SupplierPrice(
                id: asString(j, 'id'),
                productId: asString(j, 'product_id'),
                supplierId: asString(j, 'supplier_id'),
                price: asDouble(j, 'price'),
                minQty: asDouble(j, 'min_qty'),
                updatedAt: asString(j, 'updated_at'),
              ),
            )
            .toList();
      });

  Future<Result<void>> setSupplierPrice({
    required String productId,
    required String supplierId,
    required double price,
    required double minQty,
  }) =>
      guardApi(
        () => _client.post(
          '$_base/supplier-prices',
          body: {'product_id': productId, 'supplier_id': supplierId, 'price': price, 'min_qty': minQty},
        ),
      );

  Future<Result<void>> deleteSupplierPrice(String id) => guardApi(() => _client.delete('$_base/supplier-prices/$id'));

  Future<Result<List<BudgetSchedule>>> schedules() => guardApi(() async {
        final list = await _client.getList('$_base/schedules');
        return list
            .map(
              (j) => BudgetSchedule(
                id: asString(j, 'id'),
                name: asString(j, 'name'),
                frequency: asString(j, 'frequency'),
                dayOfWeek: asInt(j, 'day_of_week'),
                dayOfMonth: asInt(j, 'day_of_month'),
                coverageWeeks: asInt(j, 'coverage_weeks'),
                safetyPercent: asDouble(j, 'safety_percent'),
                lookbackWeeks: asInt(j, 'lookback_weeks'),
                active: asBool(j, 'active'),
                nextRunAt: asString(j, 'next_run_at'),
                lastRunAt: asString(j, 'last_run_at'),
              ),
            )
            .toList();
      });

  Map<String, dynamic> _scheduleBody(BudgetSchedule s) => {
        'name': s.name,
        'frequency': s.frequency,
        'coverage_weeks': s.coverageWeeks,
        'safety_percent': s.safetyPercent,
        'lookback_weeks': s.lookbackWeeks,
        'active': s.active,
        if (s.weekly) 'day_of_week': s.dayOfWeek else 'day_of_month': s.dayOfMonth,
      };

  Future<Result<void>> saveSchedule(BudgetSchedule s) => guardApi(
        () => s.id.isEmpty
            ? _client.post('$_base/schedules', body: _scheduleBody(s))
            : _client.put('$_base/schedules/${s.id}', body: _scheduleBody(s)),
      );

  Future<Result<void>> deleteSchedule(String id) => guardApi(() => _client.delete('$_base/schedules/$id'));

  Future<Result<void>> runScheduleNow(String id) => guardApi(() => _client.post('$_base/schedules/$id/run-now'));
}
