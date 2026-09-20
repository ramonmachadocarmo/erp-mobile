import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/di.dart';
import '../../../app/widgets/crud_list.dart';
import '../../../app/widgets/list_filters.dart';
import '../../../app/widgets/form_kit.dart';
import '../../purchasing/presentation/purchasing_providers.dart';
import '../data/invoicing_repository_impl.dart';
import '../domain/entities.dart';

final invoicingRepositoryProvider = Provider(
  (ref) => InvoicingRepositoryImpl(ref.watch(apiClientProvider)),
);

final invoicesProvider = AsyncNotifierProvider.family<InvoicesNotifier, List<Invoice>, String>(
  InvoicesNotifier.new,
);

class InvoicesNotifier extends FamilyAsyncNotifier<List<Invoice>, String> {
  @override
  Future<List<Invoice>> build(String arg) =>
      ref.read(invoicingRepositoryProvider).invoices(arg).then((r) => r.getOrThrow());

  Future<void> reload() async {
    state = await AsyncValue.guard(
      () => ref.read(invoicingRepositoryProvider).invoices(arg).then((r) => r.getOrThrow()),
    );
  }

  Future<void> issue(String id) async {
    (await ref.read(invoicingRepositoryProvider).issue(id)).getOrThrow();
    await reload();
  }

  Future<void> importFile({
    String path = '',
    String name = '',
    String purchaseOrderId = '',
    bool withoutNote = false,
  }) async {
    (await ref.read(invoicingRepositoryProvider).importFile(
          direction: arg,
          filePath: path,
          fileName: name,
          purchaseOrderId: purchaseOrderId,
          withoutNote: withoutNote,
        ))
        .getOrThrow();
    await reload();
  }
}

class InvoicesPage extends ConsumerWidget {
  const InvoicesPage({super.key, required this.direction});

  final String direction;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = ref.watch(invoicesProvider(direction));
    return CrudList<Invoice>(
      value: items,
      onRefresh: () => ref.read(invoicesProvider(direction).notifier).reload(),
      titleOf: (i) => '${i.series}-${i.invoiceNumber}',
      subtitleOf: (i) =>
          '${i.status} · ${i.source == 'IMPORT' ? 'Importada' : i.source == 'MANUAL' ? 'Sem nota' : 'Pedido'} · ${brl(i.totalInvoice)}',
      filters: [
        ListFilter<Invoice>.byValue(label: 'Status', valueOf: (i) => i.status),
        ListFilter<Invoice>.byValue(
          label: 'Origem',
          valueOf: (i) => i.source,
          options: const [
            FilterOption('IMPORT', 'Importada'),
            FilterOption('MANUAL', 'Sem nota'),
            FilterOption('ORDER', 'Pedido'),
          ],
        ),
      ],
      onCreate: () => _import(context, ref),
      extraActions: (i) => i.status == 'PENDING_SEFAZ'
          ? [const PopupMenuItem(value: 'issue', child: Text('Emitir NFe'))]
          : const [],
      onAction: (i, action) {
        if (action == 'issue') ref.read(invoicesProvider(direction).notifier).issue(i.id);
      },
    );
  }

  Future<void> _import(BuildContext context, WidgetRef ref) async {
    var poId = '';
    if (direction == 'IN') {
      final orders = (ref.read(purchaseOrdersProvider).valueOrNull ?? [])
          .where((o) => o.status == 'APPROVED')
          .toList();
      if (orders.isEmpty) {
        if (context.mounted) showError(context, 'Nenhum pedido de compra aprovado');
        return;
      }
      poId = await showDialog<String>(
            context: context,
            builder: (ctx) => SimpleDialog(
              title: const Text('Pedido de compra'),
              children: [
                for (final o in orders)
                  SimpleDialogOption(
                    onPressed: () => Navigator.pop(ctx, o.id),
                    child: Text('${o.id.substring(0, o.id.length.clamp(0, 8))} · ${brl(o.totalAmount)}'),
                  ),
              ],
            ),
          ) ??
          '';
      if (poId.isEmpty) return;
    }
    var withoutNote = false;
    if (direction == 'IN') {
      final choice = await showDialog<bool>(
        context: context,
        builder: (ctx) {
          var checked = false;
          return StatefulBuilder(
            builder: (ctx, setSt) => AlertDialog(
              title: const Text('Nota de entrada'),
              content: CheckboxListTile(
                title: const Text('Entrada sem nota'),
                value: checked,
                onChanged: (v) => setSt(() => checked = v ?? false),
                controlAffinity: ListTileControlAffinity.leading,
                contentPadding: EdgeInsets.zero,
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
                FilledButton(onPressed: () => Navigator.pop(ctx, checked), child: const Text('Continuar')),
              ],
            ),
          );
        },
      );
      if (choice == null) return;
      withoutNote = choice;
    }
    String path = '';
    String name = '';
    if (!withoutNote) {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['xml', 'pdf'],
      );
      final file = result?.files.single;
      if (file?.path == null) return;
      path = file!.path!;
      name = file.name;
      final lower = name.toLowerCase();
      if (!lower.endsWith('.xml') && !lower.endsWith('.pdf')) {
        if (context.mounted) showError(context, 'Arquivo deve ser XML ou PDF');
        return;
      }
    }
    try {
      await ref.read(invoicesProvider(direction).notifier).importFile(
            path: path,
            name: name,
            purchaseOrderId: poId,
            withoutNote: withoutNote,
          );
    } catch (e) {
      if (context.mounted) showError(context, '$e');
    }
  }
}
