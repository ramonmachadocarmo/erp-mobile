import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../app/di.dart';
import '../../../app/widgets/crud_list.dart';
import '../../../app/widgets/list_filters.dart';
import '../../../app/widgets/form_kit.dart';
import '../../purchasing/presentation/purchasing_providers.dart';
import '../data/invoicing_repository_impl.dart';
import '../domain/entities.dart';
import '../domain/note_attachment.dart';

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
    var source = NoteSource.file;
    if (direction == 'IN') {
      if (!context.mounted) return;
      final choice = await showDialog<NoteSource>(
        context: context,
        builder: (ctx) => SimpleDialog(
          title: const Text('Nota de entrada'),
          children: [
            SimpleDialogOption(
              onPressed: () => Navigator.pop(ctx, NoteSource.photo),
              child: const ListTile(
                leading: Icon(Icons.photo_camera),
                title: Text('Tirar foto da nota/recibo'),
                contentPadding: EdgeInsets.zero,
              ),
            ),
            SimpleDialogOption(
              onPressed: () => Navigator.pop(ctx, NoteSource.file),
              child: const ListTile(
                leading: Icon(Icons.attach_file),
                title: Text('Anexar arquivo (XML, PDF ou imagem)'),
                contentPadding: EdgeInsets.zero,
              ),
            ),
            SimpleDialogOption(
              onPressed: () => Navigator.pop(ctx, NoteSource.none),
              child: const ListTile(
                leading: Icon(Icons.block),
                title: Text('Entrada sem nota'),
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ],
        ),
      );
      if (choice == null) return;
      source = choice;
    }
    final withoutNote = source == NoteSource.none;
    String path = '';
    String name = '';
    if (source == NoteSource.photo) {
      try {
        // Reduz a foto (câmera moderna gera vários MB) — o backend guarda até 8 MB.
        final shot = await ImagePicker().pickImage(
          source: ImageSource.camera,
          imageQuality: 80,
          maxWidth: 2000,
          maxHeight: 2000,
        );
        if (shot == null) return;
        path = shot.path;
        name = shot.name.isEmpty ? 'nota-${DateTime.now().millisecondsSinceEpoch}.jpg' : shot.name;
      } catch (e) {
        if (context.mounted) showError(context, 'Não foi possível abrir a câmera: $e');
        return;
      }
    } else if (source == NoteSource.file) {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: noteFileExtensions,
      );
      final file = result?.files.single;
      if (file?.path == null) return;
      path = file!.path!;
      name = file.name;
      if (!isAllowedNoteFile(name)) {
        if (context.mounted) showError(context, 'Arquivo deve ser XML, PDF ou imagem (JPG/PNG)');
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
