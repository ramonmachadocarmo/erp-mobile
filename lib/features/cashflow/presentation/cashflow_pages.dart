import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/di.dart';
import '../../../app/widgets/crud_list.dart';
import '../../../app/widgets/list_filters.dart';
import '../../../app/widgets/form_kit.dart';
import '../data/cashflow_repository_impl.dart';
import '../domain/entities.dart';

final cashflowRepositoryProvider = Provider(
  (ref) => CashflowRepositoryImpl(ref.watch(apiClientProvider)),
);

final cashEntriesProvider =
    AsyncNotifierProvider<CashEntriesNotifier, List<CashEntry>>(CashEntriesNotifier.new);

class CashEntriesNotifier extends AsyncNotifier<List<CashEntry>> {
  @override
  Future<List<CashEntry>> build() =>
      ref.read(cashflowRepositoryProvider).entries().then((r) => r.getOrThrow());

  Future<void> reload() async {
    state = await AsyncValue.guard(
      () => ref.read(cashflowRepositoryProvider).entries().then((r) => r.getOrThrow()),
    );
  }
}

final cashSummaryProvider =
    AsyncNotifierProvider<CashSummaryNotifier, List<CashSummary>>(CashSummaryNotifier.new);

class CashSummaryNotifier extends AsyncNotifier<List<CashSummary>> {
  @override
  Future<List<CashSummary>> build() =>
      ref.read(cashflowRepositoryProvider).summary().then((r) => r.getOrThrow());

  Future<void> reload() async {
    state = await AsyncValue.guard(
      () => ref.read(cashflowRepositoryProvider).summary().then((r) => r.getOrThrow()),
    );
  }
}

class CashSummaryPage extends ConsumerWidget {
  const CashSummaryPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = ref.watch(cashSummaryProvider);
    return CrudList<CashSummary>(
      value: items,
      onRefresh: () => ref.read(cashSummaryProvider.notifier).reload(),
      titleOf: (s) => s.date,
      subtitleOf: (s) =>
          'ent. ${brl(s.inflow)} · saí. ${brl(s.outflow)} · saldo ${brl(s.balance)}',
    );
  }
}

class CashEntriesPage extends ConsumerWidget {
  const CashEntriesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = ref.watch(cashEntriesProvider);
    return CrudList<CashEntry>(
      value: items,
      onRefresh: () => ref.read(cashEntriesProvider.notifier).reload(),
      titleOf: (e) => '${e.direction == 'IN' ? 'Entrada' : 'Saída'} · ${brl(e.amount)}',
      subtitleOf: (e) =>
          '${e.dueDate} · ${e.status == 'CONFIRMED' ? 'Confirmado' : 'Previsto'} · ${e.paymentMethodCode}',
      filters: [
        ListFilter<CashEntry>.byValue(
          label: 'Tipo',
          valueOf: (e) => e.direction,
          options: const [FilterOption('IN', 'Entrada'), FilterOption('OUT', 'Saída')],
        ),
        ListFilter<CashEntry>.custom(
          label: 'Situação',
          options: const [
            FilterOption('CONFIRMED', 'Confirmado'),
            FilterOption('FORECAST', 'Previsto'),
          ],
          test: (e, v) => (e.status == 'CONFIRMED') == (v == 'CONFIRMED'),
        ),
      ],
    );
  }
}

