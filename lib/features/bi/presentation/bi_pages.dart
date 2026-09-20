import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/widgets/crud_list.dart';
import '../../../app/widgets/form_kit.dart';
import '../domain/entities.dart';
import 'bi_providers.dart';
import 'bi_widgets.dart';

int _weeks(TextEditingController c, int fallback) {
  final v = int.tryParse(c.text.trim()) ?? fallback;
  return v < 1 ? 1 : v;
}

// ---------------------------------------------------------------- Previsão

class ForecastPage extends ConsumerStatefulWidget {
  const ForecastPage({super.key});

  @override
  ConsumerState<ForecastPage> createState() => _ForecastPageState();
}

class _ForecastPageState extends ConsumerState<ForecastPage> {
  final _lookback = TextEditingController(text: '8');
  ForecastParams _params = (lookbackWeeks: 8, includeExcluded: false);

  @override
  void dispose() {
    _lookback.dispose();
    super.dispose();
  }

  void _apply({bool? includeExcluded}) => setState(() {
        _params = (
          lookbackWeeks: _weeks(_lookback, 8),
          includeExcluded: includeExcluded ?? _params.includeExcluded,
        );
      });

  void _reload() => ref.invalidate(forecastsProvider(_params));

  Future<void> _edit(Forecast f, String uom) async {
    final action = await showDialog<_ForecastAction>(
      context: context,
      builder: (_) => _ForecastDialog(forecast: f, uom: uom),
    );
    if (action == null || !mounted) return;
    final repo = ref.read(biRepositoryProvider);
    final ok = await runAction(
      context,
      switch (action) {
        _SaveOverride(:final qty) => repo.setForecastOverride(f.kind, f.targetId, qty),
        _ClearOverride() => repo.clearForecastOverride(f.kind, f.targetId),
        _Hide() => repo.excludeForecast(f.kind, f.targetId),
        _Restore() => repo.includeForecast(f.kind, f.targetId),
      },
    );
    if (ok) _reload();
  }

  @override
  Widget build(BuildContext context) {
    final products = productsById(ref);
    String uom(Forecast f) => f.isKit ? 'un' : (products[f.targetId]?.stockUom ?? '');
    return Column(
      children: [
        ParamsCard(
          fields: [NumParam(label: 'Semanas de histórico', controller: _lookback)],
          actions: [
            FilledButton(onPressed: () => _apply(), child: const Text('Atualizar')),
            FilterChip(
              label: const Text('Mostrar ocultos'),
              selected: _params.includeExcluded,
              onSelected: (v) => _apply(includeExcluded: v),
            ),
          ],
        ),
        Expanded(
          child: CrudList<Forecast>(
            value: ref.watch(forecastsProvider(_params)),
            onRefresh: () async => _reload(),
            isThreeLine: true,
            titleOf: (f) => '${f.code} — ${f.name}${f.excluded ? '  (oculto)' : ''}',
            subtitleOf: (f) {
              final u = uom(f);
              final manual = f.overrideWeeklyQty == null ? '—' : fmtQty(f.overrideWeeklyQty!);
              return '${f.isKit ? 'Kit' : 'Produto'}\n'
                  'Calculado ${fmtQty(f.computedWeeklyQty)} · Manual $manual · Efetivo ${fmtQty(f.effectiveWeeklyQty)} $u/sem';
            },
            onTap: (f) => _edit(f, uom(f)),
          ),
        ),
      ],
    );
  }
}

sealed class _ForecastAction {}

class _SaveOverride extends _ForecastAction {
  _SaveOverride(this.qty);
  final double qty;
}

class _ClearOverride extends _ForecastAction {}

class _Hide extends _ForecastAction {}

class _Restore extends _ForecastAction {}

class _ForecastDialog extends StatefulWidget {
  const _ForecastDialog({required this.forecast, required this.uom});

  final Forecast forecast;
  final String uom;

  @override
  State<_ForecastDialog> createState() => _ForecastDialogState();
}

class _ForecastDialogState extends State<_ForecastDialog> {
  late final _qty = TextEditingController(
    text: widget.forecast.overrideWeeklyQty == null ? '' : fmtQty(widget.forecast.overrideWeeklyQty!),
  );

  @override
  void dispose() {
    _qty.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final f = widget.forecast;
    return AlertDialog(
      title: Text('${f.code} — ${f.name}'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Média calculada: ${fmtQty(f.computedWeeklyQty)} ${widget.uom}/sem'),
          const SizedBox(height: 12),
          if (!f.excluded)
            TextField(
              controller: _qty,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(labelText: 'Sobreposição manual (${widget.uom}/sem)'),
            ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Fechar')),
        if (f.excluded)
          TextButton(onPressed: () => Navigator.pop(context, _Restore()), child: const Text('Restaurar'))
        else ...[
          TextButton(onPressed: () => Navigator.pop(context, _Hide()), child: const Text('Ocultar')),
          if (f.overrideWeeklyQty != null)
            TextButton(onPressed: () => Navigator.pop(context, _ClearOverride()), child: const Text('Limpar')),
          FilledButton(
            onPressed: () {
              final qty = double.tryParse(_qty.text.trim().replaceAll(',', '.'));
              if (qty == null || qty < 0) {
                showError(context, 'Informe uma quantidade válida.');
                return;
              }
              Navigator.pop(context, _SaveOverride(qty));
            },
            child: const Text('Salvar'),
          ),
        ],
      ],
    );
  }
}

// ------------------------------------------------------- Plano de estoque

class StoragePlanPage extends ConsumerStatefulWidget {
  const StoragePlanPage({super.key});

