import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/auth/presentation/providers/auth_notifier.dart';
import 'nav.dart';
import 'theme.dart';

class AppShell extends ConsumerWidget {
  const AppShell({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authNotifierProvider).user;
    final location = GoRouterState.of(context).uri.path;
    final title = _titleFor(location);

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: [
          if (user != null)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Center(
                child: Text(
                  user.name,
                  style: const TextStyle(color: erpMuted, fontSize: 14),
                ),
              ),
            ),
          TextButton(
            onPressed: () => ref.read(authNotifierProvider.notifier).logout(),
            child: const Text('Sair'),
          ),
        ],
      ),
      drawer: Drawer(child: _NavDrawer(location: location)),
      body: child,
    );
  }

  String _titleFor(String location) {
    for (final group in navGroups) {
      for (final item in group.items) {
        if (item.path == location) return item.label;
      }
    }
    return 'ERP';
  }
}

class _NavDrawer extends StatefulWidget {
  const _NavDrawer({required this.location});

  final String location;

  @override
  State<_NavDrawer> createState() => _NavDrawerState();
}

class _NavDrawerState extends State<_NavDrawer> {
  String? _open;

  @override
  void initState() {
    super.initState();
    _open = _groupFor(widget.location);
  }

  @override
  void didUpdateWidget(_NavDrawer old) {
    super.didUpdateWidget(old);
    if (old.location != widget.location) {
      _open = _groupFor(widget.location);
    }
  }

  String? _groupFor(String location) {
    for (final g in navGroups) {
      if (g.items.any((i) => i.path == location)) return g.title;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 12, 20, 16),
            child: Text(
              'ERP',
              style: TextStyle(
                letterSpacing: 1.2,
                fontWeight: FontWeight.w700,
                color: erpMuted,
              ),
            ),
          ),
          for (final group in navGroups)
            _NavGroupTile(
              group: group,
              location: widget.location,
              expanded: _open == group.title,
              onExpanded: (open) {
                if (open) {
                  setState(() => _open = group.title);
                } else if (_open == group.title) {
                  setState(() => _open = null);
                }
              },
            ),
        ],
      ),
    );
  }
}

class _NavGroupTile extends StatelessWidget {
  const _NavGroupTile({
    required this.group,
    required this.location,
    required this.expanded,
    required this.onExpanded,
  });

  final NavGroup group;
  final String location;
  final bool expanded;
  final ValueChanged<bool> onExpanded;

  @override
  Widget build(BuildContext context) {
    final active = group.items.any((i) => i.path == location);
    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        key: ValueKey('${group.title}-$expanded'),
        initiallyExpanded: expanded,
        onExpansionChanged: onExpanded,
        tilePadding: const EdgeInsets.symmetric(horizontal: 16),
        childrenPadding: const EdgeInsets.only(left: 12, bottom: 8),
        iconColor: erpAccent,
        collapsedIconColor: erpMuted,
        title: Text(
          group.title,
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 15,
            letterSpacing: 0.2,
            color: active ? erpText : erpMuted,
          ),
        ),
        children: [
          for (final item in group.items)
            ListTile(
              dense: true,
              visualDensity: VisualDensity.compact,
              contentPadding: const EdgeInsets.only(left: 20, right: 16),
              shape: const Border(
                left: BorderSide(color: erpLine, width: 2),
              ),
              title: Text(
                item.label,
                style: TextStyle(
                  fontWeight: FontWeight.w400,
                  fontSize: 14,
                  color: item.path == location ? erpAccent : erpText,
                ),
              ),
              selected: item.path == location,
              selectedTileColor: erpAccent.withValues(alpha: 0.12),
              onTap: () {
                Navigator.of(context).pop();
                context.go(item.path);
              },
            ),
        ],
      ),
    );
  }
}
