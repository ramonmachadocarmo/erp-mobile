import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/di.dart';
import '../../../app/theme.dart';
import '../../../app/widgets/crud_list.dart';
import '../../../app/widgets/form_kit.dart';
import '../../../app/widgets/status_chip.dart';
import '../../../core/json.dart';
import '../../bi/presentation/bi_widgets.dart';
import '../data/reports_repository_impl.dart';

final reportsRepositoryProvider = Provider(
  (ref) => ReportsRepositoryImpl(ref.watch(apiClientProvider)),
);

typedef DateRange = ({String from, String to});

final kitsReportProvider = FutureProvider.autoDispose<ReportRows>(
  (ref) => ref.read(reportsRepositoryProvider).kits().then((r) => r.getOrThrow()),
);

final stockReportProvider = FutureProvider.autoDispose<ReportRows>(
  (ref) => ref.read(reportsRepositoryProvider).stock().then((r) => r.getOrThrow()),
);

final salesReportProvider = FutureProvider.autoDispose.family<ReportRows, DateRange>(
  (ref, r) => ref.read(reportsRepositoryProvider).sales(from: r.from, to: r.to).then((x) => x.getOrThrow()),
);

final purchasesReportProvider = FutureProvider.autoDispose.family<ReportRows, DateRange>(
  (ref, r) => ref.read(reportsRepositoryProvider).purchases(from: r.from, to: r.to).then((x) => x.getOrThrow()),
);

final customerRankingReportProvider = FutureProvider.autoDispose.family<ReportRows, DateRange>(
  (ref, r) => ref.read(reportsRepositoryProvider).customerRanking(from: r.from, to: r.to).then((x) => x.getOrThrow()),
);

final forecastReportProvider =
    FutureProvider.autoDispose.family<ReportRows, ({int coverageWeeks, double safetyPercent, int lookbackWeeks})>(
  (ref, p) => ref
      .read(reportsRepositoryProvider)
      .forecast(coverageWeeks: p.coverageWeeks, safetyPercent: p.safetyPercent, lookbackWeeks: p.lookbackWeeks)
      .then((x) => x.getOrThrow()),
);

String _dash(String s) => s.isEmpty ? '—' : s;

// -------------------------------------------------------------------- Kits

class KitsReportPage extends ConsumerWidget {
  const KitsReportPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return CrudList<Map<String, dynamic>>(
      value: ref.watch(kitsReportProvider),
      onRefresh: () async => ref.invalidate(kitsReportProvider),
      isThreeLine: true,
      titleOf: (k) => '${asString(k, 'code')} — ${asString(k, 'name')}',
      subtitleOf: (k) =>
          '${asMapList(k['items']).length} itens\n'
          'Custo ${brl(asDouble(k, 'cost'))} · Preço sugerido ${brl(asDouble(k, 'suggested_price'))} · Margem ${fmtPct(asDouble(k, 'margin_percent'))}',
      onTap: (k) => showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        backgroundColor: erpPanel,
        builder: (_) => _KitSheet(kit: k),
      ),
    );
  }
}

class _KitSheet extends StatelessWidget {
  const _KitSheet({required this.kit});

  final Map<String, dynamic> kit;

  @override
  Widget build(BuildContext context) {
    final items = asMapList(kit['items']);
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.7,
      maxChildSize: 0.95,
      builder: (context, scroll) => ListView(
        controller: scroll,
        padding: const EdgeInsets.all(16),
        children: [
          Text('${asString(kit, 'code')} — ${asString(kit, 'name')}', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 4),
          Text(
            'Custo ${brl(asDouble(kit, 'cost'))} · Preço sugerido ${brl(asDouble(kit, 'suggested_price'))} · Margem ${fmtPct(asDouble(kit, 'margin_percent'))}',
            style: const TextStyle(color: erpMuted),
          ),
          const Divider(height: 24, color: erpLine),
          if (items.isEmpty) const Text('Kit sem itens.', style: TextStyle(color: erpMuted)),
          for (final it in items)
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text('${asString(it, 'product_sku').isEmpty ? '' : '${asString(it, 'product_sku')} — '}${asString(it, 'product_name')}'),
              subtitle: Text(
                '${_dash(asString(it, 'role'))} · ${fmtQty(asDouble(it, 'quantity'))} ${asString(it, 'uom')}\n'
                'Custo ${brl(asDouble(it, 'line_cost'))} (${brl(asDouble(it, 'unit_cost'))}/${asString(it, 'uom')}) · Venda prop. ${brl(asDouble(it, 'proportional_sale_price'))}',
                style: const TextStyle(color: erpMuted),
              ),
              isThreeLine: true,
            ),
        ],
      ),
    );
  }
}

