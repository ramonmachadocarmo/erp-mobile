import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme.dart';
import '../../../../app/widgets/form_kit.dart';
import '../../../stock/presentation/stock_providers.dart';
import '../config_providers.dart';

class RulesPage extends ConsumerWidget {
  const RulesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final required = ref.watch(quoteRequiredProvider);
    final warehouse = ref.watch(defaultWarehouseProvider);
    final warehouses = ref.watch(warehousesProvider).valueOrNull ?? [];
    return required.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('$e', style: const TextStyle(color: erpDanger))),
      data: (value) => ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SwitchListTile(
            title: const Text('Exigir orçamento antes do pedido de compra'),
            subtitle: const Text(
              'Se ativo, o pedido só é gerado a partir de um orçamento.',
              style: TextStyle(color: erpMuted),
            ),
            value: value,
            onChanged: (v) async {
              try {
                await ref.read(quoteRequiredProvider.notifier).setValue(v);
              } catch (e) {
                if (context.mounted) showError(context, '$e');
              }
            },
          ),
          const SizedBox(height: 16),
          Text('Almoxarifado padrão', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          ErpDropdown<String>(
            label: 'Almoxarifado',
            value: () {
              final id = warehouse.valueOrNull ?? '';
              if (id.isEmpty) return null;
              return warehouses.any((w) => w.id == id) ? id : null;
            }(),
            items: [
              const DropdownMenuItem(value: '', child: Text('Nenhum')),
              ...warehouses.map((w) => DropdownMenuItem(value: w.id, child: Text('${w.code} — ${w.name}'))),
            ],
            onChanged: (v) async {
              try {
                await ref.read(defaultWarehouseProvider.notifier).setValue(v ?? '');
              } catch (e) {
                if (context.mounted) showError(context, '$e');
              }
            },
          ),
          const Text(
            'Usado no recebimento de compra e na separação. Se vazio, informe na confirmação.',
            style: TextStyle(color: erpMuted),
          ),
        ],
      ),
    );
  }
}
