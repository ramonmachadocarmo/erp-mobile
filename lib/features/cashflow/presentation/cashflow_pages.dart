import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/di.dart';
import '../../../app/widgets/crud_list.dart';
import '../../../app/widgets/list_filters.dart';
import '../../../app/widgets/form_kit.dart';
import '../../config/domain/entities.dart';
import '../../config/presentation/config_providers.dart';
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

  Future<void> createManual(ManualEntry entry) async {
    (await ref.read(cashflowRepositoryProvider).createManual(entry)).getOrThrow();
    await reload();
  }

  Future<void> delete(String id) async {
    (await ref.read(cashflowRepositoryProvider).deleteEntry(id)).getOrThrow();
    await reload();
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
          '${e.dueDate} · ${e.status == 'CONFIRMED' ? 'Confirmado' : 'Previsto'} · ${e.paymentMethodCode}'
          '${e.description.isEmpty ? '' : ' · ${e.description}'}',
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
      // Só lançamento avulso (reference_type MANUAL) é excluído por aqui — o que vem de
      // pedido de venda/compra (SALE/PURCHASE) é derivado e some junto com o pedido.
      onCreate: () => pushForm(context, const _ManualEntryForm()),
      onDelete: (e) => ref.read(cashEntriesProvider.notifier).delete(e.id),
      canDelete: (e) => e.referenceType == 'MANUAL',
    );
  }
}

class _ManualEntryForm extends ConsumerStatefulWidget {
  const _ManualEntryForm();

  @override
  ConsumerState<_ManualEntryForm> createState() => _ManualEntryFormState();
}

class _ManualEntryFormState extends ConsumerState<_ManualEntryForm> {
  final _form = GlobalKey<FormState>();
  var _direction = 'OUT';
  var _dueDate = '';
  var _methodId = '';
  final _amount = TextEditingController();
  final _description = TextEditingController();
  var _saving = false;

  @override
  void dispose() {
    _amount.dispose();
    _description.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final methods = ref.watch(methodsProvider).valueOrNull ?? const <PaymentMethod>[];
    return Form(
      key: _form,
      child: FormScaffold(
        title: 'Novo lançamento',
        saving: _saving,
        onSave: _save,
        child: Column(
          children: [
            const Padding(
              padding: EdgeInsets.only(bottom: 12),
              child: Text(
                'Registre um lançamento avulso de caixa — não vinculado a nenhum pedido de venda ou compra.',
              ),
            ),
            ErpDropdown<String>(
              label: 'Tipo',
              value: _direction,
              items: const [
                DropdownMenuItem(value: 'IN', child: Text('Entrada')),
                DropdownMenuItem(value: 'OUT', child: Text('Saída')),
              ],
              onChanged: (v) => setState(() => _direction = v ?? 'OUT'),
            ),
            ErpDateField(
              label: 'Vencimento',
              value: _dueDate,
              required: true,
              onChanged: (v) => setState(() => _dueDate = v),
            ),
            ErpField('Valor', _amount, required: true, keyboard: const TextInputType.numberWithOptions(decimal: true)),
            ErpDropdown<String>(
              label: 'Forma de pagamento',
              value: _methodId.isEmpty ? null : _methodId,
              items: methods.map((m) => DropdownMenuItem(value: m.id, child: Text(m.name))).toList(),
              onChanged: (v) => setState(() => _methodId = v ?? ''),
            ),
            ErpField('Descrição', _description, required: true),
          ],
        ),
      ),
    );
  }

  Future<void> _save() async {
    if (!(_form.currentState?.validate() ?? false)) return;
    setState(() => _saving = true);
    try {
      await ref.read(cashEntriesProvider.notifier).createManual(
            ManualEntry(
              direction: _direction,
              dueDate: _dueDate,
              amount: parseNum(_amount.text),
              description: _description.text.trim(),
              paymentMethodId: _methodId,
            ),
          );
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) showError(context, '$e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}

