import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/presentation/providers/auth_notifier.dart';
import '../theme.dart';
import 'list_filters.dart';

/// The app's list widget: search box, per-screen [filters], pull-to-refresh and
/// create/edit/delete. The role's level for the current menu screen gates the
/// write actions: view-only roles get a plain list.
///
/// Search matches [searchTextOf] (default: title + subtitle, accent-insensitive).
/// Pass [itemBuilder] for rows richer than a title/subtitle tile; the
/// title/subtitle callbacks then only feed the search.
class CrudList<T> extends ConsumerStatefulWidget {
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
    this.filters = const [],
    this.searchTextOf,
    this.searchable = true,
    this.itemBuilder,
    this.emptyLabel = 'Nenhum registro',
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
  final List<ListFilter<T>> filters;
  final String Function(T item)? searchTextOf;
  final bool searchable;
  final Widget Function(BuildContext context, T item)? itemBuilder;
  final String emptyLabel;

  @override
  ConsumerState<CrudList<T>> createState() => _CrudListState<T>();
}

class _CrudListState<T> extends ConsumerState<CrudList<T>> {
  final _search = TextEditingController();
  var _query = '';
  // Picked value per filter index; '' or missing means "Todos".
  final _selected = <int, String>{};

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  List<T> _apply(List<T> items) {
    final q = normalizeSearch(_query.trim());
    return [
      for (final item in items)
        if (_passes(item, q)) item,
    ];
  }

  bool _passes(T item, String q) {
    for (final e in _selected.entries) {
      if (e.value.isEmpty) continue;
      if (!widget.filters[e.key].matches(item, e.value)) return false;
    }
    if (q.isEmpty) return true;
    final text =
        widget.searchTextOf?.call(item) ??
        '${widget.titleOf(item)} ${widget.subtitleOf(item)}';
    return normalizeSearch(text).contains(q);
  }

  @override
  Widget build(BuildContext context) {
    final path = GoRouter.of(context).routerDelegate.currentConfiguration.uri.path;
    final canEdit = ref.watch(accessProvider).canEdit(path);
    final onCreate = canEdit ? widget.onCreate : null;
    final onEdit = canEdit ? widget.onEdit : null;
    final onDelete = canEdit ? widget.onDelete : null;
    final all = widget.value.valueOrNull ?? const [];
    final showBar = widget.searchable && all.isNotEmpty;
    return Scaffold(
      floatingActionButton: onCreate == null
          ? null
          : FloatingActionButton(
              onPressed: onCreate,
              backgroundColor: erpAccent,
              child: const Icon(Icons.add),
            ),
      body: Column(
        children: [
          if (showBar)
            ListFilterBar<T>(
              controller: _search,
              onQuery: (v) => setState(() => _query = v),
              filters: widget.filters,
              items: all,
              selected: _selected,
              onFilter: (i, v) => setState(() => _selected[i] = v),
            ),
          Expanded(
            child: widget.value.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text('$e', style: const TextStyle(color: erpDanger)),
                ),
              ),
              data: (items) => _list(items, onEdit, onDelete),
            ),
          ),
        ],
      ),
    );
  }

  Widget _list(
    List<T> items,
    void Function(T item)? onEdit,
    Future<void> Function(T item)? onDelete,
  ) {
    final shown = _apply(items);
    if (shown.isEmpty) {
      final filtered = items.isNotEmpty;
      return RefreshIndicator(
        onRefresh: widget.onRefresh,
        child: ListView(
          children: [
            const SizedBox(height: 120),
            Center(
              child: Text(
                filtered ? 'Nenhum resultado' : widget.emptyLabel,
                style: const TextStyle(color: erpMuted),
              ),
            ),
          ],
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: widget.onRefresh,
      child: ListView.separated(
        itemCount: shown.length,
        separatorBuilder: (_, _) => const Divider(height: 1, color: erpLine),
        itemBuilder: (context, i) {
          final item = shown[i];
          if (widget.itemBuilder != null) {
            return widget.itemBuilder!(context, item);
          }
          return GestureDetector(
            onLongPressStart: (d) =>
                _menu(context, item, d.globalPosition, onEdit, onDelete),
            onDoubleTap: widget.onDoubleTap == null
                ? null
                : () => widget.onDoubleTap!(item),
            child: ListTile(
              isThreeLine: widget.isThreeLine,
              onTap: widget.onTap == null ? null : () => widget.onTap!(item),
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

  Future<void> _menu(
    BuildContext context,
    T item,
    Offset pos,
    void Function(T item)? onEdit,
    Future<void> Function(T item)? onDelete,
  ) async {
    final extras = widget.extraActions?.call(item) ?? const <PopupMenuItem<String>>[];
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
    widget.onAction?.call(item, action);
  }
}
