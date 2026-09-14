import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/maps.dart';
import '../../../../app/theme.dart';
import '../../../../app/widgets/form_kit.dart';
import '../../../../app/widgets/status_chip.dart';
import '../../../config/presentation/config_providers.dart';
import '../../domain/entities.dart';
import '../sales_providers.dart';
import 'delivery_page.dart';

Future<void> _open(String url) async {
  await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
}

String _km(double m) => '${(m / 1000).toStringAsFixed(1)} km';
String _mins(double s) => '${(s / 60).round()} min';

String _mapsDir(DeliveryPlan p, [List<DeliveryStop>? stops]) => mapsDirUrl(
      origin: Geo(p.centerLat, p.centerLng),
      stops: (stops ?? p.stops).map((s) => Geo(s.lat, s.lng)).toList(),
    );

String _mapsStop(double lat, double lng) => mapsStopUrl(lat, lng);

String _waze(double lat, double lng) => wazeNavUrl(lat, lng);

class RoutesPage extends ConsumerStatefulWidget {
  const RoutesPage({super.key});

  @override
  ConsumerState<RoutesPage> createState() => _RoutesPageState();
}

class _RoutesPageState extends ConsumerState<RoutesPage> {
  String? centerId;
  final vehicleIds = <String>{};
  final selected = <String>{};
  PlanResult? result;
  DeliveryPlan? active;
  int choice = 0;
  bool busy = false;
  bool primed = false;

  Future<void> _reload() async {
    await Future.wait([
      ref.read(deliveryPlansProvider.notifier).reload(),
      ref.read(deliveryCandidatesProvider.notifier).reload(),
      ref.read(customersProvider.notifier).reload(),
    ]);
    ref.invalidate(centersProvider);
    ref.invalidate(vehiclesProvider);
  }

