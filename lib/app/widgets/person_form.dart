import 'package:flutter/material.dart';

import '../../features/config/domain/entities.dart';
import '../theme.dart';
import 'address_form.dart';
import 'form_kit.dart';

class PersonForm extends StatefulWidget {
  const PersonForm({
    super.key,
    required this.title,
    this.person,
    required this.onSave,
  });

  final String title;
  final Person? person;
  final Future<void> Function(Person person) onSave;

  @override
  State<PersonForm> createState() => _PersonFormState();
}

class _PersonFormState extends State<PersonForm> {
  final _form = GlobalKey<FormState>();
  late var _kind = widget.person?.kind ?? 'PF';
  late final _document = TextEditingController(text: widget.person?.document ?? '');
  late final _name = TextEditingController(text: widget.person?.name ?? '');
  late final _phone = TextEditingController(text: widget.person?.phone ?? '');
  late final _company = TextEditingController(text: widget.person?.companyName ?? '');
  late final _responsible = TextEditingController(text: widget.person?.responsibleName ?? '');
  late var _addresses = List<Address>.from(widget.person?.addresses ?? const []);
  var _saving = false;

  @override
  void dispose() {
    _document.dispose();
    _name.dispose();
    _phone.dispose();
    _company.dispose();
    _responsible.dispose();
    super.dispose();
  }

  Future<void> _addAddress() async {
    final a = await showAddressDialog(context);
    if (a == null || !mounted) return;
    setState(() => _addresses = [..._addresses, a]);
  }

  Future<void> _editAddress(int i) async {
    final a = await showAddressDialog(context, initial: _addresses[i]);
    if (a == null || !mounted) return;
    setState(() => _addresses = [for (var j = 0; j < _addresses.length; j++) j == i ? a : _addresses[j]]);
  }

  void _removeAddress(int i) {
    setState(() => _addresses = [for (var j = 0; j < _addresses.length; j++) if (j != i) _addresses[j]]);
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _form,
      child: FormScaffold(
        title: widget.title,
        saving: _saving,
        onSave: _save,
        child: Column(
          children: [
            ErpDropdown<String>(
              label: 'Tipo',
              value: _kind,
              items: const [
                DropdownMenuItem(value: 'PF', child: Text('Pessoa física')),
                DropdownMenuItem(value: 'PJ', child: Text('Pessoa jurídica')),
              ],
              onChanged: (v) => setState(() => _kind = v ?? 'PF'),
            ),
            // Opcional, igual ao web (PersonForm.tsx) — nem todo cliente/fornecedor de balcão
            // tem o documento à mão na hora do cadastro.
            ErpField(_kind == 'PJ' ? 'CNPJ' : 'CPF', _document),
            ErpField('Nome', _name, required: true),
            ErpField('Telefone', _phone, required: true, keyboard: TextInputType.phone),
            if (_kind == 'PJ') ...[
              ErpField('Razão social', _company),
              ErpField('Responsável', _responsible),
            ],
            const SizedBox(height: 8),
            Row(
              children: [
                const Expanded(
                  child: Text('Endereços', style: TextStyle(fontWeight: FontWeight.w700)),
                ),
                TextButton.icon(
                  onPressed: _addAddress,
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Adicionar'),
                ),
              ],
            ),
            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Opcional. Alias identifica o local (Casa, Fazenda, Entrega).',
                style: TextStyle(color: erpMuted, fontSize: 12),
              ),
            ),
            if (_addresses.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Text('Nenhum endereço cadastrado.', style: TextStyle(color: erpMuted)),
              )
            else
              for (var i = 0; i < _addresses.length; i++) _AddressTile(
                address: _addresses[i],
                onEdit: () => _editAddress(i),
                onRemove: () => _removeAddress(i),
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
      await widget.onSave(
        Person(
          id: widget.person?.id ?? '',
          kind: _kind,
          document: _document.text.trim(),
          name: _name.text.trim(),
          phone: _phone.text.trim(),
          companyName: _company.text.trim(),
          responsibleName: _responsible.text.trim(),
          // Sem campo pra editar isso no app ainda — preserva o que já estava salvo em vez de
          // apagar na primeira edição feita pelo mobile.
          birthDate: widget.person?.birthDate ?? '',
          gender: widget.person?.gender ?? '',
          addresses: _addresses,
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

class _AddressTile extends StatelessWidget {
  const _AddressTile({required this.address, required this.onEdit, required this.onRemove});

  final Address address;
  final VoidCallback onEdit;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final line = [address.street, address.number].where((s) => s.isNotEmpty).join(', ');
    final cityUf = address.city.isEmpty ? '' : '${address.city}${address.state.isEmpty ? '' : '/${address.state}'}';
    final subtitle = [line, cityUf].where((s) => s.isNotEmpty).join(' · ');
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(address.alias.isNotEmpty ? address.alias : (address.street.isNotEmpty ? address.street : 'Endereço')),
      subtitle: subtitle.isEmpty ? null : Text(subtitle, style: const TextStyle(color: erpMuted)),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(icon: const Icon(Icons.edit_outlined), tooltip: 'Editar', onPressed: onEdit),
          IconButton(
            icon: const Icon(Icons.delete_outline, color: erpDanger),
            tooltip: 'Remover',
            onPressed: onRemove,
          ),
        ],
      ),
    );
  }
}