  @override
  ConsumerState<StoragePlanPage> createState() => _StoragePlanPageState();
}

class _StoragePlanPageState extends ConsumerState<StoragePlanPage> {
  final _coverage = TextEditingController(text: '4');
  final _safety = TextEditingController(text: '10');
  final _lookback = TextEditingController(text: '8');
  PlanParams _params = (coverageWeeks: 4, safetyPercent: 10, lookbackWeeks: 8);
  bool _generating = false;

  @override
  void dispose() {
    _coverage.dispose();
    _safety.dispose();
    _lookback.dispose();
    super.dispose();
  }

  PlanParams _read() => (
        coverageWeeks: _weeks(_coverage, 4),
        safetyPercent: parseNum(_safety.text, 10).clamp(0, double.infinity).toDouble(),
        lookbackWeeks: _weeks(_lookback, 8),
      );

  Future<void> _generate() async {
    setState(() => _generating = true);
    final r = await ref.read(biRepositoryProvider).createBudget(_read());
    if (!mounted) return;
    setState(() => _generating = false);
    r.when(
      ok: (_) {
        ref.invalidate(budgetsProvider);
        context.go('/bi/orcamentos');
      },
      err: (f) => showError(context, f.message),
    );
  }

  @override
  Widget build(BuildContext context) {
    final products = productsById(ref);
    String uom(String id) => products[id]?.stockUom ?? '';
    return Column(
      children: [
        ParamsCard(
          fields: [
            NumParam(label: 'Cobertura (sem.)', controller: _coverage),
            NumParam(label: 'Segurança (%)', controller: _safety, decimal: true),
            NumParam(label: 'Histórico (sem.)', controller: _lookback),
          ],
          actions: [
            FilledButton(onPressed: () => setState(() => _params = _read()), child: const Text('Atualizar')),
            OutlinedButton(
              onPressed: _generating ? null : _generate,
              child: Text(_generating ? 'Gerando...' : 'Gerar orçamento'),
            ),
          ],
        ),
        Expanded(
          child: CrudList<PlanLine>(
            value: ref.watch(storagePlanProvider(_params)),
            onRefresh: () async => ref.invalidate(storagePlanProvider(_params)),
            isThreeLine: true,
            titleOf: (l) => '${l.sku} — ${l.name}',
            subtitleOf: (l) {
              final u = uom(l.productId);
              return 'Previsão ${fmtQty(l.forecastQty)} · Estoque ${fmtQty(l.onHandQty)} · Em compra ${fmtQty(l.openPoQty)}\n'
                  'Necessário: ${fmtQty(l.neededQty)} $u';
            },
          ),
        ),
      ],
    );
  }
}

// ------------------------------------------------------ Receita x Despesa

class FinancialPage extends ConsumerStatefulWidget {
  const FinancialPage({super.key});

  @override
  ConsumerState<FinancialPage> createState() => _FinancialPageState();
}

class _FinancialPageState extends ConsumerState<FinancialPage> {
  final _lookback = TextEditingController(text: '8');
  final _horizon = TextEditingController(text: '4');
  int _lookbackApplied = 8;
  int _horizonApplied = 4;

  @override
  void dispose() {
    _lookback.dispose();
    _horizon.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final value = ref.watch(financialsProvider(_lookbackApplied));
    final lines = value.valueOrNull ?? const <FinancialLine>[];
    final revenue = lines.fold<double>(0, (n, l) => n + l.weeklyRevenue);
    final cost = lines.fold<double>(0, (n, l) => n + l.weeklyCost);
    final profit = revenue - cost;
    final margin = revenue > 0 ? profit / revenue * 100 : 0.0;
    final sorted = [...lines]..sort((a, b) => b.weeklyProfit.compareTo(a.weeklyProfit));
    final w = _horizonApplied;

    return Column(
      children: [
        ParamsCard(
          fields: [
            NumParam(label: 'Histórico (sem.)', controller: _lookback),
            NumParam(label: 'Projeção (sem.)', controller: _horizon),
          ],
          actions: [
            FilledButton(
              onPressed: () => setState(() {
                _lookbackApplied = _weeks(_lookback, 8);
                _horizonApplied = _weeks(_horizon, 4);
              }),
              child: const Text('Atualizar'),
            ),
          ],
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              StatCard(label: 'Receita/semana', value: brl(revenue), hint: '${brl(revenue * w)} em $w sem.'),
              StatCard(label: 'Despesa/semana', value: brl(cost), hint: '${brl(cost * w)} em $w sem.'),
              StatCard(label: 'Lucro/semana', value: brl(profit), negative: profit < 0, hint: '${brl(profit * w)} em $w sem.'),
              StatCard(label: 'Margem', value: fmtPct(margin), negative: margin < 0),
            ],
          ),
        ),
        Expanded(
          child: CrudList<FinancialLine>(
            value: value.whenData((_) => sorted),
            onRefresh: () async => ref.invalidate(financialsProvider(_lookbackApplied)),
            isThreeLine: true,
            titleOf: (l) => '${l.code} — ${l.name}',
            subtitleOf: (l) =>
                '${l.kind == 'KIT' ? 'Kit' : 'Produto'} · ${fmtQty(l.weeklyQty)}/sem · venda ${brl(l.unitRevenue)} · custo ${brl(l.unitCost)}\n'
                'Receita ${brl(l.weeklyRevenue)} · Despesa ${brl(l.weeklyCost)} · Lucro ${brl(l.weeklyProfit)} (${fmtPct(l.marginPercent)})',
          ),
        ),
      ],
    );
  }
}
