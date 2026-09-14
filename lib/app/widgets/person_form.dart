import 'package:flutter/material.dart';

import '../../features/config/domain/entities.dart';
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
            ErpField(_kind == 'PJ' ? 'CNPJ' : 'CPF', _document, required: true),
            ErpField('Nome', _name, required: true),
            ErpField('Telefone', _phone, required: true, keyboard: TextInputType.phone),
            if (_kind == 'PJ') ...[
              ErpField('Razão social', _company),
              ErpField('Responsável', _responsible),
            ],
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
          addresses: widget.person?.addresses ?? const [],
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
