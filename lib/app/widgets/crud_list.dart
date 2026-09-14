import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../theme.dart';

class CrudList<T> extends StatelessWidget {
  const CrudList({
    super.key,
    required this.value,
    required this.onRefresh,
    required this.titleOf,
    required this.subtitleOf,
    this.onCreate,
    this.onEdit,
    this.onDelete,
    this.extraActions,
    this.onAction,
    this.onTap,
    this.onDoubleTap,
    this.isThreeLine = false,
  });

  final AsyncValue<List<T>> value;
  final Future<void> Function() onRefresh;
  final String Function(T item) titleOf;
  final String Function(T item) subtitleOf;
  final VoidCallback? onCreate;
  final void Function(T item)? onEdit;
  final Future<void> Function(T item)? onDelete;
  final List<PopupMenuItem<String>> Function(T item)? extraActions;
  final void Function(T item, String action)? onAction;
  final void Function(T item)? onTap;
  final void Function(T item)? onDoubleTap;
  final bool isThreeLine;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: onCreate == null
          ? null
          : FloatingActionButton(
              onPressed: onCreate,
              backgroundColor: erpAccent,
              child: const Icon(Icons.add),
            ),
      body: value.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text('$e', style: const TextStyle(color: erpDanger)),
          ),
        ),
        data: (items) {
          if (items.isEmpty) {
            return RefreshIndicator(
              onRefresh: onRefresh,
              child: ListView(
                children: const [
                  SizedBox(height: 120),
                  Center(
                    child: Text(
                      'Nenhum registro',
                      style: TextStyle(color: erpMuted),
                    ),
                  ),
                ],
              ),
            );
          }
          return RefreshIndicator(
            onRefresh: onRefresh,
            child: ListView.separated(
              itemCount: items.length,
              separatorBuilder: (_, _) =>
                  const Divider(height: 1, color: erpLine),
              itemBuilder: (context, i) {
                final item = items[i];
                return GestureDetector(
                  onLongPressStart: (d) =>
                      _menu(context, item, d.globalPosition),
                  onDoubleTap: onDoubleTap == null
                      ? null
                      : () => onDoubleTap!(item),
                  child: ListTile(
                    isThreeLine: isThreeLine,
                    onTap: onTap == null ? null : () => onTap!(item),
                    title: Text(titleOf(item)),
                    subtitle: Text(
                      subtitleOf(item),
                      style: const TextStyle(color: erpMuted),
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }

  Future<void> _menu(BuildContext context, T item, Offset pos) async {
    final extras = extraActions?.call(item) ?? const <PopupMenuItem<String>>[];
    if (onEdit == null && onDelete == null && extras.isEmpty) return;
    final action = await showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(pos.dx, pos.dy, pos.dx, pos.dy),
      items: [
        if (onEdit != null)
          const PopupMenuItem(value: 'edit', child: Text('Editar')),
        ...extras,
        if (onDelete != null)
          const PopupMenuItem(
            value: 'delete',
            child: Text('Excluir', style: TextStyle(color: erpDanger)),
          ),
      ],
    );
    if (!context.mounted || action == null) return;
    if (action == 'edit') {
      onEdit?.call(item);
      return;
    }
    if (action == 'delete') {
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Excluir'),
          content: const Text('Confirma a exclusão?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Excluir'),
            ),
          ],
        ),
      );
      if (ok == true) await onDelete?.call(item);
      return;
    }
    onAction?.call(item, action);
  }
}
