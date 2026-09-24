import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/widgets/crud_list.dart';
import '../../../../app/widgets/form_kit.dart';
import '../../domain/entities.dart';
import '../stock_providers.dart';

class WarehousesPage extends ConsumerWidget {
  const WarehousesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = ref.watch(warehousesProvider);
    final bals = ref.watch(balancesProvider).valueOrNull ?? [];
    return CrudList<Warehouse>(
      value: items,
      onRefresh: () async {
        await Future.wait([
          ref.read(warehousesProvider.notifier).reload(),
          ref.read(balancesProvider.notifier).reload(),
        ]);
      },
      titleOf: (w) => w.name,
      subtitleOf: (w) {
        final reserved = bals
            .where((b) => b.warehouseId == w.id)
            .fold(0.0, (n, b) => n + b.reserved);
        return '${w.code} · res. $reserved';
      },
      onCreate: () => pushForm(context, const _WarehouseForm()),
      onEdit: (w) => pushForm(context, _WarehouseForm(warehouse: w)),
    );
  }
}

class _WarehouseForm extends ConsumerStatefulWidget {
  const _WarehouseForm({this.warehouse});

  final Warehouse? warehouse;

  @override
  ConsumerState<_WarehouseForm> createState() => _WarehouseFormState();
}

class _WarehouseFormState extends ConsumerState<_WarehouseForm> {
  final _form = GlobalKey<FormState>();
  late final _code = TextEditingController(text: widget.warehouse?.code ?? '');
  late final _name = TextEditingController(text: widget.warehouse?.name ?? '');
  var _saving = false;

  @override
  void dispose() {
    _code.dispose();
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _form,
      child: FormScaffold(
        title: widget.warehouse == null ? 'Novo almoxarifado' : 'Editar almoxarifado',
        saving: _saving,
        onSave: _save,
        child: Column(
          children: [
            // Em branco na criação, o backend atribui um código sequencial — só fica
            // obrigatório ao editar (mesma regra do CodeInput no web).
            ErpField('Código', _code, required: widget.warehouse != null),
            ErpField('Nome', _name, required: true),
          ],
        ),
      ),
    );
  }

  Future<void> _save() async {
    if (!(_form.currentState?.validate() ?? false)) return;
    setState(() => _saving = true);
    try {
      await ref.read(warehousesProvider.notifier).save(
            Warehouse(
              id: widget.warehouse?.id ?? '',
              code: _code.text.trim(),
              name: _name.text.trim(),
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
