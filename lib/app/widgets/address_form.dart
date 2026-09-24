import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/config/domain/entities.dart';
import '../../features/config/presentation/config_providers.dart';
import 'form_kit.dart';

/// Diálogo de endereço (criar/editar), com busca de CEP nos dois sentidos — CEP -> endereço e
/// endereço -> CEP (mesma dupla busca do `CepPicker`/`searchCepByAddress` do web). Único lugar
/// que implementa isso: usado tanto no cadastro de cliente/fornecedor (`PersonForm`) quanto no
/// atalho de "novo endereço" dentro do pedido de venda — evita duas versões da mesma lógica
/// divergindo com o tempo.
///
/// Devolve o endereço editado, ou `null` se cancelado.
Future<Address?> showAddressDialog(BuildContext context, {Address? initial}) {
  return showDialog<Address>(
    context: context,
    builder: (_) => AddressFormDialog(initial: initial),
  );
}

class AddressFormDialog extends ConsumerStatefulWidget {
  const AddressFormDialog({super.key, this.initial});

  final Address? initial;

  @override
  ConsumerState<AddressFormDialog> createState() => _AddressFormDialogState();
}

class _AddressFormDialogState extends ConsumerState<AddressFormDialog> {
  final _numberFocus = FocusNode();
  var _busy = ''; // '', 'cep' (CEP -> endereço) ou 'search' (endereço -> CEP)

  late final _alias = TextEditingController(text: widget.initial?.alias ?? '');
  late final _zip = TextEditingController(text: widget.initial?.zip ?? '');
  late final _street = TextEditingController(text: widget.initial?.street ?? '');
  late final _number = TextEditingController(text: widget.initial?.number ?? '');
  late final _complement = TextEditingController(text: widget.initial?.complement ?? '');
  late final _district = TextEditingController(text: widget.initial?.district ?? '');
  late final _city = TextEditingController(text: widget.initial?.city ?? '');
  late final _state = TextEditingController(text: widget.initial?.state ?? '');

  @override
  void dispose() {
    _alias.dispose();
    _zip.dispose();
    _street.dispose();
    _number.dispose();
    _complement.dispose();
    _district.dispose();
    _city.dispose();
    _state.dispose();
    _numberFocus.dispose();
    super.dispose();
  }

  Future<void> _searchByCep() async {
    if (_busy.isNotEmpty) return;
    final digits = _zip.text.replaceAll(RegExp(r'\D'), '');
    if (digits.length != 8) {
      showError(context, 'Informe um CEP com 8 dígitos');
      return;
    }
    setState(() => _busy = 'cep');
    final result = await ref.read(configRepositoryProvider).lookupCep(digits);
    if (!mounted) return;
    setState(() => _busy = '');
    result.when(
      ok: (a) {
        // Mantém o que o usuário já digitou quando a busca não traz valor.
        String pick(String found, TextEditingController c) => found.isNotEmpty ? found : c.text;
        _zip.text = pick(a.zip, _zip);
        _street.text = pick(a.street, _street);
        _complement.text = pick(a.complement, _complement);
        _district.text = pick(a.district, _district);
        _city.text = pick(a.city, _city);
        _state.text = pick(a.state, _state);
        _numberFocus.requestFocus();
      },
      err: (f) => showError(context, f.message),
    );
  }

