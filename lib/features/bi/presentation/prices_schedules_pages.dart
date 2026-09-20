import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme.dart';
import '../../../app/widgets/crud_list.dart';
import '../../../app/widgets/form_kit.dart';
import '../../config/domain/entities.dart';
import '../../purchasing/presentation/purchasing_providers.dart';
import '../../stock/presentation/stock_providers.dart';
import '../domain/entities.dart';
import 'bi_providers.dart';
import 'bi_widgets.dart';

// ------------------------------------------------ Preços de fornecedores

class SupplierPricesPage extends ConsumerWidget {
  const SupplierPricesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final products = productsById(ref);
    final suppliers = <String, String>{
      for (final s in ref.watch(suppliersProvider).valueOrNull ?? const <Person>[]) s.id: s.displayName,
    };
    final value = ref.watch(supplierPricesProvider);
    final all = value.valueOrNull ?? const <SupplierPrice>[];
    final best = <String, double>{};
    for (final sp in all) {
      final c = supplierUnitCost(products[sp.productId], sp);
      if (c != null && (best[sp.productId] == null || c < best[sp.productId]!)) best[sp.productId] = c;
    }

    return CrudList<SupplierPrice>(
      value: value.whenData((l) => [...l]..sort((a, b) => productLabel(products, a.productId).compareTo(productLabel(products, b.productId)))),
      onRefresh: () async => ref.invalidate(supplierPricesProvider),
      isThreeLine: true,
      titleOf: (sp) => productLabel(products, sp.productId),
      subtitleOf: (sp) {
        final p = products[sp.productId];
        final cost = supplierUnitCost(p, sp);
        final isBest = cost != null && best[sp.productId] == cost;
        return '${suppliers[sp.supplierId] ?? sp.supplierId}\n'
            '${brl(sp.price)} por ${fmtQty(sp.minQty)} ${p?.purchaseUom ?? ''}'
            '${cost == null ? ' · sem conversão' : ' · ${brl(cost)}/${p?.stockUom ?? ''}'}'
            '${isBest ? ' · melhor preço' : ''}';
      },
      onCreate: () => pushForm(context, const _SupplierPriceForm()),
      onDelete: (sp) async {
        if (await runAction(context, ref.read(biRepositoryProvider).deleteSupplierPrice(sp.id))) {
          ref.invalidate(supplierPricesProvider);
        }
      },
    );
  }
}

class _SupplierPriceForm extends ConsumerStatefulWidget {
  const _SupplierPriceForm();

  @override
  ConsumerState<_SupplierPriceForm> createState() => _SupplierPriceFormState();
}

class _SupplierPriceFormState extends ConsumerState<_SupplierPriceForm> {
  final _form = GlobalKey<FormState>();
  final _minQty = TextEditingController(text: '1');
  final _price = TextEditingController();
  String? _productId;
  String? _supplierId;
  bool _saving = false;