// ----------------------------------------------------------------- Estoque

class StockReportPage extends ConsumerWidget {
  const StockReportPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return CrudList<Map<String, dynamic>>(
      value: ref.watch(stockReportProvider),
      onRefresh: () async => ref.invalidate(stockReportProvider),
      isThreeLine: true,
      titleOf: (r) => '${asString(r, 'sku')} — ${asString(r, 'product_name')}',
      subtitleOf: (r) =>
          '${_dash(asString(r, 'warehouse_name'))}\n'
          'Disponível ${fmtQty(asDouble(r, 'quantity_available'))} ${asString(r, 'uom')} · Reservado ${fmtQty(asDouble(r, 'quantity_reserved'))}',
    );
  }
}

// ----------------------------------------------------- Vendas e compras

class _OrdersReport extends ConsumerStatefulWidget {
  const _OrdersReport({required this.provider, required this.partyKey});

  final AutoDisposeFutureProviderFamily<ReportRows, DateRange> provider;
  final String partyKey;

  @override
  ConsumerState<_OrdersReport> createState() => _OrdersReportState();
}

class _OrdersReportState extends ConsumerState<_OrdersReport> {
  String _from = '';
  String _to = '';

  DateRange get _range => (from: _from, to: _to);

  String _iso(DateTime d) => '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Future<void> _pick(bool isFrom) async {
    final current = DateTime.tryParse(isFrom ? _from : _to) ?? DateTime.now();
    final d = await showDatePicker(
      context: context,
      initialDate: current,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (d == null) return;
    setState(() => isFrom ? _from = _iso(d) : _to = _iso(d));
  }

  @override
  Widget build(BuildContext context) {
    final value = ref.watch(widget.provider(_range));
    final total = (value.valueOrNull ?? const []).fold<double>(0, (n, r) => n + asDouble(r, 'total_amount'));
    return Column(
      children: [
        ParamsCard(
          fields: const [],
          actions: [
            OutlinedButton.icon(
              onPressed: () => _pick(true),
              icon: const Icon(Icons.event, size: 18),
              label: Text(_from.isEmpty ? 'De' : 'De $_from'),
            ),
            OutlinedButton.icon(
              onPressed: () => _pick(false),
              icon: const Icon(Icons.event, size: 18),
              label: Text(_to.isEmpty ? 'Até' : 'Até $_to'),
            ),
            if (_from.isNotEmpty || _to.isNotEmpty)
              TextButton(onPressed: () => setState(() => _from = _to = ''), child: const Text('Limpar')),
          ],
        ),
        if (value.hasValue)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text('${value.value!.length} pedidos · total ${brl(total)}', style: const TextStyle(color: erpMuted)),
            ),
          ),
        Expanded(
          child: CrudList<Map<String, dynamic>>(
            value: value,
            onRefresh: () async => ref.invalidate(widget.provider(_range)),
            isThreeLine: true,
            titleOf: (r) => '${fmtDt(asString(r, 'created_at'))} — ${_dash(asString(r, widget.partyKey))}',
            subtitleOf: (r) =>
                '${statusView(asString(r, 'status')).label} · ${brl(asDouble(r, 'total_amount'))}\n${_dash(asString(r, 'item_summary'))}',
          ),
        ),
      ],
    );
  }
}

class SalesReportPage extends StatelessWidget {
  const SalesReportPage({super.key});

  @override
  Widget build(BuildContext context) => _OrdersReport(provider: salesReportProvider, partyKey: 'customer_name');
}

class PurchasesReportPage extends StatelessWidget {
  const PurchasesReportPage({super.key});

  @override
  Widget build(BuildContext context) => _OrdersReport(provider: purchasesReportProvider, partyKey: 'supplier_name');
}

// ------------------------------------------------------------------- CRM

class CrmCustomersPage extends ConsumerStatefulWidget {
  const CrmCustomersPage({super.key});

  @override
  ConsumerState<CrmCustomersPage> createState() => _CrmCustomersPageState();
}

class _CrmCustomersPageState extends ConsumerState<CrmCustomersPage> {
  String _from = '';
  String _to = '';

  DateRange get _range => (from: _from, to: _to);

  String _iso(DateTime d) => '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Future<void> _pick(bool isFrom) async {
    final current = DateTime.tryParse(isFrom ? _from : _to) ?? DateTime.now();
    final d = await showDatePicker(
      context: context,
      initialDate: current,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (d == null) return;
    setState(() => isFrom ? _from = _iso(d) : _to = _iso(d));
  }

