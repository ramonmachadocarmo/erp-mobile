import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/widgets/crud_list.dart';
import '../../../../app/widgets/list_filters.dart';
import '../../../../app/widgets/form_kit.dart';
import '../../domain/entities.dart';
import '../assets_providers.dart';

class AssetsPage extends ConsumerWidget {
  const AssetsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = ref.watch(assetsProvider);
    return CrudList<FixedAsset>(
      value: items,
      onRefresh: () => ref.read(assetsProvider.notifier).reload(),
      titleOf: (a) => a.tag,
      subtitleOf: (a) => '${a.status} · ${a.location} · ${brl(a.netBookValue)}',
      filters: [
        ListFilter<FixedAsset>.byValue(label: 'Status', valueOf: (a) => a.status),
        ListFilter<FixedAsset>.byValue(label: 'Local', valueOf: (a) => a.location),
      ],
      onCreate: () => pushForm(context, const _AssetForm()),
      onEdit: (a) {
        if (a.status != 'DISPOSED') pushForm(context, _AssetForm(asset: a));
      },
      extraActions: (a) => a.status == 'DISPOSED'
          ? const []
          : const [
              PopupMenuItem(value: 'transfer', child: Text('Transferir')),
              PopupMenuItem(value: 'depreciate', child: Text('Depreciar')),
              PopupMenuItem(value: 'dispose', child: Text('Baixar')),
            ],
      onAction: (a, action) {
        if (action == 'depreciate') ref.read(assetsProvider.notifier).depreciate(a.id);
        if (action == 'transfer') pushForm(context, _TransferForm(asset: a));
        if (action == 'dispose') pushForm(context, _DisposeForm(asset: a));
      },
    );
  }
}

class AssetMovementsPage extends ConsumerWidget {
  const AssetMovementsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = ref.watch(assetMovementsProvider);
    return CrudList<AssetMovement>(
      value: items,
      onRefresh: () => ref.read(assetMovementsProvider.notifier).reload(),
      titleOf: (m) => m.typeLabel,
      subtitleOf: (m) => '${m.toLocation} · ${brl(m.amount)} · ${m.occurredAt}',
      filters: [
        ListFilter<AssetMovement>.byValue(label: 'Tipo', valueOf: (m) => m.typeLabel),
      ],
    );
  }
}

class _AssetForm extends ConsumerStatefulWidget {
  const _AssetForm({this.asset});

  final FixedAsset? asset;

  @override
  ConsumerState<_AssetForm> createState() => _AssetFormState();
}

class _AssetFormState extends ConsumerState<_AssetForm> {
  final _form = GlobalKey<FormState>();
  late var _productId = widget.asset?.productId ?? '';
  late final _tag = TextEditingController(text: widget.asset?.tag ?? '');
  late final _serial = TextEditingController(text: widget.asset?.serialNumber ?? '');
  late final _desc = TextEditingController(text: widget.asset?.description ?? '');
  late final _location = TextEditingController(text: widget.asset?.location ?? '');
  late final _date = TextEditingController(
    text: (widget.asset?.acquisitionDate ?? '').length >= 10
        ? widget.asset!.acquisitionDate.substring(0, 10)
        : DateTime.now().toIso8601String().substring(0, 10),
  );
  late final _cost = TextEditingController(text: '${widget.asset?.acquisitionCost ?? 0}');
  late final _residual = TextEditingController(text: '${widget.asset?.residualValue ?? 0}');
  late final _life = TextEditingController(text: '${widget.asset?.usefulLifeMonths ?? 60}');
  var _saving = false;

  @override
  void dispose() {
    _tag.dispose();
    _serial.dispose();
    _desc.dispose();
    _location.dispose();
    _date.dispose();
    _cost.dispose();
    _residual.dispose();
    _life.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final products = ref.watch(fixedProductsProvider).valueOrNull ?? [];
    return Form(
      key: _form,
      child: FormScaffold(
        title: widget.asset == null ? 'Novo bem' : 'Editar bem',
        saving: _saving,
        onSave: _save,
        child: Column(
          children: [
            ErpDropdown<String>(
              label: 'Produto',
              value: _productId.isEmpty ? null : _productId,
              items: products
                  .map((p) => DropdownMenuItem(value: p.id, child: Text('${p.sku} — ${p.name}')))
                  .toList(),
              onChanged: (v) => setState(() => _productId = v ?? ''),
            ),
            ErpField('Tag', _tag, required: true),
            ErpField('Serial', _serial),
            ErpField('Descrição', _desc),
            ErpField('Local', _location),
            ErpField('Aquisição (YYYY-MM-DD)', _date, required: true),
            ErpField('Custo', _cost, keyboard: TextInputType.number, required: true),
            ErpField('Residual', _residual, keyboard: TextInputType.number),
            ErpField('Vida útil (meses)', _life, keyboard: TextInputType.number, required: true),
          ],
        ),
      ),
    );
  }

  Future<void> _save() async {
    if (!(_form.currentState?.validate() ?? false)) return;
    setState(() => _saving = true);
    try {
      await ref.read(assetsProvider.notifier).save(
            FixedAsset(
              id: widget.asset?.id ?? '',
              productId: _productId,
              tag: _tag.text.trim(),
              serialNumber: _serial.text.trim(),
              description: _desc.text.trim(),
              location: _location.text.trim(),
              acquisitionDate: _date.text.trim(),
              acquisitionCost: double.tryParse(_cost.text.replaceAll(',', '.')) ?? 0,
              residualValue: double.tryParse(_residual.text.replaceAll(',', '.')) ?? 0,
              usefulLifeMonths: int.tryParse(_life.text) ?? 0,
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

class _TransferForm extends ConsumerStatefulWidget {
  const _TransferForm({required this.asset});

  final FixedAsset asset;

  @override
  ConsumerState<_TransferForm> createState() => _TransferFormState();
}

class _TransferFormState extends ConsumerState<_TransferForm> {
  late final _location = TextEditingController(text: widget.asset.location);
  final _notes = TextEditingController();
  var _saving = false;

  @override
  void dispose() {
    _location.dispose();
    _notes.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FormScaffold(
      title: 'Transferir',
      saving: _saving,
      onSave: () async {
        setState(() => _saving = true);
        try {
          await ref.read(assetsProvider.notifier).transfer(
                widget.asset.id,
                _location.text.trim(),
                _notes.text.trim(),
              );
          if (context.mounted) Navigator.of(context).pop();
        } catch (e) {
          if (context.mounted) showError(context, '$e');
        } finally {
          if (mounted) setState(() => _saving = false);
        }
      },
      child: Column(
        children: [
          ErpField('Novo local', _location, required: true),
          ErpField('Notas', _notes),
        ],
      ),
    );
  }
}

class _DisposeForm extends ConsumerStatefulWidget {
  const _DisposeForm({required this.asset});

  final FixedAsset asset;

  @override
  ConsumerState<_DisposeForm> createState() => _DisposeFormState();
}

class _DisposeFormState extends ConsumerState<_DisposeForm> {
  final _notes = TextEditingController();
  var _saving = false;

  @override
  void dispose() {
    _notes.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FormScaffold(
      title: 'Baixar bem',
      saving: _saving,
      onSave: () async {
        setState(() => _saving = true);
        try {
          await ref.read(assetsProvider.notifier).disposeAsset(widget.asset.id, _notes.text.trim());
          if (context.mounted) Navigator.of(context).pop();
        } catch (e) {
          if (context.mounted) showError(context, '$e');
        } finally {
          if (mounted) setState(() => _saving = false);
        }
      },
      child: ErpField('Notas', _notes),
    );
  }
}
