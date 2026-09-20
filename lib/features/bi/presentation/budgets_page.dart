import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme.dart';
import '../../../app/widgets/crud_list.dart';
import '../../../app/widgets/form_kit.dart';
import '../../config/domain/entities.dart';
import '../../purchasing/presentation/purchasing_providers.dart';
import '../../stock/domain/entities.dart';
import '../data/bi_repository_impl.dart';
import '../domain/entities.dart';
import 'bi_providers.dart';
import 'bi_widgets.dart';

class BudgetsPage extends ConsumerWidget {
  const BudgetsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return CrudList<Budget>(
      value: ref.watch(budgetsProvider),
      onRefresh: () async => ref.invalidate(budgetsProvider),
      titleOf: (b) => '${b.code} · ${b.statusLabel}',
      subtitleOf: (b) =>
          '${b.coverageWeeks} sem · ${fmtQty(b.safetyPercent)}% · ${fmtDt(b.createdAt)}',
      onTap: (b) => pushForm(context, BudgetDetailPage(budgetId: b.id)),
      onCreate: () => _generate(context, ref),
      onDelete: (b) async {
        if (b.status == 'CONFIRMED') {
          showError(context, 'Orçamento confirmado não pode ser excluído.');
          return;
        }
        if (await runAction(context, ref.read(biRepositoryProvider).deleteBudget(b.id))) {
          ref.invalidate(budgetsProvider);
        }
      },
    );
  }

  Future<void> _generate(BuildContext context, WidgetRef ref) async {
    final params = await showDialog<PlanParams>(context: context, builder: (_) => const _GenerateDialog());
    if (params == null || !context.mounted) return;
    final r = await ref.read(biRepositoryProvider).createBudget(params);
    if (!context.mounted) return;
    r.when(
      ok: (b) {
        ref.invalidate(budgetsProvider);
        pushForm(context, BudgetDetailPage(budgetId: b.id));
      },
      err: (f) => showError(context, f.message),
    );
  }
}

class _GenerateDialog extends StatefulWidget {
  const _GenerateDialog();

  @override
  State<_GenerateDialog> createState() => _GenerateDialogState();
}

class _GenerateDialogState extends State<_GenerateDialog> {
  final _coverage = TextEditingController(text: '4');
  final _safety = TextEditingController(text: '10');
  final _lookback = TextEditingController(text: '8');

  @override
  void dispose() {
    _coverage.dispose();
    _safety.dispose();
    _lookback.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Gerar orçamento'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'Usa os mesmos parâmetros do Plano de estoque para montar um novo orçamento em rascunho.',
            style: TextStyle(color: erpMuted),
          ),
          const SizedBox(height: 12),
          NumParam(label: 'Cobertura (semanas)', controller: _coverage),
          const SizedBox(height: 8),
          NumParam(label: 'Margem de segurança (%)', controller: _safety, decimal: true),
          const SizedBox(height: 8),
          NumParam(label: 'Semanas de histórico', controller: _lookback),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
        FilledButton(
          onPressed: () => Navigator.pop<PlanParams>(context, (
            coverageWeeks: (int.tryParse(_coverage.text.trim()) ?? 4).clamp(1, 1000),
            safetyPercent: parseNum(_safety.text, 10).clamp(0, double.infinity).toDouble(),
            lookbackWeeks: (int.tryParse(_lookback.text.trim()) ?? 8).clamp(1, 1000),
          )),
          child: const Text('Gerar'),
        ),
      ],
    );
  }
}

class BudgetDetailPage extends ConsumerWidget {
  const BudgetDetailPage({super.key, required this.budgetId});

  final String budgetId;

