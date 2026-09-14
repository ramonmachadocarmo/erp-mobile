import 'package:flutter/material.dart';

import '../theme.dart';

Future<void> pushForm(BuildContext context, Widget page) {
  return Navigator.of(
    context,
    rootNavigator: true,
  ).push(MaterialPageRoute<void>(builder: (_) => page));
}

class FormScaffold extends StatelessWidget {
  const FormScaffold({
    super.key,
    required this.title,
    required this.child,
    this.onSave,
    this.saving = false,
  });

  final String title;
  final Widget child;
  final VoidCallback? onSave;
  final bool saving;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          child,
          const SizedBox(height: 24),
          FilledButton(
            onPressed: saving ? null : onSave,
            child: Text(saving ? 'Salvando...' : 'Salvar'),
          ),
        ],
      ),
    );
  }
}

class ErpField extends StatelessWidget {
  const ErpField(
    this.label,
    this.controller, {
    super.key,
    this.keyboard,
    this.required = false,
    this.obscure = false,
    this.minLength,
  });

  final String label;
  final TextEditingController controller;
  final TextInputType? keyboard;
  final bool required;
  final bool obscure;
  final int? minLength;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboard,
        obscureText: obscure,
        decoration: InputDecoration(labelText: label),
        validator: (v) {
          final t = v?.trim() ?? '';
          if (required && t.isEmpty) return 'Obrigatório';
          if (minLength != null && t.isNotEmpty && t.length < minLength!) {
            return 'Mínimo $minLength caracteres';
          }
          return null;
        },
      ),
    );
  }
}

class ErpDropdown<T> extends StatelessWidget {
  const ErpDropdown({
    super.key,
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
  });

  final String label;
  final T? value;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: DropdownButtonFormField<T>(
        key: ValueKey('${label}_${value}_${items.map((e) => e.value).join(',')}'),
        initialValue: value,
        isExpanded: true,
        items: items,
        onChanged: items.isEmpty ? null : onChanged,
        hint: Text(items.isEmpty ? 'Nenhum cadastro' : 'Selecione'),
        decoration: InputDecoration(labelText: label),
      ),
    );
  }
}

class QtyPriceFields extends StatelessWidget {
  const QtyPriceFields({super.key, required this.qty, required this.price});

  final TextEditingController qty;
  final TextEditingController price;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: TextFormField(
            controller: qty,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Qtd'),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: TextFormField(
            controller: price,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Preço'),
          ),
        ),
      ],
    );
  }
}

class LineItemsBar extends StatelessWidget {
  const LineItemsBar({
    super.key,
    required this.count,
    required this.onAdd,
    required this.onOpen,
    this.addLabel = 'Adicionar item',
  });

  final int count;
  final VoidCallback onAdd;
  final VoidCallback onOpen;
  final String addLabel;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        children: [
          TextButton(onPressed: onAdd, child: Text(addLabel)),
          const Spacer(),
          if (count > 0)
            Badge(
              label: Text('$count'),
              child: IconButton.filled(
                onPressed: onOpen,
                icon: const Icon(Icons.list),
                style: IconButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.black,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class LineItemsPage<T> extends StatefulWidget {
  const LineItemsPage({
    super.key,
    this.title = 'Itens',
    required this.items,
    required this.titleOf,
    required this.subtitleOf,
    required this.onDelete,
  });

  final String title;
  final List<T> items;
  final String Function(T item) titleOf;
  final String Function(T item) subtitleOf;
  final void Function(int index) onDelete;

  @override
  State<LineItemsPage<T>> createState() => _LineItemsPageState<T>();
}

class _LineItemsPageState<T> extends State<LineItemsPage<T>> {
  @override
  Widget build(BuildContext context) {
    final items = widget.items;
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: items.isEmpty
          ? const Center(
              child: Text('Nenhum item', style: TextStyle(color: erpMuted)),
            )
          : ListView.separated(
              itemCount: items.length,
              separatorBuilder: (_, _) =>
                  const Divider(height: 1, color: erpLine),
              itemBuilder: (context, i) {
                final item = items[i];
                return GestureDetector(
                  onLongPressStart: (d) =>
                      _remove(context, i, d.globalPosition),
                  child: ListTile(
                    title: Text(widget.titleOf(item)),
                    subtitle: Text(
                      widget.subtitleOf(item),
                      style: const TextStyle(color: erpMuted),
                    ),
                  ),
                );
              },
            ),
    );
  }

  Future<void> _remove(BuildContext context, int index, Offset pos) async {
    final action = await showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(pos.dx, pos.dy, pos.dx, pos.dy),
      items: const [
        PopupMenuItem(
          value: 'delete',
          child: Text('Excluir', style: TextStyle(color: erpDanger)),
        ),
      ],
    );
    if (!context.mounted || action != 'delete') return;
    widget.onDelete(index);
    setState(() {});
  }
}

void showError(BuildContext context, String message) {
  ScaffoldMessenger.of(
    context,
  ).showSnackBar(SnackBar(content: Text(message), backgroundColor: erpDanger));
}

double parseNum(String v, [double fallback = 0]) =>
    double.tryParse(v.replaceAll(',', '.')) ?? fallback;

String brl(num n) => 'R\$ ${n.toStringAsFixed(2).replaceAll('.', ',')}';

String sepNo(int n) => n <= 0 ? '—' : n.toString().padLeft(6, '0');

String orderNo(String id) => id.length <= 8 ? id : id.substring(0, 8).toUpperCase();

String fmtDt(String iso) {
  if (iso.isEmpty) return '—';
  final d = DateTime.tryParse(iso)?.toLocal();
  if (d == null) return '—';
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(d.day)}/${two(d.month)}/${d.year} ${two(d.hour)}:${two(d.minute)}';
}