  Future<void> _build() async {
    final ids = selected.toList();
    if (centerId == null || vehicleIds.isEmpty || ids.isEmpty) {
      showError(context, 'Selecione CD, veículos e entregas');
      return;
    }
    setState(() => busy = true);
    try {
      final out = await ref.read(deliveryPlansProvider.notifier).createPlans(
            centerId: centerId!,
            vehicleIds: vehicleIds.toList(),
            orderIds: ids,
          );
      await ref.read(deliveryCandidatesProvider.notifier).reload();
      if (!mounted) return;
      setState(() {
        result = out;
        active = out.plans.isEmpty ? null : out.plans.first;
        choice = 0;
      });
    } catch (e) {
      if (mounted) showError(context, '$e');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _confirm() async {
    final p = active;
    if (p == null) return;
    setState(() => busy = true);
    try {
      RouteOption? opt;
      if (p.options.isNotEmpty) {
        opt = p.options[choice.clamp(0, p.options.length - 1)];
      }
      final saved = await ref.read(deliveryPlansProvider.notifier).confirm(p.id, option: opt);
      ref.invalidate(deliveryPlanProvider(saved.id));
      if (!mounted) return;
      context.push('/logistica/rotas/${saved.id}');
    } catch (e) {
      if (mounted) showError(context, '$e');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cands = ref.watch(deliveryCandidatesProvider).valueOrNull ?? [];
    final centers = ref.watch(centersProvider).valueOrNull ?? [];
    final vehicles = ref.watch(vehiclesProvider).valueOrNull ?? [];
    final plans = ref.watch(deliveryPlansProvider).valueOrNull ?? [];
    final people = {
      for (final c in ref.watch(customersProvider).valueOrNull ?? []) c.id: c.displayName,
    };
    if (!primed && (centers.isNotEmpty || vehicles.isNotEmpty)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || primed) return;
        setState(() {
          primed = true;
          centerId ??= centers.isEmpty ? null : centers.first.id;
          if (vehicleIds.isEmpty && vehicles.isNotEmpty) vehicleIds.add(vehicles.first.id);
        });
      });
    }
    final shown = result?.plans.isNotEmpty == true ? result!.plans : [if (active != null) active!];
    final opt = active != null && active!.options.isNotEmpty
        ? active!.options[choice.clamp(0, active!.options.length - 1)]
        : null;
    final viewStops = opt?.stops ?? active?.stops ?? const <DeliveryStop>[];
    final viewDist = opt?.distanceM ?? active?.distanceM ?? 0;
    final viewDur = opt?.durationS ?? active?.durationS ?? 0;
    final stopByOrder = {for (final s in viewStops) s.salesOrderId: s};
    final allSelected = cands.isNotEmpty && cands.every((c) => selected.contains(c.id));
    return Scaffold(
      body: Stack(
        children: [
          RefreshIndicator(
            onRefresh: _reload,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              children: [
                ErpDropdown<String>(
                  label: 'Centro de distribuição',
                  value: centerId != null && centers.any((c) => c.id == centerId) ? centerId : null,
                  items: [
                    for (final c in centers)
                      DropdownMenuItem(value: c.id, child: Text('${c.code} ${c.name}'.trim())),
                  ],
                  onChanged: (v) => setState(() => centerId = v),
                ),
                const SizedBox(height: 12),
                const Text('Veículos', style: TextStyle(color: erpMuted)),
                for (final v in vehicles)
                  CheckboxListTile(
                    dense: true,
                    value: vehicleIds.contains(v.id),
                    onChanged: (on) => setState(() {
                      if (on == true) {
                        vehicleIds.add(v.id);
                      } else {
                        vehicleIds.remove(v.id);
                      }
                    }),
                    title: Text('${v.code} ${v.name}'.trim()),
                    subtitle: Text('${v.capacityKg} kg · ${v.capacityM3} m³', style: const TextStyle(color: erpMuted)),
                  ),
                const Padding(
                  padding: EdgeInsets.only(bottom: 8),
                  child: Text(
                    'Marque N veículos para separar em N rotas. Desmarque entregas e monte de novo.',
                    style: TextStyle(color: erpMuted, fontSize: 13),
                  ),
                ),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    OutlinedButton(
                      onPressed: cands.isEmpty
                          ? null
                          : () => setState(() {
                                if (allSelected) {
                                  selected.clear();
                                } else {
                                  selected
                                    ..clear()
                                    ..addAll(cands.map((c) => c.id));
                                }
                              }),
                      child: Text(allSelected ? 'Limpar seleção' : 'Selecionar todos'),
                    ),
                    FilledButton(
                      onPressed: busy ? null : _build,
                      child: Text(result?.plans.isNotEmpty == true ? 'Remontar rotas' : 'Montar rotas'),
                    ),
                  ],
                ),
                if (result?.skipped.isNotEmpty == true)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Text(
                      'Fora da rota: ${result!.skipped.map((s) => '${s.orderId.length >= 8 ? s.orderId.substring(0, 8) : s.orderId} (${s.reason})').join(' · ')}',
                      style: const TextStyle(color: erpDanger),
                    ),
                  ),
                if (shown.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  for (final p in shown)
                    Card(
                      color: erpPanel,
                      child: ListTile(
                        selected: active?.id == p.id,
                        title: Text('${p.vehicleCode} ${p.vehicleName}'.trim()),
                        subtitle: Text(
                          '${p.stops.length} paradas · ${_km(p.distanceM)} · ${_mins(p.durationS)} · ${p.occupancyPct.toStringAsFixed(0)}%',
                          style: const TextStyle(color: erpMuted),
                        ),
                        onTap: () => setState(() {
                          active = p;
                          choice = 0;
                        }),
                      ),
                    ),
                ],
                if (active != null) ...[
                  const SizedBox(height: 8),
                  if (active!.options.length > 1)
                    Wrap(
                      spacing: 8,
                      children: [
                        for (var i = 0; i < active!.options.length; i++)
                          ChoiceChip(
                            label: Text(
                              '${active!.options[i].label} · ${_km(active!.options[i].distanceM)} · ${_mins(active!.options[i].durationS)}',
                            ),
                            selected: choice == i,
                            onSelected: (_) => setState(() => choice = i),
                          ),
                      ],
                    ),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Text(
                      'Total ${viewStops.length} paradas · ${_km(viewDist)} · ${_mins(viewDur)}',
                      style: const TextStyle(color: erpMuted),
                    ),
                  ),
                  if (active!.status == 'PLANNED' || active!.status.isEmpty)
                    FilledButton(onPressed: busy ? null : _confirm, child: const Text('Confirmar rota'))
                  else
                    FilledButton.tonal(
                      onPressed: () => context.push('/logistica/rotas/${active!.id}'),
                      child: const Text('Relatório'),
                    ),
                ],
                const SizedBox(height: 16),
                if (cands.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Center(child: Text('Nenhuma entrega separada', style: TextStyle(color: erpMuted))),
                  )
                else
                  for (final c in cands)
                    CheckboxListTile(
                      value: selected.contains(c.id),
                      onChanged: (on) => setState(() {
                        if (on == true) {
                          selected.add(c.id);
                        } else {
                          selected.remove(c.id);
                        }
                      }),
                      title: Text(people[c.customerId] ?? c.customerId),
                      subtitle: Text(
                        [
                          c.address.label,
                          if (stopByOrder[c.id] != null)
                            '#${stopByOrder[c.id]!.seq} · ${_km(stopByOrder[c.id]!.distanceM)} · ${_mins(stopByOrder[c.id]!.durationS)}',
                          if (c.planned) 'Na rota',
                          if (!c.hasGeo) 'Sem coordenada',
                        ].join(' · '),
                        style: const TextStyle(color: erpMuted),
                      ),
                    ),
                if (plans.isNotEmpty && result?.plans.isNotEmpty != true) ...[
                  const Padding(
                    padding: EdgeInsets.fromLTRB(0, 16, 0, 8),
                    child: Text('Planos', style: TextStyle(fontWeight: FontWeight.w700)),
                  ),
                  for (final p in plans)
                    ListTile(
                      title: Text('${p.vehicleCode} ${p.vehicleName}'.trim()),
                      subtitle: Text(
                        '${p.centerName} · ${p.stops.length} paradas · ${_km(p.distanceM)}',
                        style: const TextStyle(color: erpMuted),
                      ),
                      trailing: statusChip(p.status),
                      onTap: () {
                        setState(() {
                          active = p;
                          result = null;
                          choice = 0;
                          selected
                            ..clear()
                            ..addAll(p.stops.map((s) => s.salesOrderId));
                        });
                      },
                      onLongPress: () => context.push('/logistica/rotas/${p.id}'),
                    ),
                ],
              ],
            ),
          ),
          if (busy) const ColoredBox(color: Color(0x88000000), child: Center(child: CircularProgressIndicator())),
        ],
      ),
    );
  }
}