  @override
  void dispose() {
    _minQty.dispose();
    _price.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    if (_productId == null || _supplierId == null) {
      showError(context, 'Selecione o produto e o fornecedor.');
      return;
    }
    setState(() => _saving = true);
    final ok = await runAction(
      context,
      ref.read(biRepositoryProvider).setSupplierPrice(
            productId: _productId!,
            supplierId: _supplierId!,
            price: parseNum(_price.text),
            minQty: parseNum(_minQty.text, 1),
          ),
    );
    if (!mounted) return;
    setState(() => _saving = false);
    if (ok) {
      ref.invalidate(supplierPricesProvider);
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final products = (ref.watch(productsProvider).valueOrNull ?? []).where((p) => p.kind != 'FIXED_ASSET').toList();
    final suppliers = ref.watch(suppliersProvider).valueOrNull ?? [];
    final uom = products.where((p) => p.id == _productId).firstOrNull?.purchaseUom ?? '';
    return Form(
      key: _form,
      child: FormScaffold(
        title: 'Novo preço de fornecedor',
        saving: _saving,
        onSave: _save,
        child: Column(
          children: [
            ErpDropdown<String>(
              label: 'Produto',
              value: _productId,
              items: [for (final p in products) DropdownMenuItem(value: p.id, child: Text('${p.sku} — ${p.name}', overflow: TextOverflow.ellipsis))],
              onChanged: (v) => setState(() => _productId = v),
            ),
            ErpDropdown<String>(
              label: 'Fornecedor',
              value: _supplierId,
              items: [for (final s in suppliers) DropdownMenuItem(value: s.id, child: Text(s.displayName, overflow: TextOverflow.ellipsis))],
              onChanged: (v) => setState(() => _supplierId = v),
            ),
            ErpField('Qtd mínima${uom.isEmpty ? '' : ' ($uom)'}', _minQty, keyboard: const TextInputType.numberWithOptions(decimal: true), required: true),
            ErpField('Preço', _price, keyboard: const TextInputType.numberWithOptions(decimal: true), required: true),
            const Text(
              'O preço vale para a quantidade mínima, na unidade de compra do produto (ex.: R\$ 12 por 1,5 CX).',
              style: TextStyle(color: erpMuted, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------- Agendamentos

class SchedulesPage extends ConsumerWidget {
  const SchedulesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return CrudList<BudgetSchedule>(
      value: ref.watch(schedulesProvider),
      onRefresh: () async => ref.invalidate(schedulesProvider),
      isThreeLine: true,
      titleOf: (s) => '${s.name}${s.active ? '' : '  (inativo)'}',
      subtitleOf: (s) =>
          '${s.weekly ? 'Semanal · ${weekdays[s.dayOfWeek.clamp(0, 6)]}' : 'Mensal · dia ${s.dayOfMonth}'}\n'
          'Próxima: ${fmtDt(s.nextRunAt)} · Última: ${fmtDt(s.lastRunAt)}',
      onCreate: () => pushForm(context, const _ScheduleForm()),
      onEdit: (s) => pushForm(context, _ScheduleForm(schedule: s)),
      extraActions: (_) => const [PopupMenuItem(value: 'run', child: Text('Executar agora'))],
      onAction: (s, action) async {
        if (action != 'run') return;
        if (await runAction(context, ref.read(biRepositoryProvider).runScheduleNow(s.id))) {
          ref.invalidate(schedulesProvider);
          ref.invalidate(budgetsProvider);
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Orçamento gerado.')));
          }
        }
      },
      onDelete: (s) async {
        if (await runAction(context, ref.read(biRepositoryProvider).deleteSchedule(s.id))) {
          ref.invalidate(schedulesProvider);
        }
      },
    );
  }
}

class _ScheduleForm extends ConsumerStatefulWidget {
  const _ScheduleForm({this.schedule});

  final BudgetSchedule? schedule;

  @override
  ConsumerState<_ScheduleForm> createState() => _ScheduleFormState();
}

class _ScheduleFormState extends ConsumerState<_ScheduleForm> {
  final _form = GlobalKey<FormState>();
  late final BudgetSchedule _s = widget.schedule ?? const BudgetSchedule(name: '', frequency: 'WEEKLY');
  late final _name = TextEditingController(text: _s.name);
  late final _dayOfMonth = TextEditingController(text: '${_s.dayOfMonth}');
  late final _coverage = TextEditingController(text: '${_s.coverageWeeks}');
  late final _safety = TextEditingController(text: fmtQty(_s.safetyPercent));
  late final _lookback = TextEditingController(text: '${_s.lookbackWeeks}');
  late String _frequency = _s.frequency;
  late int _dayOfWeek = _s.dayOfWeek.clamp(0, 6);
  late bool _active = _s.active;
  bool _saving = false;

  @override
  void dispose() {
    for (final c in [_name, _dayOfMonth, _coverage, _safety, _lookback]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _saving = true);
    final ok = await runAction(
      context,
      ref.read(biRepositoryProvider).saveSchedule(
            BudgetSchedule(
              id: _s.id,
              name: _name.text.trim(),
              frequency: _frequency,
              dayOfWeek: _dayOfWeek,
              dayOfMonth: (int.tryParse(_dayOfMonth.text.trim()) ?? 1).clamp(1, 31),
              coverageWeeks: (int.tryParse(_coverage.text.trim()) ?? 4).clamp(1, 1000),
              safetyPercent: parseNum(_safety.text, 10),
              lookbackWeeks: (int.tryParse(_lookback.text.trim()) ?? 8).clamp(1, 1000),
              active: _active,
            ),
          ),
    );
    if (!mounted) return;
    setState(() => _saving = false);
    if (ok) {
      ref.invalidate(schedulesProvider);
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    const numeric = TextInputType.numberWithOptions(decimal: true);
    return Form(
      key: _form,
      child: FormScaffold(
        title: widget.schedule == null ? 'Novo agendamento' : 'Editar agendamento',
        saving: _saving,
        onSave: _save,
        child: Column(
          children: [
            ErpField('Nome', _name, required: true),
            ErpDropdown<String>(
              label: 'Frequência',
              value: _frequency,
              items: const [
                DropdownMenuItem(value: 'WEEKLY', child: Text('Semanal')),
                DropdownMenuItem(value: 'MONTHLY', child: Text('Mensal')),
              ],
              onChanged: (v) => setState(() => _frequency = v ?? 'WEEKLY'),
            ),
            if (_frequency == 'WEEKLY')
              ErpDropdown<int>(
                label: 'Dia da semana',
                value: _dayOfWeek,
                items: [for (var i = 0; i < weekdays.length; i++) DropdownMenuItem(value: i, child: Text(weekdays[i]))],
                onChanged: (v) => setState(() => _dayOfWeek = v ?? 1),
              )
            else
              ErpField('Dia do mês (1-31)', _dayOfMonth, keyboard: TextInputType.number, required: true),
            ErpField('Cobertura (semanas)', _coverage, keyboard: TextInputType.number, required: true),
            ErpField('Margem de segurança (%)', _safety, keyboard: numeric),
            ErpField('Semanas de histórico', _lookback, keyboard: TextInputType.number, required: true),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Ativo'),
              value: _active,
              onChanged: (v) => setState(() => _active = v),
            ),
          ],
        ),
      ),
    );
  }
}
