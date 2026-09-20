import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/di.dart';
import '../data/bi_repository_impl.dart';
import '../domain/entities.dart';

final biRepositoryProvider = Provider(
  (ref) => BiRepositoryImpl(ref.watch(apiClientProvider)),
);

typedef ForecastParams = ({int lookbackWeeks, bool includeExcluded});

final forecastsProvider = FutureProvider.autoDispose.family<List<Forecast>, ForecastParams>(
  (ref, p) => ref
      .read(biRepositoryProvider)
      .forecasts(lookbackWeeks: p.lookbackWeeks, includeExcluded: p.includeExcluded)
      .then((r) => r.getOrThrow()),
);

final storagePlanProvider = FutureProvider.autoDispose.family<List<PlanLine>, PlanParams>(
  (ref, p) => ref.read(biRepositoryProvider).storagePlan(p).then((r) => r.getOrThrow()),
);

final financialsProvider = FutureProvider.autoDispose.family<List<FinancialLine>, int>(
  (ref, lookbackWeeks) =>
      ref.read(biRepositoryProvider).financials(lookbackWeeks).then((r) => r.getOrThrow()),
);

final budgetsProvider = FutureProvider.autoDispose<List<Budget>>(
  (ref) => ref.read(biRepositoryProvider).budgets().then((r) => r.getOrThrow()),
);

final budgetProvider = FutureProvider.autoDispose.family<Budget, String>(
  (ref, id) => ref.read(biRepositoryProvider).budget(id).then((r) => r.getOrThrow()),
);

final supplierPricesProvider = FutureProvider.autoDispose<List<SupplierPrice>>(
  (ref) => ref.read(biRepositoryProvider).supplierPrices().then((r) => r.getOrThrow()),
);

final schedulesProvider = FutureProvider.autoDispose<List<BudgetSchedule>>(
  (ref) => ref.read(biRepositoryProvider).schedules().then((r) => r.getOrThrow()),
);