class RouteStopsPage extends ConsumerWidget {
  const RouteStopsPage({super.key, required this.planId});

  final String planId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(deliveryPlanProvider(planId));
    final people = {
      for (final c in ref.watch(customersProvider).valueOrNull ?? []) c.id: c,
    };
    final orders = {
      for (final o in ref.watch(salesOrdersProvider).valueOrNull ?? []) o.id: o,
    };
    return async.when(
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, _) => Scaffold(appBar: AppBar(), body: Center(child: Text('$e'))),
      data: (p) {
        final maps = _mapsDir(p);
        final first = p.stops.where((s) => s.lat != 0 && s.lng != 0);
        return Scaffold(
          appBar: AppBar(title: Text('${p.vehicleCode} ${p.vehicleName}'.trim())),
          body: RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(deliveryPlanProvider(planId));
              await ref.read(salesOrdersProvider.notifier).reload();
            },
            child: ListView(
              children: [
                ListTile(
                  title: Text(p.centerName),
                  subtitle: Text(
                    '${_km(p.distanceM)} · ${_mins(p.durationS)} · ${p.occupancyPct.toStringAsFixed(0)}%',
                    style: const TextStyle(color: erpMuted),
                  ),
                  trailing: statusChip(p.status),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      if (maps.isNotEmpty)
                        FilledButton.tonal(onPressed: () => _open(maps), child: const Text('Google Maps')),
                      if (first.isNotEmpty)
                        FilledButton.tonal(
                          onPressed: () => _open(_waze(first.first.lat, first.first.lng)),
                          child: const Text('Waze'),
                        ),
                      if (p.status == 'PLANNED')
                        FilledButton(
                          onPressed: () async {
                            try {
                              await ref.read(deliveryPlansProvider.notifier).confirm(p.id);
                              ref.invalidate(deliveryPlanProvider(planId));
                            } catch (e) {
                              if (context.mounted) showError(context, '$e');
                            }
                          },
                          child: const Text('Confirmar rota'),
                        ),
                    ],
                  ),
                ),
                for (final s in p.stops)
                  ExpansionTile(
                    leading: CircleAvatar(child: Text('${s.seq}')),
                    title: Text(people[s.customerId]?.displayName ?? s.customerId),
                    subtitle: Text(
                      '${s.address.label} · ${_km(s.distanceM)} · ${_mins(s.durationS)}',
                      style: const TextStyle(color: erpMuted),
                    ),
                    trailing: () {
                      final o = orders[s.salesOrderId];
                      if (o == null || o.status.isEmpty) return null;
                      return statusChip(o.status, extra: o.deliveryNote);
                    }(),
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            if (s.lat != 0 && s.lng != 0) ...[
                              OutlinedButton(onPressed: () => _open(_mapsStop(s.lat, s.lng)), child: const Text('Maps')),
                              const SizedBox(height: 8),
                              OutlinedButton(onPressed: () => _open(_waze(s.lat, s.lng)), child: const Text('Waze')),
                              const SizedBox(height: 8),
                            ],
                            if ((orders[s.salesOrderId]?.status ?? 'PICKED') == 'DELIVERED')
                              FilledButton(
                                style: FilledButton.styleFrom(backgroundColor: erpDanger),
                                onPressed: () async {
                                  try {
                                    await ref.read(deliveryPlansProvider.notifier).undoDeliver(s.salesOrderId);
                                    ref.invalidate(deliveryPlanProvider(planId));
                                  } catch (e) {
                                    if (context.mounted) showError(context, '$e');
                                  }
                                },
                                child: const Text('Cancelar entrega'),
                              )
                            else ...[
                              FilledButton(
                                onPressed: () async {
                                  try {
                                    await ref.read(deliveryPlansProvider.notifier).deliver(s.salesOrderId);
                                    ref.invalidate(deliveryPlanProvider(planId));
                                  } catch (e) {
                                    if (context.mounted) showError(context, '$e');
                                  }
                                },
                                child: const Text('Confirmar entrega'),
                              ),
                              const SizedBox(height: 8),
                              OutlinedButton(
                                onPressed: () async {
                                  final note = await askFailNote(context, orders[s.salesOrderId]?.deliveryNote ?? '');
                                  if (note == null || !context.mounted) return;
                                  try {
                                    await ref.read(deliveryPlansProvider.notifier).failDelivery(s.salesOrderId, note);
                                    ref.invalidate(deliveryPlanProvider(planId));
                                  } catch (e) {
                                    if (context.mounted) showError(context, '$e');
                                  }
                                },
                                child: const Text('Não foi possível'),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}