  void _refresh(WidgetRef ref) {
    ref.invalidate(budgetProvider(budgetId));
    ref.invalidate(budgetsProvider);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final value = ref.watch(budgetProvider(budgetId));
    final products = productsById(ref);
    final suppliers = <String, String>{
      for (final s in ref.watch(suppliersProvider).valueOrNull ?? const <Person>[]) s.id: s.displayName,
    };
    final prices = ref.watch(supplierPricesProvider).valueOrNull ?? const <SupplierPrice>[];

    return Scaffold(
      appBar: AppBar(
        title: Text(value.valueOrNull == null ? 'Orçamento' : 'Orçamento ${value.value!.code}'),
        leading: IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.of(context).pop()),
      ),
      body: value.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Padding(padding: const EdgeInsets.all(24), child: Text(errText(e), style: const TextStyle(color: erpDanger))),
        ),
        data: (b) => RefreshIndicator(
          onRefresh: () async => _refresh(ref),
          child: ListView(
            padding: const EdgeInsets.all(12),
            children: [
              Row(
                children: [
                  Badge2(b.statusLabel),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '${b.coverageWeeks} sem. de cobertura · ${fmtQty(b.safetyPercent)}% de margem · ${b.lookbackWeeks} sem. de histórico',
                      style: const TextStyle(color: erpMuted, fontSize: 12),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              const Text(
                '"Necessário" é um retrato do momento em que o orçamento foi gerado e pode divergir do plano atual.',
                style: TextStyle(color: erpMuted, fontSize: 12),
              ),
              if (b.items.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(child: Text('Nenhum produto precisa de reposição.', style: TextStyle(color: erpMuted))),
                ),
              for (final item in b.items)
                _ItemCard(
                  budget: b,
                  item: item,
                  products: products,
                  suppliers: suppliers,
                  prices: prices,
                  onChanged: () => _refresh(ref),
                ),
              if (b.editable) ...[
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: () async {
                    if (await runAction(context, ref.read(biRepositoryProvider).confirmBudget(b.id))) _refresh(ref);
                  },
                  child: const Text('Confirmar orçamento'),
                ),
                const SizedBox(height: 8),
                OutlinedButton(
                  onPressed: () async {
                    if (!await confirmDialog(context, 'Cancelar este orçamento?', action: 'Cancelar orçamento')) return;
                    if (!context.mounted) return;
                    if (await runAction(context, ref.read(biRepositoryProvider).cancelBudget(b.id))) _refresh(ref);
                  },
                  child: const Text('Cancelar orçamento'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _ItemCard extends ConsumerWidget {
  const _ItemCard({
    required this.budget,
    required this.item,
    required this.products,
    required this.suppliers,
    required this.prices,
    required this.onChanged,
  });

  final Budget budget;
  final BudgetItem item;
  final Map<String, Product> products;
  final Map<String, String> suppliers;
  final List<SupplierPrice> prices;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.read(biRepositoryProvider);
    final product = products[item.productId];
    final uom = product?.stockUom ?? '';
    final remaining = item.remainingQty;
    return Card(
      color: erpPanel,
      margin: const EdgeInsets.only(top: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(productLabel(products, item.productId), style: const TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            Text(
              'Necessário ${fmtQty(item.neededQty)} $uom · Alocado ${fmtQty(item.allocatedQty)} · Restante ${fmtQty(remaining)}',
              style: const TextStyle(color: erpMuted, fontSize: 13),
            ),
            for (final a in item.allocations)
              ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                title: Text(suppliers[a.supplierId] ?? a.supplierId),
                subtitle: Text(
                  '${fmtQty(a.quantity)} $uom × ${brl(a.unitPrice)}/$uom = ${brl(a.quantity * a.unitPrice)}'
                  '${a.hasQuote ? ' · cotação gerada' : ''}',
                  style: const TextStyle(color: erpMuted),
                ),
                trailing: budget.editable && !a.hasQuote
                    ? IconButton(
                        icon: const Icon(Icons.delete_outline, color: erpDanger),
                        onPressed: () async {
                          if (await runAction(context, repo.deleteAllocation(budget.id, a.id))) onChanged();
                        },
                      )
                    : null,
              ),
            if (budget.editable)
              Wrap(
                spacing: 8,
                children: [
                  TextButton(onPressed: () => _editNeeded(context, repo), child: const Text('Necessário')),
                  if (remaining > 0)
                    TextButton(onPressed: () => _allocate(context, ref, remaining), child: const Text('Alocar')),
                  TextButton(
                    onPressed: () async {
                      final msg = item.allocatedQty > 0
                          ? 'Este item já tem alocações. Excluí-lo também as removerá. Confirma?'
                          : 'Excluir este item do orçamento?';
                      if (!await confirmDialog(context, msg, action: 'Excluir')) return;
                      if (!context.mounted) return;
                      if (await runAction(context, repo.deleteItem(budget.id, item.id))) onChanged();
                    },
                    child: const Text('Excluir', style: TextStyle(color: erpDanger)),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _editNeeded(BuildContext context, BiRepositoryImpl repo) async {
    final qty = await showDialog<double>(
      context: context,
      builder: (_) => _QtyDialog(title: 'Necessário', label: 'Quantidade', initial: fmtQty(item.neededQty)),
    );
    if (qty == null || !context.mounted) return;
    if (await runAction(context, repo.updateItemNeeded(budget.id, item.id, qty))) onChanged();
  }

  Future<void> _allocate(BuildContext context, WidgetRef ref, double remaining) async {
    final people = ref.read(suppliersProvider).valueOrNull ?? [];
    final product = products[item.productId];
    final result = await showDialog<_AllocationInput>(
      context: context,
      builder: (_) => _AllocationDialog(
        suppliers: [for (final s in people) (id: s.id, name: s.displayName)],
        remaining: remaining,
        priceFor: (supplierId) {
          final sp = prices.where((x) => x.productId == item.productId && x.supplierId == supplierId).firstOrNull;
          return sp == null ? null : supplierUnitCost(product, sp);
        },
        bestSupplierId: bestSupplierPrice(product, prices)?.sp.supplierId,
      ),
    );
    if (result == null || !context.mounted) return;
    final ok = await runAction(
      context,
      ref.read(biRepositoryProvider).addAllocation(
            budget.id,
            item.id,
            supplierId: result.supplierId,
            quantity: result.qty,
            unitPrice: result.price,
          ),
    );
    if (ok) onChanged();
  }
}

class _QtyDialog extends StatefulWidget {
  const _QtyDialog({required this.title, required this.label, required this.initial});

  final String title;
  final String label;
  final String initial;

  @override
  State<_QtyDialog> createState() => _QtyDialogState();
}

class _QtyDialogState extends State<_QtyDialog> {
  late final _c = TextEditingController(text: widget.initial);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: NumParam(label: widget.label, controller: _c, decimal: true),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
        FilledButton(
          onPressed: () {
            final v = double.tryParse(_c.text.trim().replaceAll(',', '.'));
            if (v == null || v < 0) {
              showError(context, 'Quantidade inválida.');
              return;
            }
            Navigator.pop(context, v);
          },
          child: const Text('Salvar'),
        ),
      ],
    );
  }
}

class _AllocationInput {
  const _AllocationInput(this.supplierId, this.qty, this.price);
  final String supplierId;
  final double qty;
  final double price;
}

class _AllocationDialog extends StatefulWidget {
  const _AllocationDialog({
    required this.suppliers,
    required this.remaining,
    required this.priceFor,
    required this.bestSupplierId,
  });

  final List<({String id, String name})> suppliers;
  final double remaining;
  final double? Function(String supplierId) priceFor;
  final String? bestSupplierId;

  @override
  State<_AllocationDialog> createState() => _AllocationDialogState();
}

class _AllocationDialogState extends State<_AllocationDialog> {
  String? _supplierId;
  late final _qty = TextEditingController(text: fmtQty(widget.remaining));
  final _price = TextEditingController();

  @override
  void initState() {
    super.initState();
    _pick(widget.bestSupplierId);
  }

  @override
  void dispose() {
    _qty.dispose();
    _price.dispose();
    super.dispose();
  }

  void _pick(String? id) {
    _supplierId = id;
    final p = id == null ? null : widget.priceFor(id);
    if (p != null) _price.text = p.toStringAsFixed(4).replaceFirst(RegExp(r'\.?0+$'), '').replaceAll('.', ',');
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Alocar fornecedor'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ErpDropdown<String>(
              label: 'Fornecedor',
              value: _supplierId,
              items: [for (final s in widget.suppliers) DropdownMenuItem(value: s.id, child: Text(s.name))],
              onChanged: (v) => setState(() => _pick(v)),
            ),
            NumParam(label: 'Quantidade', controller: _qty, decimal: true),
            const SizedBox(height: 8),
            NumParam(label: 'Preço unitário', controller: _price, decimal: true),
            if (widget.bestSupplierId != null && _supplierId == widget.bestSupplierId)
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text('Melhor preço cadastrado', style: TextStyle(color: erpMuted, fontSize: 12)),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
        FilledButton(
          onPressed: () {
            final qty = parseNum(_qty.text);
            if (_supplierId == null || qty <= 0) {
              showError(context, 'Selecione o fornecedor e informe a quantidade.');
              return;
            }
            Navigator.pop(context, _AllocationInput(_supplierId!, qty, parseNum(_price.text)));
          },
          child: const Text('Alocar'),
        ),
      ],
    );
  }
}
