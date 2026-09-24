import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme.dart';
import '../../../../app/widgets/crud_list.dart';
import '../../../../app/widgets/form_kit.dart';
import '../../domain/entities.dart';
import '../config_providers.dart';

class PaymentPage extends ConsumerWidget {
  const PaymentPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SizedBox.expand(
      child: DefaultTabController(
        length: 2,
        child: Column(
          children: [
            const TabBar(
              tabs: [
                Tab(text: 'Formas'),
                Tab(text: 'Condições'),
              ],
            ),
            const Expanded(
              child: TabBarView(
                children: [_MethodsTab(), _TermsTab()],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MethodsTab extends ConsumerWidget {
  const _MethodsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final methods = ref.watch(methodsProvider);
    return CrudList<PaymentMethod>(
      value: methods,
      onRefresh: () => ref.read(methodsProvider.notifier).reload(),
      titleOf: (m) => m.name,
      subtitleOf: (m) => m.code,
      onCreate: () => pushForm(context, const _MethodForm()),
      onEdit: (m) => pushForm(context, _MethodForm(method: m)),
    );
  }
}

class _TermsTab extends ConsumerWidget {
  const _TermsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final terms = ref.watch(termsProvider);
    return CrudList<PaymentTerm>(
      value: terms,
      onRefresh: () => ref.read(termsProvider.notifier).reload(),
      titleOf: (t) => t.name,
      subtitleOf: (t) => '${t.code} · ${t.summary}',
      onCreate: () => pushForm(context, const _TermForm()),
      onEdit: (t) => pushForm(context, _TermForm(term: t)),
    );
  }
}

class _MethodForm extends ConsumerStatefulWidget {
  const _MethodForm({this.method});

  final PaymentMethod? method;

  @override
  ConsumerState<_MethodForm> createState() => _MethodFormState();
}

class _MethodFormState extends ConsumerState<_MethodForm> {
  final _form = GlobalKey<FormState>();
  late final _code = TextEditingController(text: widget.method?.code ?? '');
  late final _name = TextEditingController(text: widget.method?.name ?? '');
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
        title: widget.method == null ? 'Nova forma' : 'Editar forma',
        saving: _saving,
        onSave: _save,
        child: Column(
          children: [
            // Em branco na criação, o backend atribui um código sequencial — só fica
            // obrigatório ao editar (mesma regra do CodeInput no web).
            ErpField('Código', _code, required: widget.method != null),
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
      await ref.read(methodsProvider.notifier).save(
            PaymentMethod(
              id: widget.method?.id ?? '',
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

class _TermForm extends ConsumerStatefulWidget {
  const _TermForm({this.term});

  final PaymentTerm? term;

  @override
  ConsumerState<_TermForm> createState() => _TermFormState();
}

class _TermFormState extends ConsumerState<_TermForm> {
  final _form = GlobalKey<FormState>();
  late final _code = TextEditingController(text: widget.term?.code ?? '');
  late final _name = TextEditingController(text: widget.term?.name ?? '');
  late final _installments = List<Installment>.from(widget.term?.installments ?? const []);
  final _days = TextEditingController();
  final _percent = TextEditingController();
  var _draftKey = 0;
  var _saving = false;

  @override
  void dispose() {
    _code.dispose();
    _name.dispose();
    _days.dispose();
    _percent.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _form,
      child: FormScaffold(
        title: widget.term == null ? 'Nova condição' : 'Editar condição',
        saving: _saving,
        onSave: _save,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Em branco na criação, o backend atribui um código sequencial — só fica
            // obrigatório ao editar (mesma regra do CodeInput no web).
            ErpField('Código', _code, required: widget.term != null),
            ErpField('Nome', _name, required: true),
            const Text('Parcelas (soma = 100%)', style: TextStyle(color: erpMuted)),
            const SizedBox(height: 8),
            KeyedSubtree(
              key: ValueKey(_draftKey),
              child: Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _days,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Dias'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextFormField(
                      controller: _percent,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: '%'),
                    ),
                  ),
                ],
              ),
            ),
            LineItemsBar(
              count: _installments.length,
              addLabel: 'Adicionar parcela',
              onAdd: _add,
              onOpen: () => pushForm(
                context,
                LineItemsPage<Installment>(
                  title: 'Parcelas',
                  items: _installments,
                  titleOf: (i) => '${i.days} dias',
                  subtitleOf: (i) => '${i.percent}%',
                  onDelete: (i) => setState(() => _installments.removeAt(i)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _add() {
    final days = int.tryParse(_days.text.trim()) ?? 0;
    final percent = parseNum(_percent.text);
    if (_days.text.trim().isEmpty && _percent.text.trim().isEmpty) return;
    setState(() {
      _installments.add(Installment(days: days, percent: percent));
      _days.clear();
      _percent.clear();
      _draftKey++;
    });
  }

  Future<void> _save() async {
    if (!(_form.currentState?.validate() ?? false)) return;
    setState(() => _saving = true);
    try {
      await ref.read(termsProvider.notifier).save(
            PaymentTerm(
              id: widget.term?.id ?? '',
              code: _code.text.trim(),
              name: _name.text.trim(),
              installments: _installments,
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