  @override
  Widget build(BuildContext context) {
    final value = ref.watch(customerRankingReportProvider(_range));
    final rows = value.valueOrNull ?? const <Map<String, dynamic>>[];
    final orders = rows.fold<double>(0, (n, r) => n + asDouble(r, 'order_count'));
    final spent = rows.fold<double>(0, (n, r) => n + asDouble(r, 'total_amount'));
    final cancelled = rows.fold<double>(0, (n, r) => n + asDouble(r, 'cancelled_count'));
    return Column(
      children: [
        ParamsCard(
          fields: const [],
          actions: [
            OutlinedButton.icon(
              onPressed: () => _pick(true),
              icon: const Icon(Icons.event, size: 18),
              label: Text(_from.isEmpty ? 'De' : 'De $_from'),
            ),
            OutlinedButton.icon(
              onPressed: () => _pick(false),
              icon: const Icon(Icons.event, size: 18),
              label: Text(_to.isEmpty ? 'Até' : 'Até $_to'),
            ),
            if (_from.isNotEmpty || _to.isNotEmpty)
              TextButton(onPressed: () => setState(() => _from = _to = ''), child: const Text('Limpar')),
          ],
        ),
        if (value.hasValue)
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 4),
            child: Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                StatCard(label: 'Clientes', value: '${rows.length}'),
                StatCard(label: 'Pedidos', value: fmtQty(orders)),
                StatCard(label: 'Valor gasto', value: brl(spent)),
                StatCard(label: 'Pedidos cancelados', value: fmtQty(cancelled)),
              ],
            ),
          ),
        Expanded(
          child: CrudList<Map<String, dynamic>>(
            value: value,
            onRefresh: () async => ref.invalidate(customerRankingReportProvider(_range)),
            isThreeLine: true,
            titleOf: (r) => asString(r, 'customer_name'),
            subtitleOf: (r) =>
                'Pedidos ${fmtQty(asDouble(r, 'order_count'))} · Total ${brl(asDouble(r, 'total_amount'))} · Ticket médio ${brl(asDouble(r, 'average_ticket'))}\n'
                'Cancelados: ${fmtQty(asDouble(r, 'cancelled_count'))}',
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------- Previsão

class ForecastReportPage extends ConsumerStatefulWidget {
  const ForecastReportPage({super.key});

  @override
  ConsumerState<ForecastReportPage> createState() => _ForecastReportPageState();
}

class _ForecastReportPageState extends ConsumerState<ForecastReportPage> {
  final _coverage = TextEditingController(text: '4');
  final _safety = TextEditingController(text: '10');
  final _lookback = TextEditingController(text: '8');
  ({int coverageWeeks, double safetyPercent, int lookbackWeeks}) _params =
      (coverageWeeks: 4, safetyPercent: 10, lookbackWeeks: 8);

  @override
  void dispose() {
    _coverage.dispose();
    _safety.dispose();
    _lookback.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ParamsCard(
          fields: [
            NumParam(label: 'Cobertura (sem.)', controller: _coverage),
            NumParam(label: 'Segurança (%)', controller: _safety, decimal: true),
            NumParam(label: 'Histórico (sem.)', controller: _lookback),
          ],
          actions: [
            FilledButton(
              onPressed: () => setState(() {
                _params = (
                  coverageWeeks: (int.tryParse(_coverage.text.trim()) ?? 4).clamp(1, 1000),
                  safetyPercent: parseNum(_safety.text, 10).clamp(0, double.infinity).toDouble(),
                  lookbackWeeks: (int.tryParse(_lookback.text.trim()) ?? 8).clamp(1, 1000),
                );
              }),
              child: const Text('Atualizar'),
            ),
          ],
        ),
        Expanded(
          child: CrudList<Map<String, dynamic>>(
            value: ref.watch(forecastReportProvider(_params)),
            onRefresh: () async => ref.invalidate(forecastReportProvider(_params)),
            isThreeLine: true,
            titleOf: (r) => '${asString(r, 'sku')} — ${asString(r, 'product_name')}',
            subtitleOf: (r) {
              final u = asString(r, 'uom');
              return 'Previsão ${fmtQty(asDouble(r, 'forecast_qty'))}/sem · Estoque ${fmtQty(asDouble(r, 'on_hand_qty'))} · Em compra ${fmtQty(asDouble(r, 'open_po_qty'))}\n'
                  'Necessário: ${fmtQty(asDouble(r, 'needed_qty'))} $u';
            },
          ),
        ),
      ],
    );
  }
}
