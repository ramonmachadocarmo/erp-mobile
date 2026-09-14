import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/widgets/crud_list.dart';
import '../../../../app/widgets/form_kit.dart';
import '../../domain/entities.dart';
import '../stock_providers.dart';

class CategoriesPage extends ConsumerWidget {
  const CategoriesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tree = ref.watch(categoriesProvider);
    final flat = tree.whenData(flattenCategories);
    return CrudList<Category>(
      value: flat,
      onRefresh: () => ref.read(categoriesProvider.notifier).reload(),
      titleOf: (c) => c.name,
      subtitleOf: (_) => '',
      onCreate: () => pushForm(context, const _CategoryForm()),
      onEdit: (c) => pushForm(context, _CategoryForm(category: c)),
      onDelete: (c) => ref.read(categoriesProvider.notifier).remove(c.id),
    );
  }
}

class _CategoryForm extends ConsumerStatefulWidget {
  const _CategoryForm({this.category});

  final Category? category;

  @override
  ConsumerState<_CategoryForm> createState() => _CategoryFormState();
}

class _CategoryFormState extends ConsumerState<_CategoryForm> {
  final _form = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.category?.name ?? '');
  late var _parentId = widget.category?.parentId ?? '';
  var _saving = false;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cats = flattenCategories(ref.watch(categoriesProvider).valueOrNull ?? []);
    return Form(
      key: _form,
      child: FormScaffold(
        title: widget.category == null ? 'Nova categoria' : 'Editar categoria',
        saving: _saving,
        onSave: _save,
        child: Column(
          children: [
            ErpField('Nome', _name, required: true),
            ErpDropdown<String>(
              label: 'Pai',
              value: _parentId.isEmpty ? null : _parentId,
              items: [
                const DropdownMenuItem(value: '', child: Text('—')),
                ...cats
                    .where((c) => c.id != widget.category?.id)
                    .map((c) => DropdownMenuItem(value: c.id, child: Text(c.name))),
              ],
              onChanged: (v) => setState(() => _parentId = v ?? ''),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _save() async {
    if (!(_form.currentState?.validate() ?? false)) return;
    setState(() => _saving = true);
    try {
      await ref.read(categoriesProvider.notifier).save(
            Category(
              id: widget.category?.id ?? '',
              name: _name.text.trim(),
              parentId: _parentId,
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