  /// Inverso: logradouro + cidade + UF -> CEP (bairro só refina). Com 1 resultado, aplica
  /// direto; com vários, deixa escolher numa lista.
  Future<void> _searchByAddress() async {
    if (_busy.isNotEmpty) return;
    final state = _state.text.trim();
    final city = _city.text.trim();
    final street = _street.text.trim();
    if (state.length != 2 || city.length < 3 || street.length < 3) {
      showError(context, 'Pra buscar o CEP, preencha logradouro (3+ letras), cidade e UF');
      return;
    }
    setState(() => _busy = 'search');
    final result = await ref
        .read(configRepositoryProvider)
        .searchCep(state: state, city: city, street: street, district: _district.text.trim());
    if (!mounted) return;
    setState(() => _busy = '');
    await result.when(
      ok: (list) async {
        if (list.isEmpty) {
          showError(context, 'Nenhum CEP encontrado para esse endereço');
          return;
        }
        final picked = list.length == 1 ? list.first : await _pickResult(list);
        if (picked == null || !mounted) return;
        String keep(String found, TextEditingController c) => found.isNotEmpty ? found : c.text;
        setState(() {
          _zip.text = picked.zip;
          _street.text = keep(picked.street, _street);
          _complement.text = keep(picked.complement, _complement);
          _district.text = keep(picked.district, _district);
          _city.text = keep(picked.city, _city);
          _state.text = keep(picked.state, _state);
        });
      },
      err: (f) async => showError(context, f.message),
    );
  }

  Future<Address?> _pickResult(List<Address> list) {
    return showModalBottomSheet<Address>(
      context: context,
      showDragHandle: true,
      builder: (_) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: Text('Selecione o CEP', style: TextStyle(fontWeight: FontWeight.w700)),
            ),
            for (final a in list)
              ListTile(
                title: Text(a.zip),
                subtitle: Text(
                  '${[a.street, a.complement].where((s) => s.isNotEmpty).join(' — ')}\n'
                  '${a.district.isEmpty ? '—' : a.district} · ${a.city}/${a.state}',
                ),
                isThreeLine: true,
                onTap: () => Navigator.pop(context, a),
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.initial == null ? 'Novo endereço' : 'Editar endereço'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _alias,
              decoration: const InputDecoration(labelText: 'Alias'),
              autofocus: true,
            ),
            TextField(
              controller: _zip,
              keyboardType: TextInputType.number,
              textInputAction: TextInputAction.search,
              onSubmitted: (_) => _searchByCep(),
              onChanged: (v) {
                if (v.replaceAll(RegExp(r'\D'), '').length == 8) _searchByCep();
              },
              decoration: InputDecoration(
                labelText: 'CEP',
                suffixIcon: _busy == 'cep'
                    ? const Padding(
                        padding: EdgeInsets.all(12),
                        child: SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                    : IconButton(
                        icon: const Icon(Icons.search),
                        tooltip: 'Buscar endereço',
                        onPressed: _searchByCep,
                      ),
              ),
            ),
            TextField(controller: _street, decoration: const InputDecoration(labelText: 'Logradouro')),
            TextField(
              controller: _number,
              focusNode: _numberFocus,
              decoration: const InputDecoration(labelText: 'Número'),
            ),
            TextField(controller: _complement, decoration: const InputDecoration(labelText: 'Complemento')),
            TextField(controller: _district, decoration: const InputDecoration(labelText: 'Bairro')),
            TextField(controller: _city, decoration: const InputDecoration(labelText: 'Cidade')),
            TextField(
              controller: _state,
              decoration: const InputDecoration(labelText: 'UF'),
              textCapitalization: TextCapitalization.characters,
            ),
            const SizedBox(height: 4),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: _busy.isNotEmpty ? null : _searchByAddress,
                icon: _busy == 'search'
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.pin_drop_outlined, size: 18),
                label: const Text('Buscar CEP pelo endereço'),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
        TextButton(
          onPressed: () {
            final a = Address(
              id: widget.initial?.id ?? '',
              alias: _alias.text.trim(),
              zip: _zip.text.trim(),
              street: _street.text.trim(),
              number: _number.text.trim(),
              complement: _complement.text.trim(),
              district: _district.text.trim(),
              city: _city.text.trim(),
              state: _state.text.trim().toUpperCase(),
            );
            if (a.alias.isEmpty && a.street.isEmpty) return;
            Navigator.pop(context, a);
          },
          child: const Text('Salvar'),
        ),
      ],
    );
  }
}
