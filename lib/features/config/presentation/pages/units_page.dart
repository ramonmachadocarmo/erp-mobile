import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/widgets/crud_list.dart';
import '../../../../app/widgets/form_kit.dart';
import '../../domain/entities.dart';
import '../config_providers.dart';

class UnitsPage extends ConsumerWidget {
  const UnitsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final units = ref.watch(unitsProvider);
    return CrudList<Unit>(
      value: units,
      onRefresh: () => ref.read(unitsProvider.notifier).reload(),
      titleOf: (u) => u.name,
      subtitleOf: (u) => '${u.code}  ${u.symbol}',
      onCreate: () => pushForm(context, const _UnitForm()),
      onEdit: (u) => pushForm(context, _UnitForm(unit: u)),
    );
  }
}

class _UnitForm extends ConsumerStatefulWidget {
  const _UnitForm({this.unit});

  final Unit? unit;

  @override
  ConsumerState<_UnitForm> createState() => _UnitFormState();
}

class _UnitFormState extends ConsumerState<_UnitForm> {
  final _form = GlobalKey<FormState>();
  late final _code = TextEditingController(text: widget.unit?.code ?? '');
  late final _name = TextEditingController(text: widget.unit?.name ?? '');
  late final _symbol = TextEditingController(text: widget.unit?.symbol ?? '');
  var _saving = false;

  @override
  void dispose() {
    _code.dispose();
    _name.dispose();
    _symbol.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _form,
      child: FormScaffold(
        title: widget.unit == null ? 'Nova unidade' : 'Editar unidade',
        saving: _saving,
        onSave: _save,
        child: Column(
          children: [
            // Em branco na criação, o backend atribui um código sequencial (pkg/codes.Assign) —
            // mesma regra do CodeInput no web (CodeInput.tsx): só fica obrigatório ao editar.
            ErpField('Código', _code, required: widget.unit != null),
            ErpField('Nome', _name, required: true),
            ErpField('Símbolo', _symbol),
          ],
        ),
      ),
    );
  }

  Future<void> _save() async {
    if (!(_form.currentState?.validate() ?? false)) return;
    setState(() => _saving = true);
    try {
      await ref.read(unitsProvider.notifier).save(
            Unit(
              id: widget.unit?.id ?? '',
              code: _code.text.trim(),
              name: _name.text.trim(),
              symbol: _symbol.text.trim(),
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
